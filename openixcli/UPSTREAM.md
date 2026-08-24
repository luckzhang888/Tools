# Upstream tracking

- Project: [YuzukiTsuru/OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI)
- Branch: `master`
- Pinned commit: `4030a873038d979eed6c69441ef8b6d4b457484b`
- Version: `0.2.2`
- License: MIT; see `LICENSE.openixcli`

The `upstream` branch of this repository tracks the unmodified project as the
`openixcli` submodule. The `main` branch contains the reproducible ARMv7 build,
deployment scripts and the local safety patch used on the auxiliary device.

The local patch reads `storage_type` from the firmware's embedded
`sys_config.fex`, compares it with the storage reported by FES, and rejects a
mismatch before flash-size probing, erase or download operations. It also adds
unit tests for parsing and the pre-erase rejection path.
