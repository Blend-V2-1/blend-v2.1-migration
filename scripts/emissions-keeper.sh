#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BLEND_V21_LIBRARY_ONLY=true
# shellcheck source=scripts/deploy-v2.1.sh
source "${ROOT_DIR}/scripts/deploy-v2.1.sh"

INTERVAL_SECONDS="${BLEND_V21_KEEPER_INTERVAL_SECONDS:-3600}"
INCLUSION_FEE="${BLEND_V21_KEEPER_INCLUSION_FEE:-10000}"
STOP_REQUESTED=0
SLEEP_PID=""
EXPECTED_ERROR_CODE=""

usage() {
    cat <<'EOF'
Usage: scripts/emissions-keeper.sh COMMAND

Commands:
  plan  Simulate one keeper pass without mutation.
  once  Refresh the oracle and submit one keeper pass.
  run   Run one pass immediately, then repeat every hour by default.

The keeper verifies that the saved V1 emitter targets the saved V2 backstop,
refreshes the authenticated test fixture oracle on every pass, advances the
emitter, checkpoints backstop emissions, and gulps the Fixed Pool emissions.
EOF
}

keeper_note() {
    printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2
}

require_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "$2 must be a positive integer"
}

capture_invoke() {
    local send="$1" contract="$2" function="$3" output status attempt
    shift 3
    for attempt in 1 2 3 4 5; do
        set +e
        output="$(stellar_cli contract invoke \
            --id "${contract}" \
            --source-account "${OPERATOR_IDENTITY}" \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" \
            --send "${send}" --cost -- "${function}" "$@" 2>&1)"
        status=$?
        set -e
        if (( status == 0 )); then
            printf '%s' "${output}"
            return 0
        fi
        if [[ "${output}" != *"client error (Connect)"* &&
            "${output}" != *"connection closed"* &&
            "${output}" != *"timed out"* &&
            "${output}" != *"dns error"* ]]
        then
            break
        fi
        (( attempt == 5 )) || sleep 2
    done
    printf '%s' "${output}"
    return "${status}"
}

is_expected_error() {
    local output="$1" code
    shift
    for code in "$@"; do
        if [[ "${output}" =~ \#${code}([^0-9]|$) ]]; then
            EXPECTED_ERROR_CODE="${code}"
            return 0
        fi
    done
    return 1
}

plan_call() {
    local label="$1" contract="$2" function="$3" output
    shift 3
    if output="$(capture_invoke no "${contract}" "${function}")"; then
        keeper_note "${label}: ready ($(printf '%s\n' "${output}" | tail -n 1))"
        return
    fi
    if is_expected_error "${output}" "$@"; then
        keeper_note "${label}: not ready (contract error #${EXPECTED_ERROR_CODE})"
        return
    fi
    die "${label} simulation failed: ${output}"
}

run_call() {
    local label="$1" contract="$2" function="$3" output
    shift 3
    if ! output="$(capture_invoke no "${contract}" "${function}")"; then
        if is_expected_error "${output}" "$@"; then
            keeper_note "${label}: skipped (contract error #${EXPECTED_ERROR_CODE})"
            return 0
        fi
        keeper_note "${label}: simulation failed: ${output}"
        return 1
    fi
    if ! output="$(capture_invoke yes "${contract}" "${function}")"; then
        if is_expected_error "${output}" "$@"; then
            keeper_note "${label}: another keeper changed state (contract error #${EXPECTED_ERROR_CODE})"
            return 0
        fi
        keeper_note "${label}: submission failed: ${output}"
        return 1
    fi
    keeper_note "${label}: submitted ($(printf '%s\n' "${output}" | tail -n 1))"
}

refresh_oracle() {
    local oracle
    oracle="$(state_value fixed_pool_oracle)"
    keeper_note "Refreshing Fixed oracle price histories."
    seed_fixed_oracle "${oracle}"
}

load_keeper_configuration() {
    local emitter backstop pool recipient reward
    validate_runtime_tools
    require_network
    load_state
    assert_equal "verified" "$(state_value phase)" "deployment phase"
    emitter="$(state_value emitter)"
    backstop="$(state_value backstop)"
    pool="$(state_value fixed_pool)"
    require_contract_id "${emitter}" "emitter"
    require_contract_id "${backstop}" "backstop"
    require_contract_id "${pool}" "Fixed Pool"
    recipient="$(normalize_scalar "$(invoke_view \
        "keeper-query-emitter-backstop" "${emitter}" get_backstop)")"
    assert_equal "${backstop}" "${recipient}" "emitter recipient"
    reward="$(invoke_view "keeper-query-reward-zone" "${backstop}" reward_zone)"
    printf '%s' "${reward}" | jq -e --arg pool "${pool}" \
        'index($pool) != null' >/dev/null || die "Fixed Pool is absent from reward zone"
}

plan_pass() {
    local emitter backstop pool
    emitter="$(state_value emitter)"
    backstop="$(state_value backstop)"
    pool="$(state_value fixed_pool)"
    keeper_note "Fixed oracle price histories would be refreshed before emissions."
    plan_call "advance V1 emitter" "${emitter}" distribute
    plan_call "checkpoint V2.1 backstop" "${backstop}" distribute 1000 1010
    plan_call "gulp Fixed Pool emissions" "${pool}" gulp_emissions 1000 1200
}

run_pass() {
    local emitter backstop pool failed=0
    emitter="$(state_value emitter)"
    backstop="$(state_value backstop)"
    pool="$(state_value fixed_pool)"
    if ! refresh_oracle; then
        keeper_note "Fixed oracle refresh failed; skipping emissions processing for this pass."
        return 1
    fi
    run_call "advance V1 emitter" "${emitter}" distribute || failed=1
    run_call "checkpoint V2.1 backstop" "${backstop}" distribute 1000 1010 || failed=1
    run_call "gulp Fixed Pool emissions" "${pool}" gulp_emissions 1000 1200 || failed=1
    (( failed == 0 )) || return 1
    keeper_note "Keeper pass completed successfully."
}

request_stop() {
    STOP_REQUESTED=1
    [[ -z "${SLEEP_PID}" ]] || kill "${SLEEP_PID}" 2>/dev/null || true
}

run_forever() {
    local pass=0
    trap request_stop INT TERM
    keeper_note "Keeper started; pass interval is ${INTERVAL_SECONDS}s and the oracle is refreshed on every pass."
    while (( STOP_REQUESTED == 0 )); do
        pass=$((pass + 1))
        keeper_note "Beginning scheduled pass ${pass}."
        run_pass || keeper_note "Pass ${pass} failed; retrying next interval."
        (( STOP_REQUESTED != 0 )) && break
        sleep "${INTERVAL_SECONDS}" &
        SLEEP_PID=$!
        wait "${SLEEP_PID}" || true
        SLEEP_PID=""
    done
    keeper_note "Keeper stopped."
}

main() {
    case "${1:-}" in
        plan|once|run) ;;
        help|-h|--help) usage; return ;;
        *) usage >&2; exit 2 ;;
    esac
    require_positive_integer "${INTERVAL_SECONDS}" "keeper interval"
    require_positive_integer "${INCLUSION_FEE}" "keeper inclusion fee"
    export STELLAR_INCLUSION_FEE="${INCLUSION_FEE}"
    load_keeper_configuration
    case "$1" in
        plan) plan_pass ;;
        once) run_pass ;;
        run) run_forever ;;
    esac
}

main "$@"
