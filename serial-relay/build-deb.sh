#!/usr/bin/env bash
# build-deb.sh — Build serial-relay for ARM64 and create a .deb package.
#
# Usage:
#   ./build-deb.sh              # build dynamic .deb
#   ./build-deb.sh static       # build static binary
#   ./build-deb.sh static-deb   # build static .deb
#   ./build-deb.sh install      # build and install locally
#   ./build-deb.sh clean        # clean build artifacts
#
# Requirements: rustc + cargo (installed via rustup if missing)
set -euo pipefail

PKG_NAME="serial-relay"
PKG_VER="0.1.0"
PKG_ARCH="${PKG_ARCH:-arm64}"
PKG_MAINTAINER="linaro <linaro@localhost>"
DEB_FILE="${PKG_NAME}_${PKG_VER}_${PKG_ARCH}.deb"
STATIC_DEB_FILE="${PKG_NAME}-static_${PKG_VER}_${PKG_ARCH}.deb"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

fct_ensure_rust() {
    if command -v cargo &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} rustc $(rustc --version | awk '{print $2}')"
        return
    fi
    echo -e "${YELLOW}[...]${NC} Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
}

fct_build() {
    echo -e "${YELLOW}[...]${NC} Building ${PKG_NAME} v${PKG_VER}..."
    cargo build --release
    echo -e "${GREEN}[OK]${NC} Binary: $(readlink -f target/release/serial)"
}

fct_build_static() {
    echo -e "${YELLOW}[...]${NC} Building ${PKG_NAME} v${PKG_VER} (static / musl)..."
    # Use musl target for fully static binary (bundled libc, no external deps)
    # Requires: rustup target add aarch64-unknown-linux-musl
    cargo build --release --target aarch64-unknown-linux-musl
    echo -e "${GREEN}[OK]${NC} Binary: $(readlink -f target/aarch64-unknown-linux-musl/release/serial)"
    echo ""
    echo -e "${YELLOW}[...]${NC} Checking dynamic dependencies..."
    ldd target/aarch64-unknown-linux-musl/release/serial 2>&1 || true
}

fct_build_deb() {
    local DEB_ROOT="deb-pkg/${PKG_NAME}_${PKG_VER}_${PKG_ARCH}"
    local out_deb="${DEB_FILE}"
    local static_label=""
    local bin_path="target/release/serial"

    if [[ "${1:-}" == "static" ]]; then
        out_deb="${STATIC_DEB_FILE}"
        static_label="-static"
        bin_path="target/aarch64-unknown-linux-musl/release/serial"
    fi

    rm -rf "deb-pkg"
    mkdir -p "${DEB_ROOT}/DEBIAN"
    mkdir -p "${DEB_ROOT}/usr/bin"
    mkdir -p "${DEB_ROOT}/usr/share/doc/${PKG_NAME}"

    # Copy binary
    install -m 755 "${bin_path}" "${DEB_ROOT}/usr/bin/serial"

    # control file
    cat > "${DEB_ROOT}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}${static_label}
Version: ${PKG_VER}
Architecture: ${PKG_ARCH}
Maintainer: ${PKG_MAINTAINER}
Section: electronics
Priority: optional
Depends: libc6
Description: 4-channel USB relay controller (CH340)
 Control a 4-channel USB relay module over RS-232 serial via CH340.
 Supports on/off/toggle/status operations for each channel.
 Baud rate: $(grep baud_rate Cargo.toml | head -1 | grep -oP '\d+')
EOF

    # Copyright / docs
    cat > "${DEB_ROOT}/usr/share/doc/${PKG_NAME}/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
License: MIT
EOF
    gzip -cn9 changelog 2>/dev/null > "${DEB_ROOT}/usr/share/doc/${PKG_NAME}/changelog.gz" || true

    # Build .deb
    dpkg-deb --build "${DEB_ROOT}" "${out_deb}"
    echo -e "${GREEN}[OK]${NC} Package: ${out_deb}"
}

fct_install() {
    echo -e "${YELLOW}[...]${NC} Installing ${PKG_NAME}..."
    sudo install -m 755 target/release/serial /usr/local/bin/serial
    echo -e "${GREEN}[OK]${NC} Installed to /usr/local/bin/serial"
}

fct_uninstall() {
    echo -e "${YELLOW}[...]${NC} Uninstalling ${PKG_NAME}..."
    sudo rm -f /usr/local/bin/serial
    sudo dpkg -r "${PKG_NAME}" 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Removed"
}

fct_clean() {
    echo -e "${YELLOW}[...]${NC} Cleaning..."
    cargo clean
    rm -rf deb-pkg/ ./*.deb
    echo -e "${GREEN}[OK]${NC} Clean"
}

# --- Main ---
ACTION="${1:-deb}"

case "$ACTION" in
    deb)
        fct_ensure_rust
        fct_build
        fct_build_deb
        ;;
    static)
        fct_ensure_rust
        fct_build_static
        ;;
    static-deb)
        fct_ensure_rust
        fct_build_static
        fct_build_deb static
        ;;
    install|-i)
        fct_ensure_rust
        fct_build
        fct_install
        ;;
    uninstall|-u)
        fct_uninstall
        ;;
    clean|-c)
        fct_clean
        ;;
    build)
        fct_ensure_rust
        fct_build
        ;;
    *)
        echo "Usage: $0 {deb|static|static-deb|install|uninstall|clean|build}"
        exit 1
        ;;
esac
