# portable-toolchain-pack

用户级（免 root）便携工具链打包：**Rust 1.99.0（rustc + cargo + clippy + rustfmt）+ [GitNexus](https://github.com/abhigyanpatwari/GitNexus) 1.6.12**，跨机器复制即可用，不污染系统环境。

**二进制组件包不进 git**：全部挂在本仓库 [Releases](../../releases)
（`rust-1.99.0` / `gitnexus-1.6.12` 两个 tag），安装脚本运行时自动下载
（S3 后端，支持 Range 断点续传），并按官方 `SHA256SUMS` 校验。
仓库本体只含脚本与校验和。

## 内容

| 工具 | 版本 | 来源 | 用途 |
|---|---|---|---|
| rustc / cargo（含 rustdoc） | 1.99.0 | Rust 官方发布包（[`rust/`](rust/)） | Rust 编译器与构建工具 |
| clippy / rustfmt | 0.1.99 / 1.10.0 | Rust 官方组件包（[`rust/`](rust/)） | Lint 检查与代码格式化，与 CI 门禁同版本 |
| [GitNexus](https://github.com/abhigyanpatwari/GitNexus) | 1.6.12 | npm 包（[`gitnexus/`](gitnexus/)） | 代码库知识图谱引擎（CLI + MCP），见 [`gitnexus/`](gitnexus/) |

平台：x86_64 Linux（glibc）。

### Rust 为什么不用 `.deb`

Debian 仓库里最新的 rustc 是 `1.97.1+dfsg1-1~exp1`（experimental，非稳定套件），
trixie-backports 只到 `1.95.0`，都拿不到当前最新稳定版。因此 Rust 改用官方
发布的组件包（`rustc` + `cargo` + `rust-std` + `clippy` + `rustfmt`，`x86_64-unknown-linux-gnu`），
由 [`rust/install-rust.sh`](rust/install-rust.sh) 安装到用户目录。

## 安装（免 root）

解压依赖：`xz-utils`（提供 `xz`，用于 `.tar.xz`）。Debian/Ubuntu 上
`sudo apt-get install -y xz-utils`；脚本在缺失时会明确提示并退出。

```bash
# Rust 1.99.0（官方组件包，默认 ~/rust-toolchain）
./rust/install-rust.sh ~/rust-toolchain
```

之后每次使用前：

```bash
export PATH="$HOME/rust-toolchain/bin:$PATH"
```

cargo 首次使用建议关闭增量编译并外置 target 目录（对 overlay/网络文件系统更稳）：

```bash
export CARGO_INCREMENTAL=0
export CARGO_TARGET_DIR="$HOME/tmp/cargo-target"
```

### 推送前自检（与 CI 门禁一致）

CI 对每个 PR 跑 build + test + clippy + fmt。推送前先在本地跑一遍，
避免 lint 问题烧一轮 CI 往返：

```bash
cargo clippy -- -D warnings   # clippy 报警即失败
cargo fmt -- --check          # 有 diff 即未格式化，cargo fmt 修复
```

### GitNexus（需要 Node.js >= 22）

```bash
./gitnexus/install-gitnexus.sh ~/gitnexus-toolchain   # 默认装到 ~/gitnexus-toolchain
export PATH="$HOME/gitnexus-toolchain/bin:$PATH"

cd <你的仓库> && gitnexus analyze   # 索引代码库
gitnexus setup                      # 注册 MCP（Claude Code / Cursor / Codex 等）
```

## 验证

在 Debian 13 (trixie) x86_64 上按上面的步骤实测通过：

- `rust/install-rust.sh` → `rustc 1.99.0 (b940084d7 2026-09-28)`、`cargo 1.99.0 (5f94df478 2026-08-27)`、
  `clippy 0.1.99 (b940084d7e 2026-09-28)`、`rustfmt 1.10.0-stable (b940084d7e 2026-09-28)`；
  `cargo new` + `cargo build` 编译并运行输出 `Hello, world!`，`cargo test` 通过；
  `cargo clippy` 能正确检出 `bool_comparison` 等 lint，`cargo fmt -- --check` 能正确给出格式 diff

`rust/install-rust.sh` 在安装前会按 [`rust/SHA256SUMS`](rust/SHA256SUMS) 校验五个
组件包的官方 SHA256，校验不过直接退出。

## 说明

- 包来源：
  - Rust：`https://static.rust-lang.org/dist/2026-10-01/`（官方发布，MIT / Apache-2.0 双许可）
  - 可自由再分发
- 已知坑：
  - `.tar.xz` 下载中断会产生损坏包（解压时报 `lzma error`），
    重新下载即可；Rust 组件包可用 `sha256sum -c rust/SHA256SUMS` 复核
  - 精简系统（最小化容器、部分 WSL 镜像）常缺 `xz`，`tar -xf` 会报
    `tar (child): xz: Cannot exec`，装 `xz-utils` 即可
  - Windows 上 `core.autocrlf=true` 会把脚本检出成 CRLF，在 Linux/WSL 下报
    `syntax error near unexpected token $'do\r'`；[`.gitattributes`](.gitattributes)
    已强制脚本与 `SHA256SUMS` 使用 LF
