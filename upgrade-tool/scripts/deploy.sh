#!/usr/bin/env bash
# Upload and install the verified ARMv7 binary on a remote Linux device.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

DEVICE_HOST=${DEVICE_HOST:-192.168.1.49}
DEVICE_USER=${DEVICE_USER:-myir}
BINARY=${BINARY:-"${ROOT_DIR}/dist/upgrade_tool-armhf-static"}
KNOWN_HOSTS_FILE=${KNOWN_HOSTS_FILE:-}
REMOTE_TMP=/tmp/upgrade_tool.new
INSTALL_PATH=/usr/local/bin/upgrade_tool

[[ ${DEVICE_HOST} =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
    echo "ERROR: invalid DEVICE_HOST: ${DEVICE_HOST}" >&2
    exit 1
}
[[ ${DEVICE_USER} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    echo "ERROR: invalid DEVICE_USER: ${DEVICE_USER}" >&2
    exit 1
}
[[ -f ${BINARY} ]] || {
    echo "ERROR: binary not found: ${BINARY}" >&2
    exit 1
}

binary_description=$(file "${BINARY}")
if [[ ${binary_description} != *"ELF 32-bit"* || \
      ${binary_description} != *"ARM"* || \
      ${binary_description} != *"statically linked"* ]]; then
    echo "ERROR: refusing to deploy a non-ARMv7 binary: ${binary_description}" >&2
    exit 1
fi

declare -a ssh_options=(-o ConnectTimeout=10)
if [[ -n ${KNOWN_HOSTS_FILE} ]]; then
    [[ -f ${KNOWN_HOSTS_FILE} ]] || {
        echo "ERROR: KNOWN_HOSTS_FILE not found: ${KNOWN_HOSTS_FILE}" >&2
        exit 1
    }
    ssh_options+=(
        -o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}"
        -o GlobalKnownHostsFile=/dev/null
        -o StrictHostKeyChecking=yes
    )
fi

destination="${DEVICE_USER}@${DEVICE_HOST}"
local_sha=$(sha256sum "${BINARY}" | cut -d' ' -f1)

scp "${ssh_options[@]}" "${BINARY}" "${destination}:${REMOTE_TMP}"
remote_sha=$(ssh "${ssh_options[@]}" "${destination}" \
    "sha256sum '${REMOTE_TMP}' | cut -d' ' -f1")
if [[ ${remote_sha} != "${local_sha}" ]]; then
    echo "ERROR: upload checksum mismatch" >&2
    exit 1
fi

ssh -t "${ssh_options[@]}" "${destination}" "
    set -e
    case \"\$(uname -m)\" in
        armv7l|armv8l) ;;
        *) echo 'ERROR: target is not a supported 32-bit ARM system' >&2; exit 1 ;;
    esac
    uname -m
    file '${REMOTE_TMP}'
    chmod 0755 '${REMOTE_TMP}'
    '${REMOTE_TMP}' >/dev/null
    sudo install -m 0755 '${REMOTE_TMP}' '${INSTALL_PATH}'
    sync
    file '${INSTALL_PATH}'
    sha256sum '${INSTALL_PATH}'
    rm '${REMOTE_TMP}'
"

printf 'DEPLOY=PASS\n'
printf 'Installed: %s@%s:%s\n' "${DEVICE_USER}" "${DEVICE_HOST}" "${INSTALL_PATH}"
printf 'SHA256: %s\n' "${local_sha}"
