# upgrade-tool ARMv7 构建、部署与使用手册

[English](README.en.md) | [中英文快速开始](README.md)

## 1. 工具用途

`upgrade_tool` 是 Rockchip USB 烧录命令行工具。它运行在一台 Linux 控制端上，
通过 USB 访问另一块处于 Maskrom、Loader 或 MSC 模式的 Rockchip 目标板。

本项目的部署关系是：

```text
x86_64 编译主机
    │ 交叉编译 ARMv7 静态程序
    ▼
MYD-YR3506 控制端（运行 upgrade_tool）
    │ USB Host 数据线
    ▼
待烧录的 Rockchip 目标板（Maskrom/Loader 模式）
```

把工具安装到 MYD-YR3506 不会自动修改 MYD-YR3506 的系统或 SDK。只有连接另一块
Rockchip 目标板并主动执行 `UF`、`UL`、`DI`、`EF` 等命令时，才会改写目标存储器。

## 2. 已验证环境

本流程已经完成以下实际验证：

- 控制端：MYD-YR3506
- 控制端系统：Debian 12
- 控制端架构：`armv7l`，ARM hard-float
- 控制端地址：`192.168.1.49`
- 登录用户：`myir`
- 安装路径：`/usr/local/bin/upgrade_tool`
- 上游仓库：`https://github.com/bitshelf/upgrade_tool.git`
- 固定提交：`ea51edd64f72b338c1d6adb9c21693712f38bd83`
- 上游程序内部版本：`v2.44`
- 构建产物：ELF 32-bit ARM EABI5，完全静态链接
- 实测 SHA256：
  `92a563ab2cb4832fb9cd989c6a2634b50c7edb669ae7006883d0982689cc0d1f`

设备端已通过：

- ARMv7 程序启动
- 无参数帮助页
- `sudo upgrade_tool LD` 只读 USB 枚举
- 静态链接和上传/安装文件 SHA256 一致性检查

验证时没有连接 Rockchip 目标板，所以枚举结果为：

```text
List of rockusb connected(0)
```

这个结果表示工具正常完成扫描，但当前没有 Maskrom/Loader 设备；它不是编译失败。

## 3. 上游源码和授权说明

Tools 仓库没有直接复制上游源码或二进制。构建脚本会获取并核对：

| 组件 | 固定提交 |
|---|---|
| `bitshelf/upgrade_tool` | `ea51edd64f72b338c1d6adb9c21693712f38bd83` |
| `illiliti/libudev-zero` 1.0.3 | `ee32ac5f6494047b9ece26e7a5920650cdf46655` |

在上述 `upgrade_tool` 提交中，`main.cpp` 包含 GPL-3.0-or-later 声明，但仓库没有
顶层 `LICENSE` 或 `COPYING` 文件。重新分发上游源码或二进制前，应向上游确认完整
授权状态。详情见 [UPSTREAM.md](UPSTREAM.md)。

## 4. 获取 Tools 仓库

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/upgrade-tool
```

如果已经克隆：

```bash
cd Tools
git pull --ff-only
cd upgrade-tool
```

后续命令默认在 `Tools/upgrade-tool` 目录执行。

## 5. 构建主机要求

推荐使用 x86_64 Ubuntu 或 Debian 主机。主机需要：

- Git
- Docker
- `file`
- 可访问 GitHub 和 Debian 软件源的网络

Ubuntu/Debian 安装示例：

```bash
sudo apt-get update
sudo apt-get install -y git docker.io file make
sudo usermod -aG docker "$USER"
```

添加 Docker 用户组后需要退出并重新登录。也可以按本机策略使用 `sudo docker`，但
当前脚本默认直接调用 `docker`。

确认环境：

```bash
git --version
docker version
file --version
make --version
```

## 6. 配置网络代理

只有当前网络需要代理时才设置。两条 `export` 必须分成两行：

```bash
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
```

部分工具读取大写变量，也可以同时设置：

```bash
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
```

构建脚本会把小写和大写代理变量传给 `docker build` 和构建容器，不会把代理地址
写入最终二进制。

## 7. ARMv7 交叉编译

先检查脚本语法和必要文件：

```bash
make check
```

开始构建：

```bash
make build-armv7
```

构建脚本会执行以下步骤：

1. 获取 `bitshelf/upgrade_tool` 的固定提交。
2. 获取 `libudev-zero` 1.0.3 对应的固定提交。
3. 构建 Debian 12 ARMhf 交叉编译容器。
4. 使用 `arm-linux-gnueabihf-g++` 和 ARMhf `libusb` 编译。
5. 校验产物是 32 位 ARM 且完全静态链接。
6. 生成二进制和 SHA256 文件。

输出文件：

```text
dist/upgrade_tool-armhf-static
dist/upgrade_tool-armhf-static.sha256
```

检查产物：

```bash
file dist/upgrade_tool-armhf-static
(cd dist && sha256sum --check upgrade_tool-armhf-static.sha256)
```

正确的 `file` 输出应包含：

```text
ELF 32-bit ... ARM, EABI5 ... statically linked
```

首次执行会下载 Debian 容器和交叉编译依赖，后续构建会复用 Docker 缓存。

### 7.1 自定义构建目录

默认构建缓存位于 `build/armv7`。可以改到其他磁盘：

```bash
BUILD_ROOT=/data/build/upgrade-tool-armv7 make build-armv7
```

自定义输出目录：

```bash
DIST_DIR=/data/artifacts ./scripts/build-armv7.sh
```

`build/` 和 `dist/` 已被 `.gitignore` 排除，不会误提交二进制和上游源码。

## 8. 部署到 MYD-YR3506

默认部署参数：

```text
DEVICE_USER=myir
DEVICE_HOST=192.168.1.49
INSTALL_PATH=/usr/local/bin/upgrade_tool
```

执行：

```bash
make deploy
```

脚本会：

1. 拒绝部署非 ARMv7 文件。
2. 上传到 `/tmp/upgrade_tool.new`。
3. 比较本地与远端 SHA256。
4. 在临时路径运行帮助页，确认程序可启动。
5. 使用 `sudo install` 写入 `/usr/local/bin/upgrade_tool`。
6. 再次显示架构和 SHA256。

脚本会提示输入 SSH 密码和 `sudo` 密码，但不会记录密码。

自定义设备：

```bash
DEVICE_USER=myir \
DEVICE_HOST=192.168.1.49 \
make deploy
```

自定义二进制：

```bash
BINARY=/data/artifacts/upgrade_tool-armhf-static \
./scripts/deploy.sh
```

### 8.1 SSH 主机密钥变化

如果出现：

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

不要直接关闭主机密钥检查。先通过串口、设备标签或管理员提供的信息核对当前设备的
SSH 指纹。确认设备系统确实被重装或重新生成密钥后，再更新 `known_hosts`。

也可以为单次部署准备独立的已核对密钥文件：

```bash
ssh-keyscan -T 5 192.168.1.49 > /tmp/upgrade-tool-known-hosts
ssh-keygen -lf /tmp/upgrade-tool-known-hosts

KNOWN_HOSTS_FILE=/tmp/upgrade-tool-known-hosts make deploy
KNOWN_HOSTS_FILE=/tmp/upgrade-tool-known-hosts make test-device
```

必须通过可信渠道核对 `ssh-keygen` 显示的指纹后再输入密码。

## 9. 安全的设备端验证

运行仓库提供的只读检查：

```bash
make test-device
```

它只执行：

- 检查 `/usr/local/bin/upgrade_tool` 是否存在并可执行
- 检查 ELF 架构
- 读取无参数帮助页
- 使用 `sudo upgrade_tool LD` 枚举 Rockchip USB 设备
- 显示 `lsusb`

不会下载镜像、写入分区或擦除 Flash。

也可以手动执行：

```bash
ssh myir@192.168.1.49
file /usr/local/bin/upgrade_tool
sha256sum /usr/local/bin/upgrade_tool
upgrade_tool
sudo upgrade_tool LD
lsusb
```

## 10. 连接 Rockchip 目标板

1. 确认 MYD-YR3506 使用的是 USB Host 口。
2. 使用支持数据传输的 USB 线连接目标板。
3. 让目标板进入 Loader 或 Maskrom 模式。
4. 在控制端检查 Rockchip USB VID：

```bash
lsusb | grep -i 2207
```

5. 使用 `upgrade_tool` 枚举：

```bash
sudo upgrade_tool LD
```

有设备时会显示类似：

```text
DevNo=1  Vid=0x2207,Pid=0x....  LocationID=...  Mode=Loader
```

具体 PID 和模式取决于 Rockchip SoC、Loader 和启动状态。

默认建议使用 `sudo`，因为烧录需要直接访问 `/dev/bus/usb`。本项目没有自动安装
宽松的 udev 规则，避免普通用户意外获得写入所有 Rockchip USB 设备的权限。

## 11. 命令说明和风险分级

无参数显示内置帮助：

```bash
upgrade_tool
```

### 11.1 只读或低风险命令

| 命令 | 用途 | 备注 |
|---|---|---|
| `LD` | 列出 Rockchip USB 设备 | 不写入存储器 |
| `PL` | 读取分区列表 | 需要已连接设备 |
| `RSN` | 读取序列号 | 需要已连接设备 |
| `RID` | 读取 Flash ID | 需要已连接设备 |
| `RFI` | 读取 Flash 信息 | 需要已连接设备 |
| `RCI` | 读取芯片信息 | 需要已连接设备 |
| `CPU` | 读取 CPUID | 注意输出中可能包含设备唯一标识 |
| `RSM` | 读取安全模式 | 不修改安全状态 |
| `SFI <Firmware>` | 查看固件信息 | 读取本地固件文件 |
| `EXF <Firmware> <Dir>` | 解包固件 | 写本地输出目录，不写目标 Flash |

`V` 是版本命令，但上游程序可能仍先扫描 USB；未连接设备或权限不足时可能先输出
`No found any rockusb device` 并返回 255。确认程序能启动时应直接运行无参数帮助页。

### 11.2 会修改目标设备的高风险命令

| 命令 | 作用 |
|---|---|
| `UF <Firmware>` | 烧录完整 Rockchip 固件 |
| `UL <Loader>` | 升级 Loader |
| `DI ...` | 下载分区镜像 |
| `DB <Loader>` | 向 Maskrom 设备下载启动 Loader |
| `EF <Loader|Firmware>` | 擦除 Flash |
| `SN <serial>` | 写入序列号 |
| `GPT ...` | 创建 GPT 数据 |
| `WL ...` | 写 LBA 扇区 |
| `EL ...` | 擦除 LBA 范围 |
| `EB ...` | 擦除块 |
| `RD` | 复位目标设备 |

执行高风险命令前必须确认：

- 镜像适用于确切的 SoC 和板卡型号
- Loader 与 DDR、存储器和电源配置匹配
- 目标是正确的 USB 设备
- 已备份序列号、校准数据、分区表和必要分区
- 供电和 USB 连接稳定
- 已准备 Maskrom 恢复方案

## 12. 常见烧录流程

下面只说明命令关系，不代表任意镜像都可以安全烧录。

Loader 模式下烧录完整 `update.img`：

```bash
sudo upgrade_tool LD
sudo upgrade_tool UF /path/to/update.img
```

Maskrom 模式通常需要先把匹配的 Loader 下载到 RAM，再执行后续操作：

```bash
sudo upgrade_tool LD
sudo upgrade_tool DB /path/to/MiniLoaderAll.bin
sudo upgrade_tool LD
sudo upgrade_tool UF /path/to/update.img
```

不要在未确认 Loader 和镜像匹配时复制执行这些命令。

## 13. 常见问题

### 13.1 `List of rockusb connected(0)`

工具运行正常，但没有发现目标。检查：

```bash
lsusb
lsusb | grep -i 2207
sudo upgrade_tool LD
```

然后检查 USB Host 端口、数据线、目标板供电以及 Loader/Maskrom 进入方法。

### 13.2 `No found any rockusb device, please plug device in`

某些命令在执行自身功能前要求存在 Rockchip USB 设备。先执行：

```bash
sudo upgrade_tool LD
```

若 `LD` 仍为 0 台，问题在 USB 连接或启动模式，不是固件命令参数。

### 13.3 `Permission denied` 或 `LIBUSB_ERROR_ACCESS`

使用：

```bash
sudo upgrade_tool LD
```

如果必须非 root 使用，应按组织安全策略创建只允许 VID `2207` 的 udev 规则，不建议
直接把所有 USB 设备设置为 `0666`。

### 13.4 `Exec format error`

检查：

```bash
uname -m
file /usr/local/bin/upgrade_tool
```

本项目的产物适用于 `armv7l`/`armhf`。`aarch64` 或 `x86_64` 二进制不能在当前
ARMv7 设备上运行。

### 13.5 构建时无法访问 GitHub 或 Debian 软件源

逐行设置代理：

```bash
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
make build-armv7
```

不要写成两条 `export` 粘在同一行且没有空格的形式。

### 13.6 构建目录包含本地修改

为保证固定提交可复现，脚本发现 `build/armv7` 中的上游源码有已跟踪修改时会拒绝
继续。请先保存需要的修改，或使用新的构建目录：

```bash
BUILD_ROOT=/tmp/upgrade-tool-clean-build make build-armv7
```

## 14. 卸载

```bash
ssh myir@192.168.1.49
sudo rm /usr/local/bin/upgrade_tool
```

程序运行时可能在用户目录下创建 `upgrade_tool/log/`。确认日志不再需要后再单独处理，
卸载脚本不会自动删除用户数据。

## 15. 项目结构

```text
upgrade-tool/
├── Dockerfile.armv7          # Debian 12 ARMhf 交叉编译环境
├── Makefile                  # check/build/deploy/test 入口
├── cmake/
│   └── toolchain-armv7.cmake # ARMv7 CMake 工具链
├── scripts/
│   ├── build-armv7.sh        # 固定上游提交并生成静态产物
│   ├── deploy.sh             # SHA256 校验后部署
│   └── test-device.sh        # 只读远端验证
├── UPSTREAM.md               # 上游版本和授权注意事项
├── README.md                 # 中英文快速开始
├── README.zh-CN.md           # 中文完整手册
└── README.en.md              # 英文完整手册
```
