#!/usr/bin/env bash
# Read-only validation of the OpenixCLI installation and firmware parser.

set -euo pipefail

DEVICE_HOST=${DEVICE_HOST:-192.168.1.50}
DEVICE_USER=${DEVICE_USER:-myir}
FIRMWARE=${FIRMWARE:-/myir/image/T113i/myir_image_yt113i.img}
KNOWN_HOSTS_FILE=${KNOWN_HOSTS_FILE:-}
INSTALL_PATH=/usr/local/bin/openixcli

[[ ${DEVICE_HOST} =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
    echo "ERROR: invalid DEVICE_HOST: ${DEVICE_HOST}" >&2
    exit 1
}
[[ ${DEVICE_USER} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    echo "ERROR: invalid DEVICE_USER: ${DEVICE_USER}" >&2
    exit 1
}

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
ssh -t "${ssh_options[@]}" "${destination}" "
    set -e
    test -x '${INSTALL_PATH}'
    '${INSTALL_PATH}' --version
    file '${INSTALL_PATH}'
    sha256sum '${INSTALL_PATH}'
    if test -f '${FIRMWARE}'; then
        sha256sum '${FIRMWARE}'
        '${INSTALL_PATH}' inspect '${FIRMWARE}'
    else
        echo 'NOTICE: firmware not found; inspect test skipped: ${FIRMWARE}'
    fi
    sudo '${INSTALL_PATH}' --backend libusb scan --detailed
"

printf 'READ_ONLY_TEST=PASS\n'
