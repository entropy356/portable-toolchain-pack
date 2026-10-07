#!/usr/bin/env bash
# GitNexus 用户级安装脚本（免 root，装到指定前缀）
# 用法: ./install-gitnexus.sh [目标目录]   （默认 ~/gitnexus-toolchain）
#
# 包体从本仓库 Releases 下载（二进制不进 git）；S3 后端支持 Range 断点续传。
set -euo pipefail

PREFIX="${1:-$HOME/gitnexus-toolchain}"
VERSION="gitnexus-1.6.12"
BASE_URL="https://github.com/entropy356/portable-toolchain-pack/releases/download/${VERSION}"

command -v curl  >/dev/null 2>&1 || { echo "缺少依赖：curl" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "缺少依赖：sha256sum (coreutils)" >&2; exit 1; }
# 要求：Node.js >= 22（本包在 Node 24.21 上验证）
node --version

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fL --retry 3 "$BASE_URL/SHA256SUMS" -o "$WORK/SHA256SUMS"
TGZ="$WORK/gitnexus-1.6.12.tgz"
echo "下载 gitnexus-1.6.12.tgz ..."
curl -fL --retry 3 -C - "$BASE_URL/gitnexus-1.6.12.tgz" -o "$TGZ"
( cd "$WORK" && sha256sum -c SHA256SUMS )

mkdir -p "$PREFIX"
# 跳过 Dart/Proto/Swift/Kotlin 语法树的原生构建（无需 python3/make/g++），
# 其余语言解析不受影响；如需全部语言，去掉该环境变量。
export GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1
# --offline：严格使用 npm 本地缓存安装，不访问网络（首次安装本包会顺带
# 填充缓存；若提示缓存缺失，可去掉 --offline 改为在线安装）。
npm install -g --prefix "$PREFIX" --offline "$TGZ" \
  || npm install -g --prefix "$PREFIX" "$TGZ"

echo
echo "安装完成。使用方式："
echo "  export PATH=\"$PREFIX/bin:\$PATH\""
echo "  gitnexus --version"
echo "  cd <你的仓库> && gitnexus analyze"
