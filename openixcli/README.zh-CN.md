# OpenixCLI 全志烧录工具（ARMv7）

本目录把上游 [OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI) 固定到已验证提交，提供可复现的 ARMv7 交叉编译、部署和只读测试。它不修改任何全志 SDK。

## 本仓库做了什么

- 固定 OpenixCLI `0.2.2` 和完整 Cargo 依赖锁文件。
- 在 Docker 中为 `armv7-unknown-linux-gnueabihf` 编译。
- 内置 libusb，不要求 robot 额外安装 `libusb-1.0.so`。
- 应用一个安全补丁：读取固件内 `sys_config.fex` 的 `storage_type`，与目标设备 FES 返回的存储类型比较；不一致时在擦除和下载前退出。
- `upstream` 分支以子模块保存完全未修改的上游源码；`main` 分支保存本部署包和安全补丁。

上游版本与补丁详情见 [UPSTREAM.md](UPSTREAM.md)。

## 1. 编译

宿主机需要 Git、Docker、`file`、`readelf`。代理变量会自动传给 Docker：

```bash
cd openixcli
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
make check
make build-armv7
```

输出文件：

```text
dist/openixcli-armv7
dist/openixcli-armv7.sha256
```

构建脚本会执行全部上游测试、核对固定提交、应用安全补丁，并检查产物确实为 32 位 ARM ELF 且没有动态依赖 libusb。

## 2. 部署到 robot

默认目标为实验室 robot。脚本不会保存密码；SSH 和 sudo 需要时会正常提示输入。

```bash
make deploy
```

也可以显式指定目标：

```bash
DEVICE_HOST=192.168.1.50 DEVICE_USER=myir make deploy
```

固定安装位置为：

```text
/usr/local/bin/openixcli
```

部署过程会核对上传前后的 SHA256、CPU 架构、版本和最终安装文件。

## 3. 只读测试

```bash
make test-device
```

该命令只做版本、文件类型、SHA256、固件解析和 USB 扫描，不写设备存储。目标没有进入 FEL/FES 时，扫描到 0 台烧录设备是正常结果。

## 4. 进入全志烧录模式

目标串口参数和继电器映射必须先按实验室私有指南确认。常用方式：

1. 重启目标板。
2. U-Boot 启动阶段持续输入 `2`，或进入 U-Boot 命令行后执行 `efex`。
3. 在 robot 扫描，必须确认只出现预期的一台全志设备：

```bash
sudo openixcli --backend libusb scan --detailed
```

4. 烧录前检查镜像并记录 SHA256：

```bash
openixcli inspect /myir/image/T113i/myir_image_yt113i.img
sha256sum /myir/image/T113i/myir_image_yt113i.img
```

## 5. 烧录

### 5.1 整包烧录

> `full_erase` 会删除目标存储中的全部数据。必须先确认目标板、镜像、SHA256、存储类型以及扫描得到的 USB bus/port，并取得明确烧录授权。不要照抄示例中的占位值。

```bash
sudo openixcli --backend libusb flash \
  /myir/image/T113i/myir_image_yt113i.img \
  --bus <SCAN_BUS> \
  --port <SCAN_PORT> \
  --verify true \
  --mode full_erase \
  --post-action reboot
```

烧录成功必须同时满足：命令退出码为 0、各分区和 Boot0/Boot1 校验通过、目标板重启，并通过串口或系统登录确认新系统启动。

### 5.2 单独烧录启动组件

`flash-boot` 从完整 IMAGEWTY 固件包中选择启动组件，只执行所选组件的 FES 下载和校验。
它不会擦除存储器，也不会写入 MBR、普通分区或 Preboot。不要把独立的 `u-boot.bin`
直接作为固件参数；第一个参数仍必须是与目标板匹配的完整 IMAGEWTY 固件包。

| 选择值 | 写入内容 | 适用启动模式 |
|---|---|---|
| `uboot` | 固件中的普通 U-Boot，通过 Boot1 通道写入 | Normal |
| `boot0` | 按目标存储类型选择 Boot0；TOC 模式对应 TOC0 | Normal、Package、TOC |
| `boot-package` | 固件中的 `boot_package.fex`，通过 Boot1 通道写入 | Package |

仅烧录 U-Boot：

```bash
sudo openixcli --backend libusb flash-boot \
  /myir/image/T113i/myir_image_yt113i.img \
  --components uboot \
  --bus <SCAN_BUS> \
  --port <SCAN_PORT> \
  --post-action reboot
```

Normal 模式同时烧录 U-Boot 和 Boot0：

```bash
sudo openixcli --backend libusb flash-boot \
  /myir/image/T113i/myir_image_yt113i.img \
  --components uboot,boot0 \
  --bus <SCAN_BUS> \
  --port <SCAN_PORT> \
  --post-action reboot
```

Package 模式应将 `uboot` 改为 `boot-package`。命令会先核对镜像与目标存储类型，
再核对目标启动模式；选择与目标模式不兼容时会在启动组件下载前退出。多个组件会去重，
并固定按 Boot1、Boot0 的顺序写入。

> 这是高风险恢复功能。必须先执行 `scan --detailed`、`inspect` 和 `sha256sum`，确认目标、
> 镜像、启动模式、存储类型及本次 USB bus/port，并取得明确烧录授权。该独立烧录功能已通过
> 源码自动测试和 ARMv7 构建验证，真机单组件烧录尚未验证。

## 更新上游版本

更新固定提交时，必须重新生成并提交 `Cargo.lock`，重新审查安全补丁，执行全套测试、ARMv7 构建、robot 只读测试和一次经过授权的真实烧录验证，然后同步 `UPSTREAM.md` 与 `upstream` 分支子模块。
