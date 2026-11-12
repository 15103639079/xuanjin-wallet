#!/usr/bin/env python3
"""Verify a PSBT round trip with two isolated Bitcoin Core regtest nodes."""

import argparse
import json
from contextlib import ExitStack, contextmanager
from decimal import Decimal
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


@contextmanager
def regtest(root, name, binaries):
    directory = root / name
    directory.mkdir(mode=0o700)
    with socket.socket() as port_picker:
        port_picker.bind(("127.0.0.1", 0))
        port = port_picker.getsockname()[1]

    common = ["-regtest", "-conf=/dev/null", f"-datadir={directory}", f"-rpcport={port}"]
    log_path = directory / "node.log"
    with log_path.open("w") as log:
        process = subprocess.Popen(
            [binaries["bitcoind"], *common, "-server=1", "-networkactive=0",
             "-listen=0", "-discover=0", "-dnsseed=0", "-printtoconsole"],
            stdout=log, stderr=subprocess.STDOUT,
        )

        def rpc(method, *args, wallet=None):
            command = [binaries["bitcoin-cli"], *common, "-rpcclienttimeout=15"]
            if wallet is not None:
                command.append(f"-rpcwallet={wallet}")
            output = subprocess.check_output([*command, method, *args], text=True, timeout=20).strip()
            try:
                return json.loads(output, parse_float=Decimal)
            except json.JSONDecodeError:
                return output

        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError(f"{name} 节点启动失败\n{log_path.read_text()[-1500:]}")
                if (directory / "regtest" / ".cookie").is_file():
                    try:
                        if rpc("getblockchaininfo")["chain"] != "regtest":
                            raise RuntimeError("节点网络与预期不符。")
                        break
                    except subprocess.CalledProcessError:
                        pass
                time.sleep(0.1)
            else:
                raise RuntimeError(f"{name} 节点启动超时。")
            yield rpc
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def verify_payment(decoded, recipient, amount, change, maximum_fee):
    fee = decoded.get("fee")
    if fee is None or not 0 < fee <= maximum_fee:
        raise ValueError("手续费缺失或超出范围。")
    outputs = decoded["tx"]["vout"]
    addresses = [output["scriptPubKey"].get("address") for output in outputs]
    if addresses.count(recipient) != 1 or len(addresses) != 2 or set(addresses) != {recipient, change}:
        raise ValueError("收款地址或找零地址与预期不符。")
    payment = next(output["value"] for output in outputs if output["scriptPubKey"]["address"] == recipient)
    if payment != amount:
        raise ValueError("收款金额与预期不符。")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(coordinator, signer, root):
    signer("createwallet", "signer")
    signer("createwallet", "recipient")
    coordinator("createwallet", "watch", "true", "true")
    require(not coordinator("getwalletinfo", wallet="watch")["private_keys_enabled"],
            "协调钱包不应持有私钥。")

    descriptors = signer("listdescriptors", "false", wallet="signer")["descriptors"]
    request = [
        {"desc": item["desc"], "timestamp": "now", "active": True,
         "internal": item["internal"], "range": [0, 99]}
        for item in descriptors if item["active"] and item["desc"].startswith("wpkh(")
    ]
    require(len(request) == 2, "预期有独立的收款和找零描述符。")
    imported = coordinator("importdescriptors", json.dumps(request), wallet="watch")
    require(all(item["success"] for item in imported), "导入公开描述符失败。")

    receive = signer("getnewaddress", "", "bech32", wallet="signer")
    watch_receive = coordinator("getnewaddress", "", "bech32", wallet="watch")
    require(receive == watch_receive, "收款地址不一致。")
    change = signer("getrawchangeaddress", "bech32", wallet="signer")
    require(signer("getaddressinfo", change, wallet="signer")["ischange"], "找零地址归属校验失败。")
    recipient = signer("getnewaddress", "", "bech32", wallet="recipient")
    coordinator("generatetoaddress", "101", receive)
    print("通过：公开描述符导入、收款地址核对、测试资金确认。", flush=True)

    payment_amount = Decimal("1.25")
    outputs = '[{"' + recipient + '":' + str(payment_amount) + '}]'
    options = json.dumps({"changeAddress": change, "fee_rate": 2})
    proposal = coordinator("walletcreatefundedpsbt", "[]", outputs, "0", options, wallet="watch")
    psbt = proposal["psbt"]
    decoded = signer("decodepsbt", psbt)
    maximum_fee = Decimal("0.0001")
    verify_payment(decoded, recipient, payment_amount, change, maximum_fee)
    for expected in [
        (receive, payment_amount, change, maximum_fee),
        (recipient, payment_amount, receive, maximum_fee),
        (recipient, Decimal("2"), change, maximum_fee),
        (recipient, payment_amount, change, Decimal("0.00000001")),
    ]:
        try:
            verify_payment(decoded, *expected)
        except ValueError:
            continue
        raise RuntimeError("错误的交易条件未被拦截。")
    print("通过：核对金额、收款、找零和手续费，四种不匹配均被拒绝。", flush=True)

    backup = str(root / "regtest-signer-backup.dat")
    signer("backupwallet", backup, wallet="signer")
    signer("unloadwallet", "signer")
    signer("restorewallet", "restored", backup)
    require(signer("getaddressinfo", receive, wallet="restored")["ismine"], "恢复后未识别原收款地址。")
    require(signer("getaddressinfo", change, wallet="restored")["ischange"], "恢复后未识别找零地址。")
    signed = signer("walletprocesspsbt", psbt, "true", "ALL", wallet="restored")
    require(signed["complete"], "恢复的钱包签名不完整。")
    finalized = coordinator("finalizepsbt", signed["psbt"])
    require(finalized["complete"], "交易无法完成。")
    raw = finalized["hex"]
    require(coordinator("decoderawtransaction", raw)["txid"] == decoded["tx"]["txid"],
            "签名返回的原生隔离见证交易与核对结果不一致。")
    require(coordinator("testmempoolaccept", json.dumps([raw]))[0]["allowed"], "交易未通过节点验证。")
    txid = coordinator("sendrawtransaction", raw)
    coordinator("generatetoaddress", "1", receive)
    transaction = coordinator("gettransaction", txid, wallet="watch")
    require(transaction["confirmations"] >= 1, "测试交易未入块。")
    require(signer("getblockcount") == 0, "签名节点不应同步协调节点的区块。")
    print("通过：从备份恢复、用恢复后的钱包签名、本地广播并确认入块。")
    print(f"本地测试交易 ID {txid}")


def main():
    parser = argparse.ArgumentParser(description="在临时本地测试链验证比特币签名和恢复。")
    parser.add_argument("--bin-dir", type=Path, help="Bitcoin Core 命令行工具所在目录")
    args = parser.parse_args()
    binaries = {}
    for name in ("bitcoind", "bitcoin-cli"):
        candidate = str((args.bin_dir / name).resolve()) if args.bin_dir else name
        binaries[name] = shutil.which(candidate)
        if not binaries[name]:
            parser.error(f"找不到 {name}。请安装 Bitcoin Core 或通过 --bin-dir 指定工具目录。")

    with tempfile.TemporaryDirectory(prefix="xuanjin-regtest-") as temporary, ExitStack() as nodes:
        root = Path(temporary)
        coordinator = nodes.enter_context(regtest(root, "coordinator", binaries))
        signer = nodes.enter_context(regtest(root, "signer", binaries))
        run(coordinator, signer, root)


if __name__ == "__main__":
    main()
