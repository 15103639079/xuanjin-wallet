#!/bin/bash
# 在「最安全的钱包」目录里跑：构建 + 单元测试
set -euo pipefail
cd "$(dirname "$0")"
echo "== 环境 =="; swift --version | head -1
echo "== 构建 =="; swift build
echo "== 测试 =="; swift test
echo "== 完成 =="
