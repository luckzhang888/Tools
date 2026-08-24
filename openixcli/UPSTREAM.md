# Upstream tracking

- Project: [YuzukiTsuru/OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI)
- Branch: `master`
- Pinned commit: `4030a873038d979eed6c69441ef8b6d4b457484b`
- Version: `0.2.2`
- License: MIT; see `LICENSE.openixcli`

The `upstream` branch of this repository tracks the unmodified project as the
`openixcli` submodule. The `main` branch contains the reproducible ARMv7 build,
deployment scripts and local patches used on the auxiliary device.

Local patches:

1. `0001-reject-storage-type-mismatch.patch` reads `storage_type` from the
   firmware's embedded `sys_config.fex`, compares it with the storage reported
   by FES, and rejects a mismatch before flash-size probing, erase, or download.
2. `0002-add-isolated-boot-component-flashing.patch` adds the `flash-boot`
   command for explicit `uboot`, `boot0`, and `boot-package` selection. This
   path skips erase, MBR, normal partitions, and Preboot; it rejects selections
   that do not match the target boot mode before a component download.

Both patches include unit and CLI coverage. The second patch is source-tested
and ARMv7-build-tested but still requires an explicitly authorized real-device
validation before it can be considered hardware-verified.
