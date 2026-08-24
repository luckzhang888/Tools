# Tools — upstream sources / 上游源码

[中文](#中文) | [English](#english)

## 中文

此分支保存工具的原始上游内容，不包含 `main` 分支中的部署适配和安全补丁。

| 工具 | 保存方式 | 上游来源 |
|---|---|---|
| [serial-relay](serial-relay/) | 普通源码目录 | 项目最初直接导入本仓库，没有独立的外部上游仓库 |
| [upgrade-tool](upgrade-tool/) | Git 子模块 | [bitshelf/upgrade_tool](https://github.com/bitshelf/upgrade_tool) |
| [openixcli](openixcli/) | Git 子模块 | [YuzukiTsuru/OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI) |

GitHub 显示的 `openixcli @ 4030a87`、`upgrade-tool @ ea51edd` 表示子模块固定在某个上游提交，
其中 `@ <提交号>` 不是目录后缀。`serial-relay` 是普通目录，所以不会显示该标记。

克隆此分支及其子模块：

```bash
git clone --branch upstream --recurse-submodules \
  https://github.com/luckzhang888/Tools.git
```

需要编译、部署和完整使用说明时，请切换到 [`main`](https://github.com/luckzhang888/Tools/tree/main) 分支。

## English

This branch preserves the original upstream content. It excludes the deployment
adaptations and safety patches maintained on `main`.

| Tool | Storage | Upstream source |
|---|---|---|
| [serial-relay](serial-relay/) | Normal source directory | Originally imported directly into this repository; no independent external upstream repository exists |
| [upgrade-tool](upgrade-tool/) | Git submodule | [bitshelf/upgrade_tool](https://github.com/bitshelf/upgrade_tool) |
| [openixcli](openixcli/) | Git submodule | [YuzukiTsuru/OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI) |

GitHub labels such as `openixcli @ 4030a87` and `upgrade-tool @ ea51edd` mean
that a submodule is pinned to an upstream commit. The `@ <commit>` text is not a
directory suffix. `serial-relay` is a normal directory, so it has no such label.

Clone this branch together with its submodules:

```bash
git clone --branch upstream --recurse-submodules \
  https://github.com/luckzhang888/Tools.git
```

For build, deployment, and complete usage documentation, use the
[`main`](https://github.com/luckzhang888/Tools/tree/main) branch.
