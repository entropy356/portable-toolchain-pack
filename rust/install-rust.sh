#!/usr/bin/env bash
# Rust 1.99.0 用户级安装脚本（免 root，官方发布包，装到指定前缀）
# 用法: ./install-rust.sh [目标目录]   （默认 ~/rust-toolchain）
#
# 组件包从本仓库 Releases 下载（二进制不进 git，仓库保持轻量）；
# 下载走 GitHub S3 后端，原生支持 Range 断点续传；
# 校验沿用官方 SHA256SUMS。Debian 仓库最高只到 1.97.1~exp1（实验版），
# 拿不到最新稳定版，故用官方组件包。
set -euo pipefail

PREFIX="${1:-$HOME/rust-toolchain}"
# 规范为绝对路径：组件自带 install.sh 在解压临时目录中执行，
# 相对前缀会被解析到临时目录里（常见坑），这里先落定为绝对路径
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

VERSION="rust-1.99.0"
BASE_URL="https://github.com/entropy356/portable-toolchain-pack/releases/download/${VERSION}"
PACKAGES=(
  rustc-1.99.0-x86_64-unknown-linux-gnu.tar.xz
  cargo-1.99.0-x86_64-unknown-linux-gnu.tar.xz
  rust-std-1.99.0-x86_64-unknown-linux-gnu.tar.xz
  clippy-1.99.0-x86_64-unknown-linux-gnu.tar.xz
  rustfmt-1.99.0-x86_64-unknown-linux-gnu.tar.xz
)

# 0) 依赖检查：tar 解 .tar.xz 需要外部 xz，精简系统（如最小化 Debian 容器）常常没有
missing=()
command -v tar       >/dev/null 2>&1 || missing+=(tar)
command -v xz        >/dev/null 2>&1 || missing+=(xz-utils)
command -v curl      >/dev/null 2>&1 || missing+=(curl)
command -v sha256sum >/dev/null 2>&1 || missing+=(coreutils)
if [ "${#missing[@]}" -gt 0 ]; then
    echo "缺少依赖：${missing[*]}" >&2
    echo "Debian/Ubuntu 上可执行：sudo apt-get install -y xz-utils curl coreutils" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1) 校验和先行
curl -fL --retry 3 "$BASE_URL/SHA256SUMS" -o "$WORK/SHA256SUMS"

# 2) 下载五个组件包（-C - 断点续传；S3 后端支持 Range）
for pkg in "${PACKAGES[@]}"; do
    echo "下载 $pkg ..."
    curl -fL --retry 3 -C - "$BASE_URL/$pkg" -o "$WORK/$pkg"
done

# 3) 完整性校验（下载产物 vs 官方 SHA256SUMS）
( cd "$WORK" && sha256sum -c SHA256SUMS )

# 4) 逐个解压组件包，调用官方 install.sh 装到同一前缀
#    --disable-ldconfig：不调用 ldconfig（需要 root，且官方包不依赖它）
shopt -s nullglob
tarballs=( "$WORK"/rustc-*.tar.xz "$WORK"/cargo-*.tar.xz "$WORK"/rust-std-*.tar.xz \
           "$WORK"/clippy-*.tar.xz "$WORK"/rustfmt-*.tar.xz )
shopt -u nullglob

if [ "${#tarballs[@]}" -ne 5 ]; then
    echo "错误：下载产物应为五个组件包，实际找到 ${#tarballs[@]} 个" >&2
    exit 1
fi

for tarball in "${tarballs[@]}"; do
    name="$(basename "$tarball" .tar.xz)"
    echo "安装 $name ..."
    rm -rf "$WORK/$name"
    tar -xf "$tarball" -C "$WORK"
    # 用 sh 调用，不依赖包内 install.sh 的可执行位
    ( cd "$WORK/$name" && sh ./install.sh --prefix="$PREFIX" --disable-ldconfig )
done

BINDIR="$PREFIX/bin"

echo
echo "安装完成。使用方式（每次使用前设置环境变量）："
echo "  export PATH=\"$BINDIR:\$PATH\""
echo
echo "包含的工具："
"$BINDIR/rustc" --version
"$BINDIR/cargo" --version
"$BINDIR/clippy-driver" --version
"$BINDIR/rustfmt" --version
