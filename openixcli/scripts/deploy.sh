#!/usr/bin/env bash
# Upload and install the verified ARMv7 OpenixCLI binary on robot.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

DEVICE_HOST=${DEVICE_HOST:-192.168.1.50}
DEVICE_USER=${DEVICE_USER:-myir}
BINARY=${BINARY:-"${ROOT_DIR}/dist/openixcli-armv7"}
KNOWN_HOSTS_FILE=${KNOWN_HOSTS_FILE:-}
REMOTE_TMP=/tmp/openixcli.new
INSTALL_PATH=/usr/local/bin/openixcli

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
if [[ ${binary_description} != *"ELF 32-bit"* || ${binary_description} != *"ARM"* ]]; then
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
[[ ${remote_sha} == "${local_sha}" ]] || {
    echo "ERROR: upload checksum mismatch" >&2
    exit 1
}

ssh -t "${ssh_options[@]}" "${destination}" "
    set -e
    case \"\$(uname -m)\" in
        armv7l|armv8l) ;;
        *) echo 'ERROR: target is not a supported 32-bit ARM system' >&2; exit 1 ;;
    esac
    chmod 0755 '${REMOTE_TMP}'
    '${REMOTE_TMP}' --version
    sudo install -o root -g root -m 0755 '${REMOTE_TMP}' '${INSTALL_PATH}'
    sync
    '${INSTALL_PATH}' --version
    sha256sum '${INSTALL_PATH}'
    rm '${REMOTE_TMP}'
"

printf 'DEPLOY=PASS\n'
printf 'Installed: %s@%s:%s\n' "${DEVICE_USER}" "${DEVICE_HOST}" "${INSTALL_PATH}"
printf 'SHA256: %s\n' "${local_sha}"
