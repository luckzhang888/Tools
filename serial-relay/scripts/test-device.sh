#!/usr/bin/env bash
# Query all four relay channels, or exercise ON/OFF and restore initial states.

set -euo pipefail

BIN=${SERIAL_RELAY_BIN:-serial-relay}
DEVICE=${SERIAL_RELAY_DEVICE:-/dev/ttyUSB0}
EXERCISE=0

usage() {
    cat <<'EOF'
Usage: ./scripts/test-device.sh [--exercise] [--device PATH] [--binary PATH]

Without --exercise, only status queries are sent. With --exercise, each channel
is switched ON and OFF, verified after each operation, then restored to its
initial state. Be sure attached equipment can be switched safely.
EOF
}

while (($#)); do
    case "$1" in
        --exercise)
            EXERCISE=1
            shift
            ;;
        --device)
            DEVICE=${2:?--device requires a path}
            shift 2
            ;;
        --binary)
            BIN=${2:?--binary requires a path}
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

command -v "${BIN}" >/dev/null 2>&1 || [[ -x "${BIN}" ]] || {
    echo "ERROR: binary not found or not executable: ${BIN}" >&2
    exit 1
}
[[ -r "${DEVICE}" && -w "${DEVICE}" ]] || {
    echo "ERROR: serial device is not readable and writable: ${DEVICE}" >&2
    exit 1
}

QUERY_STATE=
query_state() {
    local port=$1
    local output
    output=$("${BIN}" -d "${DEVICE}" -p "${port}" status 2>&1) || {
        printf '%s\n' "${output}" >&2
        return 1
    }
    printf '%s\n' "${output}"
    if [[ "${output}" =~ status:\ (ON|OFF) ]]; then
        QUERY_STATE=${BASH_REMATCH[1],,}
    elif [[ "${output}" =~ response\ \(4\ bytes\):\ A0\ [0-9A-Fa-f]{2}\ (00|01)\ [0-9A-Fa-f]{2} ]]; then
        [[ ${BASH_REMATCH[1]} == 01 ]] && QUERY_STATE=on || QUERY_STATE=off
    else
        echo "ERROR: cannot parse CH$((port + 1)) state" >&2
        return 1
    fi
}

declare -a INITIAL_STATES
for port in 0 1 2 3; do
    echo "CH$((port + 1)) INITIAL"
    query_state "${port}"
    INITIAL_STATES[port]=${QUERY_STATE}
done

if ((EXERCISE == 0)); then
    echo "ALL_CHANNEL_STATUS=PASS"
    exit 0
fi

restore_initial_states() {
    local port
    set +e
    for port in 0 1 2 3; do
        [[ -n ${INITIAL_STATES[port]:-} ]] || continue
        "${BIN}" -d "${DEVICE}" -p "${port}" "${INITIAL_STATES[port]}" >/dev/null 2>&1
    done
}
trap restore_initial_states EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for port in 0 1 2 3; do
    channel=$((port + 1))

    echo "CH${channel} ON_TEST"
    "${BIN}" -d "${DEVICE}" -p "${port}" on
    sleep 1
    query_state "${port}"
    [[ ${QUERY_STATE} == on ]] || {
        echo "ERROR: CH${channel} failed to reach ON" >&2
        exit 1
    }
    echo "CH${channel} ON_VERIFY=PASS"

    echo "CH${channel} OFF_TEST"
    "${BIN}" -d "${DEVICE}" -p "${port}" off
    sleep 1
    query_state "${port}"
    [[ ${QUERY_STATE} == off ]] || {
        echo "ERROR: CH${channel} failed to reach OFF" >&2
        exit 1
    }
    echo "CH${channel} OFF_VERIFY=PASS"
done

restore_initial_states
set -e
for port in 0 1 2 3; do
    echo "CH$((port + 1)) RESTORE_VERIFY"
    query_state "${port}"
    [[ ${QUERY_STATE} == "${INITIAL_STATES[port]}" ]] || {
        echo "ERROR: CH$((port + 1)) was not restored to ${INITIAL_STATES[port]}" >&2
        exit 1
    }
done
trap - EXIT HUP INT TERM
echo "ALL_CHANNEL_TESTS=PASS"
