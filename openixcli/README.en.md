# OpenixCLI for Allwinner flashing (ARMv7)

This directory pins [OpenixCLI](https://github.com/YuzukiTsuru/OpenixCLI) to a verified upstream commit and provides reproducible ARMv7 cross-compilation, deployment, and read-only validation. It does not modify an Allwinner SDK.

## What is included

- OpenixCLI `0.2.2` and a complete Cargo dependency lock file.
- A Docker build for `armv7-unknown-linux-gnueabihf`.
- Vendored libusb linkage, so robot does not need a dynamic `libusb-1.0.so`.
- A safety patch that compares `storage_type` from the firmware's embedded `sys_config.fex` with the storage reported by target FES and aborts before erase or download on a mismatch.
- Unmodified upstream source as a submodule on the `upstream` branch; this deployment kit and patch on `main`.

See [UPSTREAM.md](UPSTREAM.md) for provenance and patch details.

## Build

The host needs Git, Docker, `file`, and `readelf`. Proxy environment variables are forwarded to Docker automatically.

```bash
cd openixcli
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
make check
make build-armv7
```

Artifacts:

```text
dist/openixcli-armv7
dist/openixcli-armv7.sha256
```

The build runs all upstream tests, verifies the pinned commit, applies the safety patch, and confirms the artifact is a 32-bit ARM ELF without a dynamic libusb dependency.

## Deploy to robot

The script does not store a password. SSH and sudo prompt normally when authentication is required.

```bash
make deploy
```

To select a host explicitly:

```bash
DEVICE_HOST=192.168.1.50 DEVICE_USER=myir make deploy
```

The fixed installation path is `/usr/local/bin/openixcli`. Deployment verifies the upload checksum, architecture, version, and installed checksum.

## Read-only test

```bash
make test-device
```

This checks version, ELF metadata, checksums, firmware parsing, and a USB scan. It does not write target storage. Zero flashing devices is expected while the target is not in FEL/FES mode.

## Enter Allwinner flashing mode

First confirm the target console and relay mapping against the private lab guide. Reboot the target and repeatedly send `2` during U-Boot startup, or run `efex` at the U-Boot prompt. Then scan from robot:

```bash
sudo openixcli --backend libusb scan --detailed
```

Exactly one expected Allwinner target must be present. Inspect and hash the image before flashing:

```bash
openixcli inspect /myir/image/T113i/myir_image_yt113i.img
sha256sum /myir/image/T113i/myir_image_yt113i.img
```

## Flash

> `full_erase` destroys all data on target storage. Confirm the target, image, SHA256, storage type, and the USB bus/port returned by the current scan, and obtain explicit authorization. Do not copy the placeholders literally.

```bash
sudo openixcli --backend libusb flash \
  /myir/image/T113i/myir_image_yt113i.img \
  --bus <SCAN_BUS> \
  --port <SCAN_PORT> \
  --verify true \
  --mode full_erase \
  --post-action reboot
```

A successful exit is only one gate: partition and Boot0/Boot1 verification must pass, the target must reboot, and the new system must be confirmed through its console or a system login.

## Updating upstream

When changing the pinned commit, regenerate and commit `Cargo.lock`, re-review the safety patch, run the full test and ARMv7 build, perform the robot read-only checks and one explicitly authorized real-flash validation, then update `UPSTREAM.md` and the `upstream` submodule.
