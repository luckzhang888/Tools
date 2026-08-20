#!/usr/bin/env bash
# scripts/package-deb.sh — Build a .deb package from a static binary.
#
# Usage:  ./scripts/package-deb.sh <binary> <arch> [output-dir]
#
# Creates a .deb in the specified output directory (default: dist/).
# Uses ar + tar — no dpkg-deb required, works on any Linux.
#
# Examples:
#   ./scripts/package-deb.sh target/x86_64-unknown-linux-musl/release/serial_relay amd64
#   ./scripts/package-deb.sh target/aarch64-unknown-linux-musl/release/serial_relay arm64 dist/

set -euo pipefail

BIN="${1:?Usage: $0 <binary> <arch> [output-dir]}"
ARCH="${2:?Usage: $0 <binary> <arch> [output-dir]}"
OUT_DIR="${3:-dist}"

# ── Extract metadata from Cargo.toml ──
PKG_NAME="serial-relay-static"
VER=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
BAUD=$(grep baud_rate Cargo.toml | head -1 | grep -oP '\d+')

if [ ! -f "${BIN}" ]; then
  echo "ERROR: binary not found: ${BIN}" >&2
  exit 1
fi

DEB_NAME="${PKG_NAME}_${VER}_${ARCH}"
DEB_ROOT="deb-pkg/${DEB_NAME}"

echo "Packaging ${DEB_NAME}.deb ..."
rm -rf "deb-pkg"
mkdir -p "${DEB_ROOT}/DEBIAN" \
         "${DEB_ROOT}/usr/bin" \
         "${DEB_ROOT}/usr/share/doc/${PKG_NAME}"

install -m 755 "${BIN}" "${DEB_ROOT}/usr/bin/serial_relay"

# ── DEBIAN/control ──
python3 -c "
control = '''Package: ${PKG_NAME}
Version: ${VER}
Architecture: ${ARCH}
Maintainer: linaro <linaro@localhost>
Section: electronics
Priority: optional
Conflicts: serial-relay
Replaces: serial-relay
Description: 4-channel USB relay controller — static build (CH340)
 Control a 4-channel USB relay module over RS-232 serial via CH340.
 Supports on/off/toggle/status operations for each channel.
 Fully static binary — no external library dependencies.
 Baud rate: ${BAUD}
'''
with open('${DEB_ROOT}/DEBIAN/control', 'w') as f:
    f.write(control)
"

# ── copyright ──
cat > "${DEB_ROOT}/usr/share/doc/${PKG_NAME}/copyright" <<'COPY'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
License: MIT
COPY

# ── Build .deb with ar + tar (POSIX, no dpkg-deb needed) ──
# Archives are created in the parent dir to avoid tar self-referencing
# (tar refuses to archive its own output file).
cd "${DEB_ROOT}"
echo "2.0" > debian-binary
tar czf ../data.tar.gz --exclude=DEBIAN --exclude=debian-binary .
tar czf ../control.tar.gz -C DEBIAN .
cp debian-binary ..
cd ..
ar rcs "../${OUT_DIR}/${DEB_NAME}.deb" debian-binary control.tar.gz data.tar.gz
cd - >/dev/null

rm -rf "deb-pkg"
echo "  -> ${OUT_DIR}/${DEB_NAME}.deb"
