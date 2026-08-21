# serial-relay

[简体中文](README.zh-CN.md) | [Bilingual overview](README.md)

`serial-relay` is a command-line tool for controlling a four-channel relay
board through a CH340 USB-to-serial adapter. Each invocation performs one
operation and exits. It is not a daemon and does not require an autostart
service.

The project has been tested with the following environment:

- Device: MYD-YR3506
- Operating system: Debian 12
- CPU architecture: ARMv7 hard-float (Debian architecture `armhf`)
- Serial device: `/dev/ttyUSB0`
- USB adapter: CH340, VID:PID `1a86:7523`
- Serial settings: 9600 baud, 8N1
- Verified operations: ON, OFF, status query, and state restoration on CH1–CH4

## Quick start: x86_64 host to MYD-YR3506

If you only need to build and deploy the program to the tested MYD-YR3506,
run the commands in this section.

On an x86_64 Ubuntu/Debian host:

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

scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay
```

Log in and install the binary:

```bash
ssh myir@192.168.1.49
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

Query all four channels on the device:

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done
```

If any step fails, see the relevant section and [Troubleshooting](#troubleshooting).

## 1. Commands and channel mapping

The tool supports four primary operations:

| Operation | Argument | Description |
|---|---|---|
| Turn on | `on` | Energize the relay |
| Turn off | `off` | Release the relay |
| Toggle | `toggle` | Change ON to OFF or OFF to ON |
| Query | `status` | Query and validate the response from the relay |

Channel arguments are zero-based:

| Physical channel | `--port` value | Short form |
|---|---:|---|
| CH1 | `0` | `-p 0` |
| CH2 | `1` | `-p 1` |
| CH3 | `2` | `-p 2` |
| CH4 | `3` | `-p 3` |

The default serial device is `/dev/ttyUSB0`, so `-d` is normally unnecessary:

```bash
serial-relay -p 0 status
```

Complete command syntax:

```text
serial-relay [--device <serial-device>] --port <0..3> <on|off|toggle|status>
```

Display built-in help and version information:

```bash
serial-relay --help
serial-relay --version
```

## 2. Get the source

On Ubuntu, Debian, or the target device:

```bash
git clone https://github.com/luckzhang888/Tools.git
cd Tools/serial-relay
```

If the repository is already cloned:

```bash
cd Tools
git pull --ff-only
cd serial-relay
```

Run all following build commands from the `Tools/serial-relay` directory.

## 3. Install the Rust toolchain

The minimum supported Rust version is 1.85. The current stable toolchain from
rustup is recommended.

Install the basic host tools:

```bash
sudo apt-get update
sudo apt-get install -y curl build-essential file binutils
```

Install Rust:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

Check the installed versions:

```bash
rustc --version
cargo --version
```

If `rustc` is older than 1.85:

```bash
rustup update stable
rustup default stable
```

## 4. Build

Check the build host architecture first:

```bash
uname -m
```

| `uname -m` | Architecture | Debian package architecture |
|---|---|---|
| `x86_64` | 64-bit x86 PC/server | `amd64` |
| `aarch64` | 64-bit ARM | `arm64` |
| `armv7l` | 32-bit ARMv7 hard-float | `armhf` |

### 4.1 Native build on the target device

Use this method when Rust and GCC are already installed on the target. From the
source directory, run:

```bash
cargo build --release --locked
```

The Makefile provides the equivalent shortcut:

```bash
make build
```

The output is:

```text
target/release/serial-relay
```

Check the binary architecture and version:

```bash
file target/release/serial-relay
target/release/serial-relay --version
```

Query CH1 directly from the build directory:

```bash
./target/release/serial-relay -p 0 status
```

### 4.2 Cross-compile ARMv7 on an x86_64 Ubuntu/Debian host

The tested MYD-YR3506 reports `armv7l`. It requires the
`armv7-unknown-linux-gnueabihf` Rust target; an ARM64 binary will not run on it.

Install the ARMv7 cross compiler:

```bash
sudo apt-get update
sudo apt-get install -y gcc-arm-linux-gnueabihf \
  binutils-arm-linux-gnueabihf file
```

Install the Rust standard library for ARMv7:

```bash
rustup target add armv7-unknown-linux-gnueabihf
```

Build the program:

```bash
TARGET=armv7-unknown-linux-gnueabihf make build
```

Equivalent Cargo command:

```bash
cargo build --release --locked --target armv7-unknown-linux-gnueabihf
```

The output is:

```text
target/armv7-unknown-linux-gnueabihf/release/serial-relay
```

Confirm that it is a 32-bit ARM binary:

```bash
file target/armv7-unknown-linux-gnueabihf/release/serial-relay
```

The output should contain text similar to:

```text
ELF 32-bit LSB ... ARM, EABI5 ... interpreter /lib/ld-linux-armhf.so.3
```

### 4.3 Cross-compile ARM64 on an x86_64 Ubuntu/Debian host

Use this procedure for an ARM64 target. Do not deploy this output to an
`armv7l` device.

```bash
sudo apt-get update
sudo apt-get install -y gcc-aarch64-linux-gnu \
  binutils-aarch64-linux-gnu file
rustup target add aarch64-unknown-linux-gnu
TARGET=aarch64-unknown-linux-gnu make build
```

The output is:

```text
target/aarch64-unknown-linux-gnu/release/serial-relay
```

### 4.4 Run code checks and unit tests

These checks do not access or switch the relay hardware:

```bash
make check
```

This target runs:

```bash
cargo fmt -- --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

The current five unit tests cover the default device, action codes,
four-channel packets, status parsing, and invalid responses.

## 5. Build Debian packages

### 5.1 Package for the current host architecture

```bash
./build-deb.sh deb
```

For example, an x86_64 host produces:

```text
dist/serial-relay_0.1.0_amd64.deb
```

### 5.2 Build an ARMv7/armhf package on an x86_64 host

Install the cross toolchain described in section 4.2, then run:

```bash
TARGET=armv7-unknown-linux-gnueabihf \
PKG_ARCH=armhf \
./build-deb.sh deb
```

The output is:

```text
dist/serial-relay_0.1.0_armhf.deb
```

Inspect its metadata and contents:

```bash
dpkg-deb --info dist/serial-relay_0.1.0_armhf.deb
dpkg-deb --contents dist/serial-relay_0.1.0_armhf.deb
```

### 5.3 Build an ARM64 package on an x86_64 host

```bash
TARGET=aarch64-unknown-linux-gnu \
PKG_ARCH=arm64 \
./build-deb.sh deb
```

The output is:

```text
dist/serial-relay_0.1.0_arm64.deb
```

Display all actions supported by the build script:

```bash
./build-deb.sh --help
```

## 6. Deploy to MYD-YR3506

The examples below use device address `192.168.1.49` and user `myir`.

### 6.1 Deploy the ARMv7 binary

On the cross-compilation host:

```bash
scp target/armv7-unknown-linux-gnueabihf/release/serial-relay \
  myir@192.168.1.49:/tmp/serial-relay
```

Log in:

```bash
ssh myir@192.168.1.49
```

On the device, inspect and install the binary:

```bash
uname -m
file /tmp/serial-relay
chmod +x /tmp/serial-relay
/tmp/serial-relay --version
sudo install -m 0755 /tmp/serial-relay /usr/local/bin/serial-relay
rm /tmp/serial-relay
```

Verify the installation:

```bash
command -v serial-relay
serial-relay --version
```

The expected installation path is:

```text
/usr/local/bin/serial-relay
```

### 6.2 Install the armhf Debian package

Upload the package from the build host:

```bash
scp dist/serial-relay_0.1.0_armhf.deb myir@192.168.1.49:/tmp/
```

Install it on the device:

```bash
ssh myir@192.168.1.49
sudo dpkg -i /tmp/serial-relay_0.1.0_armhf.deb
rm /tmp/serial-relay_0.1.0_armhf.deb
```

Verify the package and command:

```bash
dpkg -s serial-relay
serial-relay --version
```

### 6.3 Uninstall

For a manually copied binary:

```bash
sudo rm /usr/local/bin/serial-relay
```

For a Debian package installation:

```bash
sudo dpkg -r serial-relay
```

## 7. Verify the serial device

After connecting the CH340 adapter, check the USB device:

```bash
lsusb | grep -i '1a86:7523'
```

Check the serial device and persistent device links:

```bash
ls -l /dev/ttyUSB* 2>/dev/null
ls -l /dev/serial/by-id/ 2>/dev/null
```

The tested device reported:

```text
/dev/ttyUSB0
/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 -> ../../ttyUSB0
```

Resolve the persistent path:

```bash
readlink -f /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0
```

The `/dev/ttyUSB0` number can change after reconnecting the adapter or when
multiple USB serial adapters are present. Prefer `/dev/serial/by-id/...` in
long-lived scripts.

## 8. Configure serial-port permissions

Inspect the device permissions and current groups:

```bash
ls -l /dev/ttyUSB0
id
```

The device usually belongs to `root:dialout`. If the current user is not in
the `dialout` group, run:

```bash
sudo usermod -aG dialout "$USER"
```

Then close the SSH session and log in again:

```bash
exit
ssh myir@192.168.1.49
```

Verify access:

```bash
id
test -r /dev/ttyUSB0 && echo readable=yes
test -w /dev/ttyUSB0 && echo writable=yes
```

## 9. Usage

### 9.1 Query all four channels

```bash
serial-relay -p 0 status
serial-relay -p 1 status
serial-relay -p 2 status
serial-relay -p 3 status
```

Or use a loop:

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" status
done
```

Example response when CH1 is OFF:

```text
Device: /dev/ttyUSB0, CH1, Action: STATUS
Sent: A0 01 05 A6 (checksum=0xA6)
CH1 status: OFF (response: A0 01 00 A1)
```

Example response when CH1 is ON:

```text
CH1 status: ON (response: A0 01 01 A2)
```

### 9.2 Control CH1

```bash
# Energize CH1
serial-relay -p 0 on

# Confirm that CH1 reports ON
serial-relay -p 0 status

# Release CH1
serial-relay -p 0 off

# Confirm that CH1 reports OFF
serial-relay -p 0 status
```

### 9.3 Control CH2 through CH4

```bash
# CH2
serial-relay -p 1 on
serial-relay -p 1 status
serial-relay -p 1 off

# CH3
serial-relay -p 2 on
serial-relay -p 2 status
serial-relay -p 2 off

# CH4
serial-relay -p 3 on
serial-relay -p 3 status
serial-relay -p 3 off
```

### 9.4 Toggle a channel

```bash
serial-relay -p 2 toggle
serial-relay -p 2 status
```

### 9.5 Select another serial device

Short option:

```bash
serial-relay -d /dev/ttyUSB1 -p 0 status
```

Long option:

```bash
serial-relay --device /dev/ttyUSB1 --port 0 status
```

Persistent device path:

```bash
serial-relay \
  --device /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 \
  --port 0 status
```

### 9.6 Operate all channels

The commands below change all four relay states. Confirm that every connected
load can be switched safely before running them.

Turn all channels on:

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" on
done
```

Turn all channels off:

```bash
for port in 0 1 2 3; do
  serial-relay -p "$port" off
done
```

Run `status` after ON or OFF to confirm the state reported by the relay module.

Compatibility aliases are available: `open` is equivalent to `on`, and
`close` is equivalent to `off`. Prefer `on` and `off` in scripts for clarity.

## 10. Hardware test script

The test script is located at:

```text
scripts/test-device.sh
```

### 10.1 Read-only status check

This command queries all four channels without changing their states:

```bash
./scripts/test-device.sh --device /dev/ttyUSB0
```

If `serial-relay` is not in `PATH`, provide the binary path:

```bash
./scripts/test-device.sh \
  --binary ./target/release/serial-relay \
  --device /dev/ttyUSB0
```

### 10.2 Complete ON/OFF exercise

```bash
./scripts/test-device.sh --exercise --device /dev/ttyUSB0
```

The exercise performs the following sequence:

```text
Record the initial CH1–CH4 states
  -> turn each channel ON
  -> query and verify ON
  -> turn each channel OFF
  -> query and verify OFF
  -> restore every pre-test state
  -> query and verify successful restoration
```

`--exercise` physically energizes and releases the relays. Confirm that the
connected equipment, loads, and mechanisms can move safely before using it.

## 11. Exit status and error handling

A successful command exits with status 0:

```bash
serial-relay -p 0 status
echo "$?"
```

The command exits with a nonzero status when it encounters problems such as:

- failure to open the serial device;
- insufficient read or write permission;
- serial write or read failure;
- status query timeout;
- invalid response length;
- invalid response header, channel, state, or checksum.

Use the exit status in a shell script:

```bash
if serial-relay -p 0 status; then
  echo "CH1 query succeeded"
else
  echo "CH1 query failed" >&2
fi
```

## 12. Troubleshooting

### 12.1 `No such file or directory` or missing `/dev/ttyUSB0`

Check whether the adapter was enumerated:

```bash
lsusb
ls -l /dev/ttyUSB*
dmesg | tail -50
```

If the device is `/dev/ttyUSB1`, select it explicitly:

```bash
serial-relay -d /dev/ttyUSB1 -p 0 status
```

### 12.2 `Permission denied`

```bash
ls -l /dev/ttyUSB0
id
sudo usermod -aG dialout "$USER"
```

Log out and back in after changing group membership. The current SSH session
does not automatically receive the new group.

### 12.3 `Exec format error`

The deployed binary was built for the wrong architecture. Inspect the device
and binary:

```bash
uname -m
file /usr/local/bin/serial-relay
```

- An `armv7l` device needs an `armv7-unknown-linux-gnueabihf`/`armhf` build.
- An `aarch64` device needs an `aarch64-unknown-linux-gnu`/`arm64` build.

### 12.4 `query timed out (no response)`

Check the following in order:

1. The correct USB serial device is selected.
2. The user has read and write access to the serial device.
3. The relay board is powered correctly.
4. TX, RX, and GND are wired correctly and share a reliable ground.
5. The relay protocol actually uses 9600 baud and 8N1.
6. No other process has opened the same serial device.

Check which process is using the port:

```bash
sudo fuser -v /dev/ttyUSB0
```

### 12.5 ON/OFF succeeds, but the physical state is uncertain

Query the state after sending the command:

```bash
serial-relay -p 0 on
serial-relay -p 0 status
```

Only a response containing `status: ON` confirms that the module reported ON.

### 12.6 Change the baud rate

The baud rate is read from `Cargo.toml` at build time:

```toml
[package.metadata]
baud_rate = 9600
```

Rebuild and redeploy after changing it:

```bash
cargo clean
cargo build --release --locked
```

## 13. Serial protocol

Command frames and four-byte status responses use this format:

```text
[0xA0, channel, opcode/state, checksum]
checksum = (0xA0 + channel + opcode/state) & 0xFF
```

| Byte/value | Meaning |
|---|---|
| `0xA0` | Fixed frame header |
| `0x01`–`0x04` | CH1–CH4 |
| `0x00` | OFF |
| `0x01` | ON |
| `0x04` | TOGGLE |
| `0x05` | STATUS query |

Common command frames:

| Operation | Bytes |
|---|---|
| CH1 ON | `A0 01 01 A2` |
| CH1 OFF | `A0 01 00 A1` |
| CH1 STATUS | `A0 01 05 A6` |
| CH2 ON | `A0 02 01 A3` |
| CH2 OFF | `A0 02 00 A2` |
| CH3 ON | `A0 03 01 A4` |
| CH3 OFF | `A0 03 00 A3` |
| CH4 ON | `A0 04 01 A5` |
| CH4 OFF | `A0 04 00 A4` |
| CH4 STATUS | `A0 04 05 A9` |

## 14. GitHub Actions builds

The repository workflow `.github/workflows/serial-relay.yml` runs when:

- changes under `serial-relay/` are pushed to `main`;
- a pull request targeting `main` is created or updated;
- the workflow file itself changes.

CI runs unit tests and builds the following artifacts:

- amd64 binary and Debian package;
- arm64 binary and Debian package;
- armhf/ARMv7 binary and Debian package.

Pushing a `serial-relay-v*` tag also creates a GitHub Release:

```bash
git tag serial-relay-v0.1.0
git push origin serial-relay-v0.1.0
```

## 15. Project layout

```text
serial-relay/
├── Cargo.toml                 # Rust package metadata and baud rate
├── Cargo.lock                 # Locked dependency versions
├── build.rs                   # Passes the baud rate to the program
├── src/main.rs                # CLI, protocol implementation, and unit tests
├── .cargo/config.toml         # ARM cross-linker configuration
├── Makefile                   # build/check/test/deb/install entry points
├── build-deb.sh               # Multi-architecture build and Debian packaging
├── scripts/package-deb.sh     # Create a .deb from a compiled binary
├── scripts/test-device.sh     # Four-channel test and state restoration
├── debian/                    # Standard Debian packaging metadata
├── README.md                  # Bilingual overview and quick start
├── README.zh-CN.md            # Complete Simplified Chinese guide
└── README.en.md               # Complete English guide
```

## License

MIT
