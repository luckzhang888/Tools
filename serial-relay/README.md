# serial-relay

`serial-relay` 是一个通过 CH340 USB 转串口模块控制四路继电器的命令行工具。
程序每执行一次命令就退出，不是后台服务，也不需要配置开机启动。

项目已在以下环境完成实际验证：

- 设备：MYD-YR3506
- 系统：Debian 12
- CPU 架构：ARMv7 hard-float（Debian 架构名 `armhf`）
- 串口节点：`/dev/ttyUSB0`
- USB 芯片：CH340，VID:PID 为 `1a86:7523`
- 串口参数：9600 baud、8N1
- 验证结果：CH1～CH4 的 ON、OFF、状态查询和状态恢复全部通过

## 快速开始：从 x86_64 主机部署到 MYD-YR3506

如果只需要完成当前 MYD-YR3506 的编译和部署，可以直接执行这一组命令。

在 Ubuntu/Debian x86_64 主机上：

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/serial-relay

sudo apt-get update
sudo apt-get install -y curl build-essential \
  gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf file

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustup target add armv7-unknown-linux-gnueabihf

TARGET=armv7-unknown-linux-gnueabihf make build
file target/armv7-unknown-linux-gnueabihf/release/serial-relay

scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay
```

登录设备并安装：

```bash
ssh myir@192.168.1.49
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

在设备上查询四路状态：

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done
```

如果上述任一步失败，请继续阅读对应章节和“常见问题”。

## 1. 功能和参数

支持四种主要操作：

| 操作 | 命令参数 | 说明 |
|---|---|---|
| 打开继电器 | `on` | 继电器吸合 |
| 关闭继电器 | `off` | 继电器释放 |
| 翻转状态 | `toggle` | ON 变 OFF，OFF 变 ON |
| 查询状态 | `status` | 查询并校验继电器返回的数据 |

通道参数从 0 开始：

| 实际接口 | `--port` 参数 | 简写 |
|---|---:|---|
| CH1 | `0` | `-p 0` |
| CH2 | `1` | `-p 1` |
| CH3 | `2` | `-p 2` |
| CH4 | `3` | `-p 3` |

串口节点默认是 `/dev/ttyUSB0`，所以大多数情况下不需要传 `-d`：

```bash
serial-relay -p 0 status
```

完整命令格式：

```text
serial-relay [--device <串口节点>] --port <0到3> <on|off|toggle|status>
```

查看程序内置帮助：

```bash
serial-relay --help
serial-relay --version
```

## 2. 获取源码

在 Ubuntu、Debian 或目标设备上执行：

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/serial-relay
```

如果已经克隆过仓库：

```bash
cd Tools
git pull --ff-only
cd serial-relay
```

后续所有编译命令都应在 `Tools/serial-relay` 目录中执行。

## 3. 安装 Rust 编译环境

最低支持 Rust 1.85，建议使用 rustup 安装当前稳定版。

先安装基础工具：

```bash
sudo apt-get update
sudo apt-get install -y curl build-essential file binutils
```

安装 Rust：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

确认环境：

```bash
rustc --version
cargo --version
```

如果 `rustc` 版本低于 1.85：

```bash
rustup update stable
rustup default stable
```

## 4. 编译方式

首先确认编译主机的架构：

```bash
uname -m
```

常见输出与含义：

| `uname -m` 输出 | 架构 | Debian 包架构 |
|---|---|---|
| `x86_64` | PC/服务器 64 位 x86 | `amd64` |
| `aarch64` | 64 位 ARM | `arm64` |
| `armv7l` | 32 位 ARMv7 hard-float | `armhf` |

### 4.1 在目标设备上原生编译

适用于设备本身已经安装 Rust 和 GCC 的情况。进入源码目录后执行：

```bash
cargo build --release --locked
```

也可以使用 Makefile：

```bash
make build
```

输出文件：

```text
target/release/serial-relay
```

检查文件架构和程序版本：

```bash
file target/release/serial-relay
target/release/serial-relay --version
```

直接从构建目录查询 CH1：

```bash
./target/release/serial-relay -p 0 status
```

### 4.2 在 x86_64 Ubuntu/Debian 主机上交叉编译 ARMv7

MYD-YR3506 是 `armv7l`，需要使用 Rust 目标
`armv7-unknown-linux-gnueabihf`，不能使用 ARM64 程序。

安装 ARMv7 交叉编译器：

```bash
sudo apt-get update
sudo apt-get install -y gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf file
```

安装 Rust ARMv7 标准库：

```bash
rustup target add armv7-unknown-linux-gnueabihf
```

开始编译：

```bash
TARGET=armv7-unknown-linux-gnueabihf make build
```

等价的 Cargo 命令：

```bash
cargo build --release --locked --target armv7-unknown-linux-gnueabihf
```

输出文件：

```text
target/armv7-unknown-linux-gnueabihf/release/serial-relay
```

确认输出确实是 ARMv7 32 位程序：

```bash
file target/armv7-unknown-linux-gnueabihf/release/serial-relay
```

正确输出应包含类似内容：

```text
ELF 32-bit LSB ... ARM, EABI5 ... interpreter /lib/ld-linux-armhf.so.3
```

### 4.3 在 x86_64 Ubuntu/Debian 主机上交叉编译 ARM64

ARM64 设备使用下面的流程；不要把这个产物部署到 `armv7l` 设备。

```bash
sudo apt-get update
sudo apt-get install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu file
rustup target add aarch64-unknown-linux-gnu
TARGET=aarch64-unknown-linux-gnu make build
```

输出文件：

```text
target/aarch64-unknown-linux-gnu/release/serial-relay
```

### 4.4 运行代码检查和单元测试

这些检查不操作继电器硬件：

```bash
make check
```

它依次执行：

```bash
cargo fmt -- --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

当前包含 5 个单元测试，覆盖默认设备节点、动作码、四路数据包、状态解析及错误响应。

## 5. 生成 Debian 安装包

### 5.1 生成当前主机架构的包

```bash
./build-deb.sh deb
```

例如在 x86_64 主机上会生成：

```text
dist/serial-relay_0.1.0_amd64.deb
```

### 5.2 在 x86_64 主机上生成 ARMv7/armhf 包

先完成“4.2 交叉编译 ARMv7”中的交叉工具链安装，然后执行：

```bash
TARGET=armv7-unknown-linux-gnueabihf \
PKG_ARCH=armhf \
./build-deb.sh deb
```

输出文件：

```text
dist/serial-relay_0.1.0_armhf.deb
```

检查包信息和文件内容：

```bash
dpkg-deb --info dist/serial-relay_0.1.0_armhf.deb
dpkg-deb --contents dist/serial-relay_0.1.0_armhf.deb
```

### 5.3 在 x86_64 主机上生成 ARM64 包

```bash
TARGET=aarch64-unknown-linux-gnu \
PKG_ARCH=arm64 \
./build-deb.sh deb
```

输出文件：

```text
dist/serial-relay_0.1.0_arm64.deb
```

查看构建脚本支持的参数：

```bash
./build-deb.sh --help
```

## 6. 部署到 MYD-YR3506

以下示例设备地址为 `192.168.1.49`，用户为 `myir`。

### 6.1 部署 ARMv7 二进制

在交叉编译主机上执行：

```bash
scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay
```

登录设备：

```bash
ssh myir@192.168.1.49
```

在设备上检查并安装：

```bash
uname -m
file /tmp/serial-relay
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

确认安装结果：

```bash
command -v serial-relay
serial-relay --version
```

预期安装路径：

```text
/usr/local/bin/serial-relay
```

### 6.2 使用 armhf Debian 包安装

在交叉编译主机上上传：

```bash
scp dist/serial-relay_0.1.0_armhf.deb myir@192.168.1.49:/tmp/
```

在设备上安装：

```bash
ssh myir@192.168.1.49
sudo dpkg -i /tmp/serial-relay_0.1.0_armhf.deb
rm /tmp/serial-relay_0.1.0_armhf.deb
```

确认 Debian 包和命令：

```bash
dpkg -s serial-relay
serial-relay --version
```

### 6.3 卸载

如果是复制二进制安装：

```bash
sudo rm /usr/local/bin/serial-relay
```

如果是 Debian 包安装：

```bash
sudo dpkg -r serial-relay
```

## 7. 确认串口设备

插入 CH340 后检查 USB 设备：

```bash
lsusb | grep -i '1a86:7523'
```

检查串口节点：

```bash
ls -l /dev/ttyUSB* 2>/dev/null
ls -l /dev/serial/by-id/ 2>/dev/null
```

本项目验证设备上的结果为：

```text
/dev/ttyUSB0
/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 -> ../../ttyUSB0
```

确认持久路径最终指向哪个节点：

```bash
readlink -f /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
```

`/dev/ttyUSB0` 的编号可能在重新插拔或连接多个 USB 串口后变化。用于长期脚本时，推荐使用 `/dev/serial/by-id/...`。

## 8. 配置串口访问权限

查看当前节点权限和用户组：

```bash
ls -l /dev/ttyUSB0
id
```

设备节点通常属于 `root:dialout`。如果当前用户不在 `dialout` 组：

```bash
sudo usermod -aG dialout "$USER"
```

然后退出 SSH 并重新登录：

```bash
exit
ssh myir@192.168.1.49
```

确认权限：

```bash
id
test -r /dev/ttyUSB0 && echo readable=yes
test -w /dev/ttyUSB0 && echo writable=yes
```

## 9. 使用方法

### 9.1 查询四路状态

```bash
serial-relay -p 0 status
serial-relay -p 1 status
serial-relay -p 2 status
serial-relay -p 3 status
```

也可以使用循环：

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done
```

正常的 CH1 OFF 返回示例：

```text
Device: /dev/ttyUSB0, CH1, Action: STATUS
Sent: A0 01 05 A6 (checksum=0xA6)
CH1 status: OFF (response: A0 01 00 A1)
```

正常的 CH1 ON 返回示例：

```text
CH1 status: ON (response: A0 01 01 A2)
```

### 9.2 控制 CH1

```bash
# CH1 吸合
serial-relay -p 0 on

# 查询并确认 CH1 已经 ON
serial-relay -p 0 status

# CH1 释放
serial-relay -p 0 off

# 查询并确认 CH1 已经 OFF
serial-relay -p 0 status
```

### 9.3 控制 CH2～CH4

```bash
# CH2
serial-relay -p 1 on
serial-relay -p 1 status
serial-relay -p 1 off

# CH3
serial-relay -p 2 on
serial-relay -p 2 status
serial-relay -p 2 off

# CH4
serial-relay -p 3 on
serial-relay -p 3 status
serial-relay -p 3 off
```

### 9.4 翻转状态

```bash
serial-relay -p 2 toggle
serial-relay -p 2 status
```

### 9.5 指定其他串口节点

使用短参数：

```bash
serial-relay -d /dev/ttyUSB1 -p 0 status
```

使用完整参数：

```bash
serial-relay --device /dev/ttyUSB1 --port 0 status
```

使用持久设备路径：

```bash
serial-relay \
  --device /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 \
  --port 0 status
```

### 9.6 一次操作全部通道

下面的命令会实际改变四路继电器状态，执行前应确认外接负载允许切换。

全部打开：

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" on
done
```

全部关闭：

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" off
done
```

建议在 ON/OFF 后再执行 `status`，确认继电器实际返回的状态。

兼容别名：`open` 等价于 `on`，`close` 等价于 `off`。为避免歧义，建议脚本统一使用 `on` 和 `off`。

## 10. 硬件测试脚本

测试脚本位于：

```text
scripts/test-device.sh
```

### 10.1 只读查询

下面的命令只查询四路状态，不改变继电器：

```bash
./scripts/test-device.sh --device /dev/ttyUSB0
```

如果程序不在 `PATH` 中，可以指定二进制：

```bash
./scripts/test-device.sh \
  --binary ./target/release/serial-relay \
  --device /dev/ttyUSB0
```

### 10.2 完整 ON/OFF 测试

```bash
./scripts/test-device.sh --exercise --device /dev/ttyUSB0
```

完整测试流程为：

```text
记录 CH1～CH4 初始状态
  -> 每路依次 ON
  -> 查询确认 ON
  -> 每路依次 OFF
  -> 查询确认 OFF
  -> 恢复测试前状态
  -> 再次查询确认恢复成功
```

`--exercise` 会让继电器实际吸合和释放。运行前必须确认外接设备、负载和机械机构允许动作。

## 11. 退出状态与错误判断

命令成功时退出码为 0：

```bash
serial-relay -p 0 status
echo "$?"
```

以下情况会返回非 0：

- 无法打开串口节点
- 当前用户没有读写权限
- 串口写入或读取失败
- 状态查询超时
- 返回帧长度错误
- 返回帧头、通道、状态或校验和错误

在 shell 脚本中可以这样判断：

```bash
if serial-relay -p 0 status; then
  echo "CH1 查询成功"
else
  echo "CH1 查询失败" >&2
fi
```

## 12. 常见问题

### 12.1 `No such file or directory` 或找不到 `/dev/ttyUSB0`

检查设备是否枚举：

```bash
lsusb
ls -l /dev/ttyUSB*
dmesg | tail -50
```

如果实际节点是 `/dev/ttyUSB1`，使用：

```bash
serial-relay -d /dev/ttyUSB1 -p 0 status
```

### 12.2 `Permission denied`

```bash
ls -l /dev/ttyUSB0
id
sudo usermod -aG dialout "$USER"
```

修改用户组后需要重新登录，当前 SSH 会话不会自动获得新组权限。

### 12.3 `Exec format error`

部署了错误架构的程序。分别检查设备和二进制：

```bash
uname -m
file /usr/local/bin/serial-relay
```

- `armv7l` 设备应使用 `armv7-unknown-linux-gnueabihf`/`armhf` 产物
- `aarch64` 设备应使用 `aarch64-unknown-linux-gnu`/`arm64` 产物

### 12.4 `query timed out (no response)`

依次检查：

1. USB 串口节点是否选择正确。
2. 用户是否有串口读写权限。
3. 继电器板是否正确供电。
4. TX、RX、GND 是否正确连接，共地是否可靠。
5. 继电器协议是否确实为 9600/8N1。
6. 是否有其他程序正在占用同一个串口。

检查串口占用：

```bash
sudo fuser -v /dev/ttyUSB0
```

### 12.5 ON/OFF 命令显示成功，但不确定继电器是否动作

ON/OFF 命令发送完成后，再执行状态查询：

```bash
serial-relay -p 0 on
serial-relay -p 0 status
```

只有状态返回中出现 `status: ON`，才能确认模块回报为 ON。

### 12.6 修改波特率

波特率在编译时从 `Cargo.toml` 读取：

```toml
[package.metadata]
baud_rate = 9600
```

修改后重新编译并部署：

```bash
cargo clean
cargo build --release --locked
```

## 13. 串口协议

命令帧和四字节状态响应格式：

```text
[0xA0, channel, opcode/state, checksum]
checksum = (0xA0 + channel + opcode/state) & 0xFF
```

| 字节 | 含义 |
|---|---|
| `0xA0` | 固定帧头 |
| `0x01`～`0x04` | CH1～CH4 |
| `0x00` | OFF |
| `0x01` | ON |
| `0x04` | TOGGLE |
| `0x05` | STATUS 查询 |

常用命令帧：

| 操作 | 数据 |
|---|---|
| CH1 ON | `A0 01 01 A2` |
| CH1 OFF | `A0 01 00 A1` |
| CH1 STATUS | `A0 01 05 A6` |
| CH2 ON | `A0 02 01 A3` |
| CH2 OFF | `A0 02 00 A2` |
| CH3 ON | `A0 03 01 A4` |
| CH3 OFF | `A0 03 00 A3` |
| CH4 ON | `A0 04 01 A5` |
| CH4 OFF | `A0 04 00 A4` |
| CH4 STATUS | `A0 04 05 A9` |

## 14. GitHub Actions 自动构建

仓库根目录的 `.github/workflows/serial-relay.yml` 会在以下情况下运行：

- 修改 `serial-relay/` 后推送到 `main`
- 针对 `main` 创建或更新 Pull Request
- 修改工作流文件本身

流水线会执行单元测试，并分别生成：

- amd64 二进制和 Debian 包
- arm64 二进制和 Debian 包
- armhf/ARMv7 二进制和 Debian 包

推送 `serial-relay-v*` 标签时还会自动创建 GitHub Release：

```bash
git tag serial-relay-v0.1.0
git push origin serial-relay-v0.1.0
```

## 15. 项目结构

```text
serial-relay/
├── Cargo.toml                 # Rust 包配置和波特率
├── Cargo.lock                 # 固定依赖版本
├── build.rs                   # 将波特率传给程序
├── src/main.rs                # CLI、协议实现和单元测试
├── .cargo/config.toml         # ARM 交叉链接器配置
├── Makefile                   # build/check/test/deb/install 等入口
├── build-deb.sh               # 多架构构建和 Debian 打包入口
├── scripts/package-deb.sh     # 从二进制生成 .deb
├── scripts/test-device.sh     # 四路硬件测试与状态恢复
├── debian/                    # 标准 Debian 打包元数据
└── README.md                  # 本文档
```

## License

MIT
