# upgrade_tool ARMv7 build, deployment, and usage guide

[简体中文](README.zh-CN.md) | [Bilingual quick start](README.md)

## 1. Purpose

`upgrade_tool` is a Rockchip USB flashing command-line tool. It runs on a
Linux controller and accesses another Rockchip target in Maskrom, Loader, or
MSC mode over USB.

The deployment model documented here is:

```text
x86_64 build host
    | cross-compile a static ARMv7 executable
    v
MYD-YR3506 controller running upgrade_tool
    | USB host data connection
    v
Rockchip target in Maskrom or Loader mode
```

Installing the tool on MYD-YR3506 does not automatically modify its system or
SDK. Target storage changes only after a different Rockchip device is
connected and a write command such as `UF`, `UL`, `DI`, or `EF` is run.

## 2. Verified environment

This workflow has been tested with:

- Controller: MYD-YR3506
- Controller OS: Debian 12
- Controller architecture: `armv7l`, ARM hard-float
- Controller address: `192.168.1.49`
- Login user: `myir`
- Installation path: `/usr/local/bin/upgrade_tool`
- Upstream: `https://github.com/bitshelf/upgrade_tool.git`
- Pinned commit: `ea51edd64f72b338c1d6adb9c21693712f38bd83`
- Internal application version: `v2.44`
- Artifact: fully static 32-bit ARM EABI5 executable
- Tested SHA256:
  `92a563ab2cb4832fb9cd989c6a2634b50c7edb669ae7006883d0982689cc0d1f`

The following checks passed on the controller:

- ARMv7 executable startup;
- no-argument help output;
- read-only `sudo upgrade_tool LD` USB enumeration;
- static-link verification and matching upload/install SHA256 hashes.

No Rockchip target was connected during verification, so enumeration returned:

```text
List of rockusb connected(0)
```

This means that scanning completed successfully but no Maskrom/Loader target
was present. It is not a build failure.

## 3. Upstream source and licensing

The Tools repository does not copy upstream source files or binaries. The
build helper fetches and verifies:

| Component | Pinned commit |
|---|---|
| `bitshelf/upgrade_tool` | `ea51edd64f72b338c1d6adb9c21693712f38bd83` |
| `illiliti/libudev-zero` 1.0.3 | `ee32ac5f6494047b9ece26e7a5920650cdf46655` |

At the pinned `upgrade_tool` commit, `main.cpp` contains a GPL-3.0-or-later
notice, but the repository has no top-level `LICENSE` or `COPYING` file.
Confirm the complete upstream licensing status before redistributing its
source or binary. See [UPSTREAM.md](UPSTREAM.md).

## 4. Get the Tools repository

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/upgrade-tool
```

For an existing checkout:

```bash
cd Tools
git pull --ff-only
cd upgrade-tool
```

Run the remaining commands from `Tools/upgrade-tool`.

## 5. Build-host requirements

An x86_64 Ubuntu or Debian host is recommended. It needs:

- Git;
- Docker;
- `file`;
- network access to GitHub and Debian repositories.

Example installation on Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io file make
sudo usermod -aG docker "$USER"
```

Log out and back in after changing Docker group membership. You may instead
use `sudo docker` according to local policy, but the helper invokes `docker`
directly by default.

Verify the environment:

```bash
git --version
docker version
file --version
make --version
```

## 6. Network proxy

Set the proxy only when the current network requires it. Each export must be
on its own line:

```bash
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
```

Some tools read uppercase variables as well:

```bash
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
```

The helper forwards lowercase and uppercase proxy variables to `docker build`
and the build container. It does not embed the proxy in the final executable.

## 7. Cross-compile ARMv7

Check the scripts and required files:

```bash
make check
```

Build:

```bash
make build-armv7
```

The script:

1. fetches the pinned `bitshelf/upgrade_tool` commit;
2. fetches the pinned `libudev-zero` 1.0.3 commit;
3. builds a Debian 12 ARMhf cross-compilation container;
4. compiles with `arm-linux-gnueabihf-g++` and ARMhf `libusb`;
5. verifies a fully static 32-bit ARM output;
6. writes the binary and a SHA256 checksum file.

Artifacts:

```text
dist/upgrade_tool-armhf-static
dist/upgrade_tool-armhf-static.sha256
```

Verify them:

```bash
file dist/upgrade_tool-armhf-static
(cd dist && sha256sum --check upgrade_tool-armhf-static.sha256)
```

The `file` output must contain text similar to:

```text
ELF 32-bit ... ARM, EABI5 ... statically linked
```

The first build downloads the Debian container and cross dependencies. Later
builds reuse Docker layers.

### 7.1 Custom build and artifact directories

The default cache is `build/armv7`. Put it on another disk with:

```bash
BUILD_ROOT=/data/build/upgrade-tool-armv7 make build-armv7
```

Select another artifact directory with:

```bash
DIST_DIR=/data/artifacts ./scripts/build-armv7.sh
```

`build/` and `dist/` are ignored by Git, preventing accidental commits of
upstream checkouts and binaries.

## 8. Deploy to MYD-YR3506

Defaults:

```text
DEVICE_USER=myir
DEVICE_HOST=192.168.1.49
INSTALL_PATH=/usr/local/bin/upgrade_tool
```

Run:

```bash
make deploy
```

The deploy helper:

1. refuses a non-ARMv7 input;
2. uploads it to `/tmp/upgrade_tool.new`;
3. compares local and remote SHA256 hashes;
4. starts the temporary binary and checks its help output;
5. installs it with `sudo install`;
6. displays the installed architecture and SHA256 hash.

It prompts for SSH and `sudo` passwords but never stores them.

Select another device:

```bash
DEVICE_USER=myir \
DEVICE_HOST=192.168.1.49 \
make deploy
```

Select another binary:

```bash
BINARY=/data/artifacts/upgrade_tool-armhf-static \
./scripts/deploy.sh
```

### 8.1 Changed SSH host key

If SSH reports:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

Do not simply disable host-key checking. Verify the device fingerprint through
a serial console, physical device information, or a trusted administrator.
Update `known_hosts` only after confirming that the OS or host keys really
changed.

A separately verified host-key file can be used for one deployment:

```bash
ssh-keyscan -T 5 192.168.1.49 > /tmp/upgrade-tool-known-hosts
ssh-keygen -lf /tmp/upgrade-tool-known-hosts

KNOWN_HOSTS_FILE=/tmp/upgrade-tool-known-hosts make deploy
KNOWN_HOSTS_FILE=/tmp/upgrade-tool-known-hosts make test-device
```

Compare the displayed fingerprint through a trusted channel before entering
the device password.

## 9. Safe device-side verification

Run the repository's read-only check:

```bash
make test-device
```

It only:

- verifies `/usr/local/bin/upgrade_tool` exists and is executable;
- displays its ELF architecture;
- reads the no-argument help page;
- runs `sudo upgrade_tool LD` to enumerate Rockchip USB devices;
- displays `lsusb`.

It never downloads an image or writes/erases flash.

Manual equivalent:

```bash
ssh myir@192.168.1.49
file /usr/local/bin/upgrade_tool
sha256sum /usr/local/bin/upgrade_tool
upgrade_tool
sudo upgrade_tool LD
lsusb
```

## 10. Connect a Rockchip target

1. Use a USB Host port on MYD-YR3506.
2. Connect the target with a data-capable USB cable.
3. Put the target into Loader or Maskrom mode.
4. Check for Rockchip's USB vendor ID:

```bash
lsusb | grep -i 2207
```

5. Enumerate with the tool:

```bash
sudo upgrade_tool LD
```

With a target connected, output resembles:

```text
DevNo=1  Vid=0x2207,Pid=0x....  LocationID=...  Mode=Loader
```

The PID and mode depend on the Rockchip SoC, loader, and boot state.

Using `sudo` is recommended because flashing requires direct access to
`/dev/bus/usb`. This project does not install a permissive udev rule, reducing
the chance of granting unprivileged write access to every Rockchip USB device.

## 11. Commands and risk levels

Run without arguments to display built-in help:

```bash
upgrade_tool
```

### 11.1 Read-only or low-risk operations

| Command | Purpose | Notes |
|---|---|---|
| `LD` | List Rockchip USB devices | Does not write storage |
| `PL` | Read the partition list | Requires a connected target |
| `RSN` | Read the serial number | Requires a connected target |
| `RID` | Read the flash ID | Requires a connected target |
| `RFI` | Read flash information | Requires a connected target |
| `RCI` | Read chip information | Requires a connected target |
| `CPU` | Read CPUID | Output may contain a unique identifier |
| `RSM` | Read secure mode | Does not change secure state |
| `SFI <Firmware>` | Show firmware metadata | Reads a local file |
| `EXF <Firmware> <Dir>` | Extract firmware | Writes a local directory, not target flash |

`V` is the version command, but the upstream program may scan USB first. With
no target or insufficient USB permission, it can print
`No found any rockusb device` and return 255. Use the no-argument help page to
verify basic startup.

### 11.2 High-risk operations that modify the target

| Command | Effect |
|---|---|
| `UF <Firmware>` | Flash a complete Rockchip firmware image |
| `UL <Loader>` | Upgrade the loader |
| `DI ...` | Download partition images |
| `DB <Loader>` | Download a boot loader to a Maskrom device |
| `EF <Loader|Firmware>` | Erase flash |
| `SN <serial>` | Write a serial number |
| `GPT ...` | Create GPT data |
| `WL ...` | Write LBA sectors |
| `EL ...` | Erase an LBA range |
| `EB ...` | Erase blocks |
| `RD` | Reset the target |

Before any high-risk command, confirm:

- the image matches the exact SoC and board;
- the loader matches DDR, storage, and power configuration;
- the intended USB target is selected;
- serial numbers, calibration data, the partition table, and required
  partitions are backed up;
- power and USB connections are stable;
- a Maskrom recovery procedure is available.

## 12. Typical flashing relationships

These examples explain command relationships. They do not make an arbitrary
image safe for a particular board.

Flash a complete `update.img` in Loader mode:

```bash
sudo upgrade_tool LD
sudo upgrade_tool UF /path/to/update.img
```

Maskrom mode commonly requires downloading a matching loader into RAM first:

```bash
sudo upgrade_tool LD
sudo upgrade_tool DB /path/to/MiniLoaderAll.bin
sudo upgrade_tool LD
sudo upgrade_tool UF /path/to/update.img
```

Do not copy and run these commands until loader and image compatibility are
confirmed.

## 13. Troubleshooting

### 13.1 `List of rockusb connected(0)`

The tool works, but no target was found. Check:

```bash
lsusb
lsusb | grep -i 2207
sudo upgrade_tool LD
```

Then inspect the USB Host port, cable, target power, and the procedure used to
enter Loader or Maskrom mode.

### 13.2 `No found any rockusb device, please plug device in`

Some commands require a Rockchip device before performing their own function.
Run:

```bash
sudo upgrade_tool LD
```

If it still lists zero devices, diagnose USB connectivity or boot mode before
changing firmware command arguments.

### 13.3 `Permission denied` or `LIBUSB_ERROR_ACCESS`

Use:

```bash
sudo upgrade_tool LD
```

If non-root access is required, create a udev rule restricted to VID `2207`
according to organizational security policy. Do not set every USB device to
mode `0666`.

### 13.4 `Exec format error`

```bash
uname -m
file /usr/local/bin/upgrade_tool
```

This artifact is for `armv7l`/`armhf`. An `aarch64` or `x86_64` binary will not
run on the tested ARMv7 controller.

### 13.5 GitHub or Debian repositories are unreachable during build

Set the proxy on separate lines:

```bash
export http_proxy=http://192.168.1.111:7999
export https_proxy=http://192.168.1.111:7999
make build-armv7
```

Do not concatenate the two `export` commands without whitespace or a newline.

### 13.6 The build checkout has local changes

For reproducibility, the helper refuses tracked changes under `build/armv7`.
Save those changes or use a fresh build directory:

```bash
BUILD_ROOT=/tmp/upgrade-tool-clean-build make build-armv7
```

## 14. Uninstall

```bash
ssh myir@192.168.1.49
sudo rm /usr/local/bin/upgrade_tool
```

The application may create `upgrade_tool/log/` in the user's directory. Review
those logs separately before deleting user data; the uninstall command does
not remove them automatically.

## 15. Project layout

```text
upgrade-tool/
├── Dockerfile.armv7          # Debian 12 ARMhf cross-build environment
├── Makefile                  # check/build/deploy/test entry points
├── cmake/
│   └── toolchain-armv7.cmake # ARMv7 CMake toolchain
├── scripts/
│   ├── build-armv7.sh        # Pin upstream commits and build statically
│   ├── deploy.sh             # Deploy after SHA256 verification
│   └── test-device.sh        # Read-only remote validation
├── UPSTREAM.md               # Provenance and licensing caveat
├── README.md                 # Bilingual quick start
├── README.zh-CN.md           # Complete Chinese guide
└── README.en.md              # Complete English guide
```
