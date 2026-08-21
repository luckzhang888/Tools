# upgrade-tool ARMv7 deployment kit

[简体中文完整手册](README.zh-CN.md) | [Full English Guide](README.en.md)

This directory provides reproducible ARMv7 build, deployment, and read-only
test helpers for [bitshelf/upgrade_tool](https://github.com/bitshelf/upgrade_tool).
It does not copy the upstream source or compiled binary into this repository.

本目录为 [bitshelf/upgrade_tool](https://github.com/bitshelf/upgrade_tool)
提供可复现的 ARMv7 构建、部署和只读测试脚本。上游源码和编译产物不直接复制到本仓库。

> `upgrade_tool` runs on a controller host and flashes a different Rockchip
> target connected over USB. Installing it on MYD-YR3506 does not by itself
> flash the MYD-YR3506.
>
> `upgrade_tool` 运行在控制端，通过 USB 烧录另一块 Rockchip 目标板。把它安装到
> MYD-YR3506 并不会自动烧录 MYD-YR3506 本身。

Verified / 已验证：

- Controller / 控制端：MYD-YR3506, Debian 12, ARMv7 hard-float
- Installed path / 安装路径：`/usr/local/bin/upgrade_tool`
- Upstream commit / 上游提交：`ea51edd64f72b338c1d6adb9c21693712f38bd83`
- Output / 产物：32-bit ARM EABI5, fully static / 完全静态链接
- Safe tests / 安全测试：startup, help, `LD` USB enumeration

## 中文快速开始

在 x86_64 Ubuntu/Debian 主机上：

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/upgrade-tool

# 如果当前网络需要代理，每条 export 必须单独一行
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999

make check
make build-armv7
file dist/upgrade_tool-armhf-static
(cd dist && sha256sum --check upgrade_tool-armhf-static.sha256)
```

部署和只读测试：

```bash
make deploy
make test-device
```

默认设备为 `myir@192.168.1.49`。脚本会要求输入 SSH 密码和 `sudo` 密码，
不会保存密码。完整说明见[中文手册](README.zh-CN.md)。

连接处于 Maskrom/Loader 模式的 Rockchip 目标板后，只读枚举：

```bash
lsusb | grep -i 2207
sudo upgrade_tool LD
```

`UF`、`UL`、`DI`、`EF`、`WL`、`EL` 等命令会写入或擦除目标存储器，必须先
确认镜像、芯片型号、存储类型和恢复方案。

## English quick start

On an x86_64 Ubuntu/Debian host:

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/upgrade-tool

# Set these only when the network requires this proxy.
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999

make check
make build-armv7
file dist/upgrade_tool-armhf-static
(cd dist && sha256sum --check upgrade_tool-armhf-static.sha256)
```

Deploy and run the read-only test:

```bash
make deploy
make test-device
```

The default destination is `myir@192.168.1.49`. The scripts prompt for SSH
and `sudo` passwords and never store them. See the
[English guide](README.en.md) for full instructions.

After connecting a Rockchip target in Maskrom or Loader mode, enumerate it
without writing flash:

```bash
lsusb | grep -i 2207
sudo upgrade_tool LD
```

Commands such as `UF`, `UL`, `DI`, `EF`, `WL`, and `EL` write or erase target
storage. Verify the image, SoC, storage type, and recovery procedure first.

## Documentation / 文档

| File | Description |
|---|---|
| [README.zh-CN.md](README.zh-CN.md) | 中文构建、部署、使用和故障排查手册 |
| [README.en.md](README.en.md) | Complete English build, deployment, usage, and troubleshooting guide |
| [UPSTREAM.md](UPSTREAM.md) | Fixed upstream revisions and licensing caveat / 上游版本和授权说明 |

## Repository contents / 目录内容

```text
upgrade-tool/
├── Dockerfile.armv7
├── Makefile
├── cmake/toolchain-armv7.cmake
├── scripts/build-armv7.sh
├── scripts/deploy.sh
├── scripts/test-device.sh
├── UPSTREAM.md
├── README.md
├── README.zh-CN.md
└── README.en.md
```
