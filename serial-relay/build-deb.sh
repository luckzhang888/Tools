#!/usr/bin/env bash
# Build serial-relay and optionally create a Debian package.
#
# Examples:
#   ./build-deb.sh build
#   ./build-deb.sh deb
#   TARGET=armv7-unknown-linux-gnueabihf PKG_ARCH=armhf ./build-deb.sh deb
#   TARGET=aarch64-unknown-linux-gnu PKG_ARCH=arm64 ./build-deb.sh deb
#   TARGET=armv7-unknown-linux-musleabihf ./build-deb.sh static-deb

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "${ROOT_DIR}"

ACTION=${1:-deb}
TARGET=${TARGET:-}
PKG_ARCH=${PKG_ARCH:-}

usage() {
    cat <<'EOF'
Usage: ./build-deb.sh {build|deb|static|static-deb|install|clean}

Environment:
  TARGET       Rust target triple. Empty means a native build.
  PKG_ARCH     Debian architecture (amd64, arm64 or armhf). Auto-detected.
  PREFIX       Install prefix for the install action (default: /usr/local).
  DESTDIR      Optional staging root for the install action.
EOF
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required tool not found: $1" >&2
        exit 1
    }
}

native_target() {
    rustc -vV | sed -n 's/^host: //p'
}

default_musl_target() {
    case "$(native_target)" in
        x86_64-unknown-linux-gnu) echo x86_64-unknown-linux-musl ;;
        aarch64-unknown-linux-gnu) echo aarch64-unknown-linux-musl ;;
        armv7-unknown-linux-gnueabihf) echo armv7-unknown-linux-musleabihf ;;
        *)
            echo "ERROR: set TARGET to an explicit musl target" >&2
            exit 1
            ;;
    esac
}

deb_arch_for_target() {
    case "$1" in
        x86_64-*) echo amd64 ;;
        aarch64-*) echo arm64 ;;
        armv7-*gnueabihf | armv7-*musleabihf) echo armhf ;;
        *)
            echo "ERROR: cannot map Rust target '$1' to a Debian architecture" >&2
            exit 1
            ;;
    esac
}

build() {
    local args=(build --release --locked)
    if [[ -n "${TARGET}" ]]; then
        args+=(--target "${TARGET}")
    fi
    cargo "${args[@]}"
}

binary_path() {
    if [[ -n "${TARGET}" ]]; then
        echo "target/${TARGET}/release/serial-relay"
    else
        echo "target/release/serial-relay"
    fi
}

package_deb() {
    local effective_target=${TARGET:-$(native_target)}
    local arch=${PKG_ARCH:-$(deb_arch_for_target "${effective_target}")}
    local depends='libc6, libgcc-s1'
    if [[ "${effective_target}" == *musl* ]]; then
        depends=''
    fi
    PACKAGE_DEPENDS="${depends}" \
        ./scripts/package-deb.sh "$(binary_path)" "${arch}" dist
}

require_tool cargo
require_tool rustc

case "${ACTION}" in
    build)
        build
        ;;
    deb)
        build
        package_deb
        ;;
    static | static-deb)
        TARGET=${TARGET:-$(default_musl_target)}
        if [[ "${TARGET}" != *musl* ]]; then
            echo "ERROR: static builds require a musl TARGET" >&2
            exit 1
        fi
        build
        if [[ "${ACTION}" == static-deb ]]; then
            package_deb
        fi
        ;;
    install)
        if [[ -n "${TARGET}" ]]; then
            echo "ERROR: install only supports a native build; use DESTDIR with make install for staging" >&2
            exit 1
        fi
        build
        install -D -m 0755 "$(binary_path)" \
            "${DESTDIR:-}${PREFIX:-/usr/local}/bin/serial-relay"
        ;;
    clean)
        cargo clean
        rm -rf dist
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
