# serial-relay

4-channel USB relay controller via RS-232 serial (CH340 chipset, 9600/8N1).

## Hardware

- **Chip**: CH340 USB-to-UART bridge (VID `1a86`, PID `7523`)
- **Driver**: `ch341` (mainline kernel)
- **Device node**: `/dev/ttyUSB1` (or `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`)
- **Relay**: 4-channel optocoupler relay module

## Protocol

Each command is a 4-byte packet: `[0xA0, channel, opcode, checksum]`

| Byte | Range | Description |
|------|-------|-------------|
| 0 | `0xA0` | Fixed header |
| 1 | `0x01`–`0x04` | Channel number (CH1–CH4) |
| 2 | `0x00`–`0x05` | Opcode (see table below) |
| 3 | `0x00`–`0xFF` | Checksum = `(0xA0 + channel + opcode) & 0xFF` |

### Command Table

| Command (hex) | Function | Channel |
|---------------|----------|---------|
| `A0 01 01 A2` | CH1 ON | 1 |
| `A0 01 00 A1` | CH1 OFF | 1 |
| `A0 01 03 A4` | CH1 ON with feedback | 1 |
| `A0 01 02 A3` | CH1 OFF with feedback | 1 |
| `A0 01 04 A5` | CH1 TOGGLE | 1 |
| `A0 01 05 A6` | CH1 STATUS query | 1 |
| `A0 02 01 A3` | CH2 ON | 2 |
| `A0 02 00 A2` | CH2 OFF | 2 |
| `A0 02 03 A5` | CH2 ON with feedback | 2 |
| `A0 02 02 A4` | CH2 OFF with feedback | 2 |
| `A0 02 04 A6` | CH2 TOGGLE | 2 |
| `A0 02 05 A7` | CH2 STATUS query | 2 |
| `A0 03 01 A4` | CH3 ON | 3 |
| `A0 03 00 A3` | CH3 OFF | 3 |
| `A0 03 03 A6` | CH3 ON with feedback | 3 |
| `A0 03 02 A5` | CH3 OFF with feedback | 3 |
| `A0 03 04 A7` | CH3 TOGGLE | 3 |
| `A0 03 05 A8` | CH3 STATUS query | 3 |
| `A0 04 01 A5` | CH4 ON | 4 |
| `A0 04 00 A4` | CH4 OFF | 4 |
| `A0 04 03 A7` | CH4 ON with feedback | 4 |
| `A0 04 02 A6` | CH4 OFF with feedback | 4 |
| `A0 04 04 A8` | CH4 TOGGLE | 4 |
| `A0 04 05 A9` | CH4 STATUS query | 4 |

### Opcode Reference

| Opcode | Action | Description |
|--------|--------|-------------|
| `0x00` | OFF | Open relay contacts |
| `0x01` | ON | Close relay contacts |
| `0x02` | OFF + feedback | OFF with response expected |
| `0x03` | ON + feedback | ON with response expected |
| `0x04` | TOGGLE | Flip current state |
| `0x05` | STATUS | Query current state (returns 1-byte response) |

## Build

### Prerequisites

- Rust toolchain (install via [rustup.rs](https://rustup.rs)):
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```

### Native Build

```bash
# Build release binary
cargo build --release

# Binary location
./target/release/serial --help
```

### ARM64 Cross-Compilation (from x86 host)

```bash
# Install ARM64 target
rustup target add aarch64-unknown-linux-gnu

# Build with Docker-based cross tool
cargo install cross
cross build --release --target aarch64-unknown-linux-gnu
```

### Static Build (musl, no dynamic dependencies)

Produces a fully self-contained binary with no external library dependencies:

```bash
# Install musl target (use a mirror if download is slow, see below)
rustup target add aarch64-unknown-linux-musl

# Build static binary
make static
# or
cargo build --release --target aarch64-unknown-linux-musl

# Verify — should say "not a dynamic executable"
ldd target/aarch64-unknown-linux-musl/release/serial
```

#### Rustup mirror (for slow downloads in mainland China)

```bash
# Set mirror before rustup commands
export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup
export RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup

# Then install targets normally
rustup target add aarch64-unknown-linux-musl
```

### Configuring Baud Rate

Edit `[package.metadata]` in `Cargo.toml`:

```toml
[package.metadata]
baud_rate = 9600     # Change this to match your relay module
```

Then rebuild. The baud rate is embedded at compile time.

## Usage

```bash
# Turn CH1 ON
serial -d /dev/ttyUSB1 -p 0 on

# Turn CH1 OFF
serial -d /dev/ttyUSB1 -p 0 off

# Turn CH2 ON
serial -d /dev/ttyUSB1 -p 1 on

# Turn CH2 OFF
serial -d /dev/ttyUSB1 -p 1 off

# Toggle CH3
serial -d /dev/ttyUSB1 -p 2 toggle

# Query CH4 status
serial -d /dev/ttyUSB1 -p 3 status

# Use persistent device path (avoids /dev/ttyUSB* renumbering)
serial -d /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0 -p 0 on
```

Port mapping: `-p 0` = CH1, `-p 1` = CH2, `-p 2` = CH3, `-p 3` = CH4.

## Debian Package

### On the target ARM64 device

```bash
# Transfer source to target
scp serial-relay-src.tar.gz linaro@192.168.1.189:/tmp/

# SSH into target
ssh linaro@192.168.1.189

cd /tmp
tar xzf serial-relay-src.tar.gz -C serial-relay
cd serial-relay

# Build dynamic .deb
./build-deb.sh deb

# Or build static .deb (no runtime deps)
./build-deb.sh static-deb

# Install (requires root)
sudo dpkg -i serial-relay_0.1.0_arm64.deb
# Or for static version:
sudo dpkg -i serial-relay-static_0.1.0_arm64.deb

# Or install directly from build
./build-deb.sh install
```

### Package commands

```bash
./build-deb.sh deb        # Build dynamic binary and create .deb
./build-deb.sh static     # Build static binary (musl)
./build-deb.sh static-deb # Build static binary and create .deb
./build-deb.sh install    # Build and install to /usr/local/bin
./build-deb.sh uninstall  # Remove installed binary
./build-deb.sh clean      # Remove build artifacts
```

## Debugging

### Check the relay device is recognized

```bash
# List USB serial devices
ls -la /dev/serial/by-id/

# Check device attributes
sudo udevadm info --query=all --name=/dev/ttyUSB1

# Walk the device tree
sudo udevadm info --attribute-walk --name=/dev/ttyUSB1 | grep -E 'DRIVERS|idVendor|idProduct|product'
```

Expected: `DRIVERS=="ch341"`, `ATTRS{idVendor}=="1a86"`, `ATTRS{idProduct}=="7523"`.

### Manual serial test with Python

```bash
# Install pyserial
uv pip install pyserial

# Turn CH1 ON
uv run python3 -c "
import serial
s = serial.Serial('/dev/ttyUSB1', 9600, timeout=0.8)
# CH1 ON: 0xA0 0x01 0x01 0xA2
s.write(bytes([0xA0, 0x01, 0x01, 0xA2]))
s.close()
"
```

### Permission denied on /dev/ttyUSB*

The `linaro` user needs to be in the `dialout` group:

```bash
sudo usermod -a -G dialout linaro
# Log out and back in, or use:
newgrp dialout
```

### Silent / no relay click

- Verify the relay module has external 5V power (USB data cable alone may not supply enough current)
- Check the command bytes with `serial` tool: it prints the hex packet on stderr
- Test with the Python snippet above to rule out the Rust binary

## Project Structure

```
serial-relay/
├── Cargo.toml            # Package config + baud rate setting
├── Cargo.lock            # Locked dependency versions
├── build.rs              # Reads baud_rate from Cargo.toml at compile time
├── src/
│   └── main.rs           # CLI and serial control logic
├── .cargo/
│   └── config.toml       # Target-specific rustflags / linker config
├── debian/               # Debian packaging (dpkg-buildpackage)
│   ├── control
│   ├── rules
│   ├── changelog
│   ├── compat
│   └── install
├── build-deb.sh           # Standalone build+deb script (no debhelper needed)
├── Makefile               # Alternative build targets (make/make static/make deb)
└── README.md
```

## License

MIT
