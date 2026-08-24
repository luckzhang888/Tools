#!/usr/bin/env bash
# Reproducibly cross-compile the pinned OpenixCLI source for ARMv7 hard-float.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

UPSTREAM_REPO=https://github.com/YuzukiTsuru/OpenixCLI.git
UPSTREAM_COMMIT=4030a873038d979eed6c69441ef8b6d4b457484b
BUILD_ROOT=${BUILD_ROOT:-"${ROOT_DIR}/build/armv7"}
CHECKOUT_DIR="${BUILD_ROOT}/upstream"
SOURCE_DIR="${BUILD_ROOT}/source"
TARGET_DIR="${BUILD_ROOT}/target"
DIST_DIR=${DIST_DIR:-"${ROOT_DIR}/dist"}
BUILDER_IMAGE=${BUILDER_IMAGE:-openixcli-armv7-builder:rust-1.96.1}
ARTIFACT="${DIST_DIR}/openixcli-armv7"
PATCH_FILE="${ROOT_DIR}/patches/0001-reject-storage-type-mismatch.patch"

for required_command in docker git file readelf sha256sum tar; do
    command -v "${required_command}" >/dev/null 2>&1 || {
        echo "ERROR: ${required_command} is required" >&2
        exit 1
    }
done

[[ -s ${PATCH_FILE} ]] || {
    echo "ERROR: safety patch not found: ${PATCH_FILE}" >&2
    exit 1
}
[[ -s ${ROOT_DIR}/Cargo.lock ]] || {
    echo "ERROR: pinned Cargo.lock not found" >&2
    exit 1
}

if [[ ! -e ${CHECKOUT_DIR} ]]; then
    mkdir -p "$(dirname -- "${CHECKOUT_DIR}")"
    git clone "${UPSTREAM_REPO}" "${CHECKOUT_DIR}"
elif [[ ! -d ${CHECKOUT_DIR}/.git ]]; then
    echo "ERROR: upstream path is not a Git checkout: ${CHECKOUT_DIR}" >&2
    exit 1
fi

actual_remote=$(git -C "${CHECKOUT_DIR}" remote get-url origin)
[[ ${actual_remote} == "${UPSTREAM_REPO}" ]] || {
    echo "ERROR: upstream origin mismatch: ${actual_remote}" >&2
    exit 1
}
if ! git -C "${CHECKOUT_DIR}" diff --quiet || \
   ! git -C "${CHECKOUT_DIR}" diff --cached --quiet; then
    echo "ERROR: upstream checkout has tracked local changes" >&2
    exit 1
fi

git -C "${CHECKOUT_DIR}" fetch --depth 1 origin "${UPSTREAM_COMMIT}"
git -C "${CHECKOUT_DIR}" checkout --detach "${UPSTREAM_COMMIT}"
actual_commit=$(git -C "${CHECKOUT_DIR}" rev-parse HEAD)
[[ ${actual_commit} == "${UPSTREAM_COMMIT}" ]] || {
    echo "ERROR: upstream commit mismatch: ${actual_commit}" >&2
    exit 1
}

case ${SOURCE_DIR} in
    "${ROOT_DIR}"/build/*) ;;
    *) echo "ERROR: unsafe source path: ${SOURCE_DIR}" >&2; exit 1 ;;
esac
rm -rf -- "${SOURCE_DIR}"
mkdir -p "${SOURCE_DIR}" "${TARGET_DIR}" "${DIST_DIR}"
git -C "${CHECKOUT_DIR}" archive "${UPSTREAM_COMMIT}" | tar -x -C "${SOURCE_DIR}"
install -m 0644 "${ROOT_DIR}/Cargo.lock" "${SOURCE_DIR}/Cargo.lock"
git -C "${SOURCE_DIR}" init --quiet
git -C "${SOURCE_DIR}" apply --unidiff-zero --check "${PATCH_FILE}"
git -C "${SOURCE_DIR}" apply --unidiff-zero "${PATCH_FILE}"
rm -rf -- "${SOURCE_DIR}/.git"
grep -q 'storage_mismatch_is_rejected_before_any_download' \
    "${SOURCE_DIR}/src/flash/fes_handler/mod.rs" || {
    echo "ERROR: safety patch was not applied to the prepared source" >&2
    exit 1
}

declare -a proxy_build_args=()
declare -a proxy_run_args=()
for proxy_name in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY; do
    proxy_value=${!proxy_name:-}
    if [[ -n ${proxy_value} ]]; then
        proxy_build_args+=(--build-arg "${proxy_name}=${proxy_value}")
        proxy_run_args+=(-e "${proxy_name}=${proxy_value}")
    fi
done

docker build \
    "${proxy_build_args[@]}" \
    --file "${ROOT_DIR}/Dockerfile.armv7" \
    --tag "${BUILDER_IMAGE}" \
    "${ROOT_DIR}"

build_uid=$(id -u)
build_gid=$(id -g)
docker run --rm \
    "${proxy_run_args[@]}" \
    -e CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc \
    -e CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc \
    -e AR_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-ar \
    -e BUILD_UID="${build_uid}" \
    -e BUILD_GID="${build_gid}" \
    -v "${SOURCE_DIR}:/src:ro" \
    -v "${TARGET_DIR}:/out" \
    -w /src \
    "${BUILDER_IMAGE}" \
    bash -c '
        set -euo pipefail
        trap '\''chown -R "${BUILD_UID}:${BUILD_GID}" /out'\'' EXIT
        cargo test --locked --all-targets --target-dir /out/tests
        cargo build --locked --release --target armv7-unknown-linux-gnueabihf --target-dir /out
    '

built_binary="${TARGET_DIR}/armv7-unknown-linux-gnueabihf/release/openixcli"
binary_description=$(file "${built_binary}")
if [[ ${binary_description} != *"ELF 32-bit"* || ${binary_description} != *"ARM"* ]]; then
    echo "ERROR: unexpected build output: ${binary_description}" >&2
    exit 1
fi
if readelf -d "${built_binary}" | grep -qi 'libusb'; then
    echo "ERROR: binary unexpectedly requires a dynamic libusb" >&2
    exit 1
fi
if ! grep -aFq 'firmware storage type' "${built_binary}"; then
    echo "ERROR: built binary does not contain the storage-mismatch guard" >&2
    exit 1
fi

install -m 0755 "${built_binary}" "${ARTIFACT}"
(
    cd "${DIST_DIR}"
    sha256sum "$(basename -- "${ARTIFACT}")" > \
        "$(basename -- "${ARTIFACT}").sha256"
)

printf 'Upstream commit: %s\n' "${UPSTREAM_COMMIT}"
printf 'Artifact: %s\n' "${ARTIFACT}"
file "${ARTIFACT}"
cat "${ARTIFACT}.sha256"
