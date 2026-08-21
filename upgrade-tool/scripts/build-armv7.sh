#!/usr/bin/env bash
# Reproducibly cross-compile bitshelf/upgrade_tool for ARMv7 hard-float.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

UPSTREAM_REPO=https://github.com/bitshelf/upgrade_tool.git
UPSTREAM_COMMIT=ea51edd64f72b338c1d6adb9c21693712f38bd83
LIBUDEV_ZERO_REPO=https://github.com/illiliti/libudev-zero.git
LIBUDEV_ZERO_COMMIT=ee32ac5f6494047b9ece26e7a5920650cdf46655

BUILD_ROOT=${BUILD_ROOT:-"${ROOT_DIR}/build/armv7"}
SOURCE_DIR="${BUILD_ROOT}/upstream"
CMAKE_BUILD_DIR="${BUILD_ROOT}/cmake"
LIBUDEV_ZERO_CHECKOUT_DIR="${BUILD_ROOT}/libudev-zero"
LIBUDEV_ZERO_BUILD_DIR="${CMAKE_BUILD_DIR}/third_party/libudev-zero-src"
DIST_DIR=${DIST_DIR:-"${ROOT_DIR}/dist"}
BUILDER_IMAGE=${BUILDER_IMAGE:-upgrade-tool-armv7-builder:bookworm}
ARTIFACT="${DIST_DIR}/upgrade_tool-armhf-static"

command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker is required" >&2
    exit 1
}
command -v git >/dev/null 2>&1 || {
    echo "ERROR: git is required" >&2
    exit 1
}
command -v file >/dev/null 2>&1 || {
    echo "ERROR: file is required" >&2
    exit 1
}
command -v tar >/dev/null 2>&1 || {
    echo "ERROR: tar is required" >&2
    exit 1
}

prepare_repo() {
    local repository=$1
    local commit=$2
    local directory=$3
    local label=$4
    local actual_remote
    local actual_commit

    if [[ ! -e ${directory} ]]; then
        mkdir -p "$(dirname -- "${directory}")"
        git clone "${repository}" "${directory}"
    elif [[ ! -d ${directory}/.git ]]; then
        echo "ERROR: ${label} directory exists but is not a Git checkout: ${directory}" >&2
        exit 1
    fi

    actual_remote=$(git -C "${directory}" remote get-url origin)
    if [[ ${actual_remote} != "${repository}" ]]; then
        echo "ERROR: ${label} origin mismatch: ${actual_remote}" >&2
        exit 1
    fi
    if ! git -C "${directory}" diff --quiet || \
       ! git -C "${directory}" diff --cached --quiet; then
        echo "ERROR: ${label} checkout has tracked local changes: ${directory}" >&2
        exit 1
    fi

    git -C "${directory}" fetch --depth 1 origin "${commit}"
    git -C "${directory}" checkout --detach "${commit}"
    actual_commit=$(git -C "${directory}" rev-parse HEAD)
    if [[ ${actual_commit} != "${commit}" ]]; then
        echo "ERROR: ${label} commit mismatch: ${actual_commit}" >&2
        exit 1
    fi
}

prepare_repo "${UPSTREAM_REPO}" "${UPSTREAM_COMMIT}" \
    "${SOURCE_DIR}" "upgrade_tool"
prepare_repo "${LIBUDEV_ZERO_REPO}" "${LIBUDEV_ZERO_COMMIT}" \
    "${LIBUDEV_ZERO_CHECKOUT_DIR}" "libudev-zero"

mkdir -p "${CMAKE_BUILD_DIR}" "${LIBUDEV_ZERO_BUILD_DIR}" "${DIST_DIR}"
git -C "${LIBUDEV_ZERO_CHECKOUT_DIR}" archive "${LIBUDEV_ZERO_COMMIT}" | \
    tar -x -C "${LIBUDEV_ZERO_BUILD_DIR}"

verify_libudev_zero_sources() {
    local relative_path

    while IFS= read -r -d '' relative_path; do
        if ! cmp -- \
            "${LIBUDEV_ZERO_CHECKOUT_DIR}/${relative_path}" \
            "${LIBUDEV_ZERO_BUILD_DIR}/${relative_path}"; then
            echo "ERROR: libudev-zero source mismatch: ${relative_path}" >&2
            exit 1
        fi
    done < <(git -C "${LIBUDEV_ZERO_CHECKOUT_DIR}" ls-files -z)
}

verify_libudev_zero_sources

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
    -e CC=arm-linux-gnueabihf-gcc \
    -e CXX=arm-linux-gnueabihf-g++ \
    -e BUILD_UID="${build_uid}" \
    -e BUILD_GID="${build_gid}" \
    -v "${SOURCE_DIR}:/src:ro" \
    -v "${CMAKE_BUILD_DIR}:/out" \
    -v "${ROOT_DIR}/cmake/toolchain-armv7.cmake:/toolchain/armv7.cmake:ro" \
    -w /src \
    "${BUILDER_IMAGE}" \
    bash -c '
        set -euo pipefail
        cmake -S /src -B /out \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=/toolchain/armv7.cmake
        cmake --build /out --parallel
        file /out/upgrade_tool
        chown -R "${BUILD_UID}:${BUILD_GID}" /out
    '

verify_libudev_zero_sources

binary_description=$(file "${CMAKE_BUILD_DIR}/upgrade_tool")
if [[ ${binary_description} != *"ELF 32-bit"* || \
      ${binary_description} != *"ARM"* || \
      ${binary_description} != *"statically linked"* ]]; then
    echo "ERROR: unexpected build output: ${binary_description}" >&2
    exit 1
fi

install -m 0755 "${CMAKE_BUILD_DIR}/upgrade_tool" "${ARTIFACT}"
(
    cd "${DIST_DIR}"
    sha256sum "$(basename -- "${ARTIFACT}")" > \
        "$(basename -- "${ARTIFACT}").sha256"
)

printf 'Upstream commit: %s\n' "${UPSTREAM_COMMIT}"
printf 'Artifact: %s\n' "${ARTIFACT}"
file "${ARTIFACT}"
cat "${ARTIFACT}.sha256"
