# serial-relay

[简体中文完整手册](README.zh-CN.md) | [Full English Guide](README.en.md)

`serial-relay` is a one-shot command-line tool for controlling a four-channel
relay board through a CH340 USB-to-serial adapter. Each command performs one
operation and exits; it is not a background service.

`serial-relay` 是一个通过 CH340 USB 转串口模块控制四路继电器的命令行工具。
程序每执行一次命令就退出，不是后台服务。

Verified / 已验证环境：

- MYD-YR3506, Debian 12, ARMv7 hard-float (`armhf`)
- CH340 (`1a86:7523`), default device / 默认设备：`/dev/ttyUSB0`
- Serial settings / 串口参数：9600 baud, 8N1
- CH1–CH4 ON, OFF, status query, and state restoration

## 中文快速开始

在 Ubuntu/Debian x86_64 主机上安装工具链并交叉编译 ARMv7 程序：

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
```

部署到设备：

```bash
scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay

ssh myir@192.168.1.49
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

查询和控制继电器：

```bash
# CH1～CH4 对应端口 0～3
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done

serial-relay -p 0 on
serial-relay -p 0 status
serial-relay -p 0 off
```

程序默认使用 `/dev/ttyUSB0`。其他节点可通过
`--device /dev/ttyUSB1` 指定。完整的编译、Debian 打包、权限配置、四路硬件测试、
故障排查和协议说明请阅读[简体中文完整手册](README.zh-CN.md)。

> `on`、`off` 和硬件测试脚本的 `--exercise` 会实际切换继电器。执行前请确认
> 外接负载允许动作。

## English quick start

Install the toolchain and cross-compile for ARMv7 on an x86_64 Ubuntu/Debian
host:

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
```

Deploy it to the device:

```bash
scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay

ssh myir@192.168.1.49
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

Query and control the relays:

```bash
# CH1 through CH4 map to ports 0 through 3
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done

serial-relay -p 0 on
serial-relay -p 0 status
serial-relay -p 0 off
```

The default serial device is `/dev/ttyUSB0`. Use
`--device /dev/ttyUSB1` when the device has another name. See the
[full English guide](README.en.md) for native and cross compilation, Debian
packaging, serial permissions, four-channel hardware tests, troubleshooting,
and protocol details.

> `on`, `off`, and the hardware test script's `--exercise` option physically
> switch the relays. Make sure the connected load can be switched safely.

## Documentation / 文档

| Document / 文档 | Description / 内容 |
|---|---|
| [README.zh-CN.md](README.zh-CN.md) | 中文完整手册：编译、打包、部署、使用、测试和排障 |
| [README.en.md](README.en.md) | Complete English build, deployment, usage, test, and troubleshooting guide |

## License

MIT
