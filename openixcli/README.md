# OpenixCLI ARMv7 deployment kit

Reproducible build, deployment and safety documentation for the Allwinner
flashing tool used on the ARMv7 auxiliary device. The local patches reject
firmware/target storage mismatches and add isolated `uboot`, `boot0`, and
`boot-package` flashing through the `flash-boot` command.

- [中文说明](README.zh-CN.md)
- [English guide](README.en.md)
- [Upstream tracking and local patch](UPSTREAM.md)

The generated binary is not committed. Build it from the pinned upstream
commit with `make build-armv7`, then install it with `make deploy`.
