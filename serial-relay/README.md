# serial-relay

通过 CH340 USB 串口控制四路继电器的命令行工具，协议为 9600/8N1。

已在 MYD-YR3506（ARMv7、Debian 12）上验证：设备节点 `/dev/ttyUSB0`，
四路均可执行 ON、OFF 和状态回读。

## 功能

- CH1～CH4 独立执行 `on`、`off`、`toggle`、`status`
- 默认设备节点 `/dev/ttyUSB0`，可通过 `--device` 覆盖
- 校验四字节响应的帧头、通道、状态和校验和
- 支持 amd64、arm64、armhf（ARMv7）构建和 Debian 打包
- 提供只读状态检查及自动恢复原状态的硬件测试脚本

## 硬件与权限

- USB 转串口：CH340（VID `1a86`、PID `7523`）
- 默认节点：`/dev/ttyUSB0`
- 推荐节点：`/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`
- 当前用户需要属于 `dialout` 组

```bash
ls -l /dev/ttyUSB0 /dev/serial/by-id/
sudo usermod -aG dialout "$USER"
```

修改用户组后需要重新登录。

## 使用

端口参数从 0 开始：`-p 0`～`-p 3` 分别对应 CH1～CH4。

```bash
# CH1 状态（默认使用 /dev/ttyUSB0）
serial-relay -p 0 status

# CH1 打开和关闭
serial-relay -p 0 on
serial-relay -p 0 off

# 使用不会随 ttyUSB 编号变化的持久路径
serial-relay \
  -d /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 \
  -p 3 status
```

`open` 等价于 `on`，`close` 等价于 `off`。

## 构建

最低 Rust 版本为 1.85。

### 原生构建

```bash
cargo build --release --locked
./target/release/serial-relay --help
```

安装到 `/usr/local/bin`：

```bash
make build
sudo make install
```

### x86_64 主机交叉构建

ARMv7/armhf：

```bash
sudo apt-get install gcc-arm-linux-gnueabihf
rustup target add armv7-unknown-linux-gnueabihf
TARGET=armv7-unknown-linux-gnueabihf make build
```

ARM64：

```bash
sudo apt-get install gcc-aarch64-linux-gnu
rustup target add aarch64-unknown-linux-gnu
TARGET=aarch64-unknown-linux-gnu make build
```

对应输出分别位于：

```text
target/armv7-unknown-linux-gnueabihf/release/serial-relay
target/aarch64-unknown-linux-gnu/release/serial-relay
```

## Debian 包

本机打包：

```bash
./build-deb.sh deb
```

交叉构建 ARMv7 包：

```bash
TARGET=armv7-unknown-linux-gnueabihf \
PKG_ARCH=armhf \
./build-deb.sh deb
```

输出为 `dist/serial-relay_<版本>_<架构>.deb`，安装方式：

```bash
sudo dpkg -i dist/serial-relay_0.1.0_armhf.deb
```

GitHub Actions 会为 amd64、arm64、armhf 构建二进制及 Debian 包。
推送 `serial-relay-v*` 标签时会自动创建 Release。

## 测试

代码检查和单元测试不需要继电器硬件：

```bash
make check
```

只查询四路状态，不改变继电器：

```bash
./scripts/test-device.sh --device /dev/ttyUSB0
```

依次验证四路 ON/OFF，并在退出时恢复测试前状态：

```bash
./scripts/test-device.sh --exercise --device /dev/ttyUSB0
```

`--exercise` 会实际吸合和释放继电器，运行前应确认外接设备允许切换。

## 串口协议

命令和四字节状态响应格式均为：

```text
[0xA0, channel, opcode/state, checksum]
checksum = (0xA0 + channel + opcode/state) & 0xFF
```

| 值 | 含义 |
|---|---|
| channel `0x01`～`0x04` | CH1～CH4 |
| opcode `0x00` | OFF |
| opcode `0x01` | ON |
| opcode `0x04` | TOGGLE |
| opcode `0x05` | STATUS |

例如 CH1 ON 为 `A0 01 01 A2`，CH4 STATUS 为 `A0 04 05 A9`。

## 项目结构

```text
serial-relay/
├── Cargo.toml                 # Rust 包和波特率配置
├── Cargo.lock                 # 固定依赖版本
├── build.rs                   # 将波特率写入编译环境
├── src/main.rs                # CLI 与协议实现、单元测试
├── build-deb.sh               # 构建和 Debian 打包入口
├── scripts/package-deb.sh     # 从二进制生成 .deb
├── scripts/test-device.sh     # 四路硬件测试
├── debian/                    # 标准 Debian 打包元数据
└── Makefile                   # 常用构建命令
```

波特率由 `Cargo.toml` 中的 `[package.metadata].baud_rate` 设置，修改后重新构建。

## License

MIT
