# 玄金钱包

玄金钱包是一个开源的 macOS 只读钱包。粘贴比特币或以太坊主网的公开地址，即可查询原生币余额和最近 10 笔交易。默认界面只接收公开地址，适合查看已有钱包的链上状态。

![玄金钱包 Logo](Sources/WalletDesktop/Resources/WalletLogo.png)

## 开始使用

在装有 Swift 6 或更新版本、Xcode 命令行工具及 Homebrew 的 Mac 上运行以下命令。当前构建在 Apple 芯片 Mac 上验证。

```bash
brew install secp256k1 openssl
git clone https://github.com/15103639079/xuanjin-wallet.git
cd xuanjin-wallet
./一键启动.command
```

选择网络，粘贴原钱包的公开收款地址，然后点击「查询」。「填入公开示例」可用于体验。比特币显示已入块余额，以太坊显示 ETH 余额和普通交易。查询结果带有时间和交易状态，错误会单独显示。USDT 等代币余额、整组派生地址汇总和真实资产转账暂未接入。

只有主动查询才会把公开地址发送给界面标出的服务。比特币使用 [Blockstream Esplora](https://github.com/Blockstream/esplora/blob/master/API.md)，以太坊使用 [Blockscout](https://eth.blockscout.com/)。

## 如何降低静默盗转风险

- **日常查询只需要公开地址。** 默认界面没有助记词输入、交易签名或转账入口。即使只读查询客户端被控制，它也没有可用于花费资金的私钥。被控制的客户端仍可能伪造余额或替换收款地址，因此收款时应在独立硬件钱包上核对地址。
- **把签名交给独立设备。** 本地测试用两个隔离的 Bitcoin Core 节点演练了这一设计。只读节点构建部分签名比特币交易（PSBT），独立软件签名节点核对收款地址、金额、找零和手续费，再用从备份恢复的钱包签名。测试验证了四类不匹配会被拦截。实体硬件的屏幕核对、签名和恢复仍待验证。 [Bitcoin Core 的 PSBT 流程](https://github.com/bitcoin/bitcoin/blob/master/doc/psbt.md)
- **开源便于复查。** 可以从源代码自行构建，检查查询请求和测试流程。目前尚未完成独立安全审计或真机硬件签名验证。

所谓「无感」如果指设备被静默入侵，应用无法保证发现入侵。这里降低的是**联网客户端持有私钥并被静默签名的风险**。具体防护与限制见[威胁模型](文档/01_威胁模型.md)。

## 本地验证

`./一键验证.sh` 构建应用并运行 Swift 测试。安装 Bitcoin Core 和 Python 3 后，可运行 `python3 Scripts/bitcoin-regtest.py` 验证本地测试链的签名和恢复。步骤见[操作说明](文档/03_路线图.md#比特币签名与恢复验证)。

`./一键启动.command --offline-lab` 可打开仅供开发测试的离线实验室。请使用公开测试向量或临时测试助记词，真实钱包只需提供公开地址。

项目采用 [MIT 许可证](LICENSE)。BIP39 英文词表及外部依赖见[第三方声明](THIRD-PARTY-NOTICES.txt)。
