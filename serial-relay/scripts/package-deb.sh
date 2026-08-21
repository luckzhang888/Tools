#!/usr/bin/env bash
# Create a Debian package from an already-built serial-relay binary.
#
# Usage: ./scripts/package-deb.sh <binary> <arch> [output-dir]

set -euo pipefail

BIN=${1:?Usage: $0 <binary> <arch> [output-dir]}
ARCH=${2:?Usage: $0 <binary> <arch> [output-dir]}
OUT_DIR=${3:-dist}
PACKAGE_DEPENDS=${PACKAGE_DEPENDS-'libc6, libgcc-s1'}

[[ -f "${BIN}" ]] || {
    echo "ERROR: binary not found: ${BIN}" >&2
    exit 1
}

case "${ARCH}" in
    amd64 | arm64 | armhf) ;;
    *)
        echo "ERROR: unsupported Debian architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

VER=$(sed -n 's/^version = "\([^"]*\)"/\1/p' Cargo.toml | head -1)
BAUD=$(sed -n 's/^baud_rate = \([0-9][0-9]*\).*/\1/p' Cargo.toml | head -1)
[[ -n "${VER}" && -n "${BAUD}" ]] || {
    echo "ERROR: cannot read version or baud rate from Cargo.toml" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required tool not found: $1" >&2
        exit 1
    }
}

require_tool ar
require_tool tar

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/serial-relay-deb.XXXXXX")
trap 'rm -rf -- "${STAGE}"' EXIT

CONTROL_ROOT="${STAGE}/control"
DATA_ROOT="${STAGE}/data"
mkdir -p "${CONTROL_ROOT}" "${DATA_ROOT}/usr/bin" \
    "${DATA_ROOT}/usr/share/doc/serial-relay" "${OUT_DIR}"

chmod 0755 "${CONTROL_ROOT}" "${DATA_ROOT}" "${DATA_ROOT}/usr" \
    "${DATA_ROOT}/usr/bin" "${DATA_ROOT}/usr/share" \
    "${DATA_ROOT}/usr/share/doc" "${DATA_ROOT}/usr/share/doc/serial-relay"

install -m 0755 "${BIN}" "${DATA_ROOT}/usr/bin/serial-relay"

{
    cat <<EOF
Package: serial-relay
Version: ${VER}
Architecture: ${ARCH}
Maintainer: luckzhang888 <luckzhang888@users.noreply.github.com>
Section: electronics
Priority: optional
EOF
    if [[ -n "${PACKAGE_DEPENDS}" ]]; then
        echo "Depends: ${PACKAGE_DEPENDS}"
    fi
    cat <<EOF
Description: 4-channel USB relay controller (CH340)
 Control a 4-channel USB relay module over a CH340 serial adapter.
 Supports on/off/toggle/status operations for each channel.
 Default device: /dev/ttyUSB0. Baud rate: ${BAUD}.
EOF
} >"${CONTROL_ROOT}/control"
chmod 0644 "${CONTROL_ROOT}/control"

cat >"${DATA_ROOT}/usr/share/doc/serial-relay/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
License: MIT
EOF
chmod 0644 "${DATA_ROOT}/usr/share/doc/serial-relay/copyright"

printf '2.0\n' >"${STAGE}/debian-binary"
tar --owner=0 --group=0 -C "${CONTROL_ROOT}" -czf "${STAGE}/control.tar.gz" .
tar --owner=0 --group=0 -C "${DATA_ROOT}" -czf "${STAGE}/data.tar.gz" .

OUT_PATH=$(realpath -m "${OUT_DIR}/serial-relay_${VER}_${ARCH}.deb")
(
    cd "${STAGE}"
    ar rcs "${OUT_PATH}" debian-binary control.tar.gz data.tar.gz
)

echo "Package: ${OUT_PATH}"
