# Tools

[中文](#中文) | [English](#english)

## 中文

嵌入式设备辅助工具集合。

### 分支

- `main`：经过适配、构建和验证的版本，日常使用请选择此分支。
- `upstream`：保留外部项目的原始上游提交，以及 `serial-relay` 的原始源码快照。

### 工具

| 工具 | 类型 | 说明 | 编译与使用 |
|---|---|---|---|
| [serial-relay](serial-relay/) | 仓库内源码 | 通过 CH340 串口控制四路继电器，支持 amd64、arm64 和 armhf | [中英文入口](serial-relay/README.md) · [中文手册](serial-relay/README.zh-CN.md) · [English guide](serial-relay/README.en.md) |
| [upgrade-tool](upgrade-tool/) | 修改后的源码 | Rockchip USB 烧录工具的可复现 ARMv7 构建、部署和使用文档 | [使用说明](upgrade-tool/README.md) |
| [openixcli](openixcli/) | 修改后的源码 | 全志 USB 烧录工具的可复现 ARMv7 构建、部署和安全检查 | [中英文说明](openixcli/README.md) |

GitHub 目录名称后的 `@ <提交号>` 表示该目录是 Git 子模块，并不是文件名后缀。
`serial-relay` 没有独立的外部上游仓库，因此作为普通源码目录保存，不显示 `@ <提交号>`。

克隆日常使用版本：

```bash
git clone --recurse-submodules https://github.com/luckzhang888/Tools.git
```

## English

A collection of helper tools for embedded-device development and flashing.

### Branches

- `main`: adapted, built, and verified versions intended for normal use.
- `upstream`: original external upstream revisions plus the original
  `serial-relay` source snapshot.

### Tools

| Tool | Storage | Description | Build and usage |
|---|---|---|---|
| [serial-relay](serial-relay/) | In-repository source | Controls a four-channel relay board through a CH340 serial adapter; supports amd64, arm64, and armhf | [Bilingual entry](serial-relay/README.md) · [中文手册](serial-relay/README.zh-CN.md) · [English guide](serial-relay/README.en.md) |
| [upgrade-tool](upgrade-tool/) | Modified source | Reproducible ARMv7 build, deployment, and usage support for the Rockchip USB flashing tool | [Guide](upgrade-tool/README.md) |
| [openixcli](openixcli/) | Modified source | Reproducible ARMv7 build, deployment, and safety checks for the Allwinner USB flashing tool | [Bilingual guide](openixcli/README.md) |

The `@ <commit>` text shown after a directory name on GitHub identifies a Git
submodule pinned to a commit; it is not a filename suffix. `serial-relay` has no
independent external upstream repository, so it is stored as a normal source
directory and has no `@ <commit>` marker.

Clone the normal-use branch:

```bash
git clone --recurse-submodules https://github.com/luckzhang888/Tools.git
```
