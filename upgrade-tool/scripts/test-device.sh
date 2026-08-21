#!/usr/bin/env bash
# Run non-destructive startup, help, and USB-enumeration checks remotely.

set -euo pipefail

DEVICE_HOST=${DEVICE_HOST:-192.168.1.49}
DEVICE_USER=${DEVICE_USER:-myir}
KNOWN_HOSTS_FILE=${KNOWN_HOSTS_FILE:-}
INSTALL_PATH=/usr/local/bin/upgrade_tool

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
    file '${INSTALL_PATH}'
    help_output=\$('${INSTALL_PATH}')
    printf '%s\n' \"\${help_output}\" | grep -q -- 'Tool Usage'
    printf '%s\n' \"\${help_output}\" | sed -n '1,12p'
    sudo '${INSTALL_PATH}' LD
    if command -v lsusb >/dev/null 2>&1; then
        lsusb
    fi
"

echo "READ_ONLY_DEVICE_TESTS=PASS"
