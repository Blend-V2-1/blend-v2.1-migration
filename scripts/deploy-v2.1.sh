#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NETWORK_MODE="${BLEND_V21_NETWORK:-local}"
case "${NETWORK_MODE}" in
    local)
        NETWORK_LABEL="Localnet"
        WORK_DIR="${BLEND_V21_LOCALNET_WORK_DIR:-${ROOT_DIR}/.localnet}"
        RPC_PORT="${BLEND_V21_LOCALNET_RPC_PORT:-8000}"
        RPC_URL="${BLEND_V21_RPC_URL:-http://127.0.0.1:${RPC_PORT}/soroban/rpc}"
        HORIZON_URL="${BLEND_V21_HORIZON_URL:-http://127.0.0.1:${RPC_PORT}}"
        FRIENDBOT_URL="${BLEND_V21_FRIENDBOT_URL:-http://127.0.0.1:${RPC_PORT}/friendbot}"
        NETWORK_PASSPHRASE="Standalone Network ; February 2017"
        OPERATOR_IDENTITY="${BLEND_V21_OPERATOR_IDENTITY:-blend-v21-local-operator}"
        BLNT_ISSUER_IDENTITY="${BLEND_V21_BLNT_ISSUER_IDENTITY:-blend-v21-local-blnt-issuer}"
        CONTROLLER_IDENTITY="${BLEND_V21_CONTROLLER_IDENTITY:-blend-v21-local-comet-controller}"
        ;;
    testnet)
        NETWORK_LABEL="Public testnet"
        WORK_DIR="${BLEND_V21_TESTNET_WORK_DIR:-${ROOT_DIR}/.testnet}"
        RPC_PORT=""
        RPC_URL="${BLEND_V21_RPC_URL:-https://soroban-testnet.stellar.org}"
        HORIZON_URL="${BLEND_V21_HORIZON_URL:-https://horizon-testnet.stellar.org}"
        FRIENDBOT_URL="${BLEND_V21_FRIENDBOT_URL:-https://friendbot.stellar.org/}"
        NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
        OPERATOR_IDENTITY="${BLEND_V21_OPERATOR_IDENTITY:-blend-v21-testnet-operator}"
        BLNT_ISSUER_IDENTITY="${BLEND_V21_BLNT_ISSUER_IDENTITY:-blend-v21-testnet-blnt-issuer}"
        CONTROLLER_IDENTITY="${BLEND_V21_CONTROLLER_IDENTITY:-blend-v21-testnet-comet-controller}"
        ;;
    *)
        printf 'error: unsupported BLEND_V21_NETWORK: %s\n' "${NETWORK_MODE}" >&2
        exit 2
        ;;
esac

CONFIG_DIR="${BLEND_V21_CONFIG_DIR:-${WORK_DIR}/stellar-config}"
STATE_FILE="${BLEND_V21_STATE_FILE:-${WORK_DIR}/state.json}"
CONTAINER_NAME="${BLEND_V21_LOCALNET_CONTAINER:-blend-v21-local}"
DOCKER_HOST_URI="${BLEND_V21_DOCKER_HOST:-}"
DEPLOY_STELLAR="${BLEND_V21_DEPLOY_STELLAR:-stellar}"
EXTERNAL_BLND="${BLEND_V21_EXTERNAL_BLND:-CB22KRA3YZVCNCQI64JQ5WE7UY2VAV7WFLK6A2JN3HEX56T2EDAFO7QF}"
BLNT_HOME_DOMAIN="${BLEND_BLNT_HOME_DOMAIN:-}"

SCALAR_7=10000000
BACKFILL_ALLOCATION=$((74000000 * SCALAR_7))
GRANT_ALLOCATION=0
SWAP_CAPACITY=$((51000000 * SCALAR_7))
BACKFILL_PREMINT=$((125000000 * SCALAR_7))
COMET_BLNT_BALANCE=$((1000 * SCALAR_7))
COMET_USDC_BALANCE=$((25 * SCALAR_7))
COMET_BLNT_WEIGHT=8000000
COMET_USDC_WEIGHT=2000000
COMET_SWAP_FEE=30000
COMET_CONTROLLER_THRESHOLD=100
BLNT_ISSUER_THRESHOLD=88
BACKSTOP_SALT="${BLEND_V21_BACKSTOP_SALT:-0000000000000000000000000000000000000000000000000000000000000021}"

V1_DIR="${ROOT_DIR}/blend-contracts"
V2_DIR="${ROOT_DIR}/blend-contracts-v2"
BACKFILL_DIR="${ROOT_DIR}/blnt-backfill-contract"
COMET_DIR="${ROOT_DIR}/comet-contracts-v1.1"
V1_EMITTER_WASM="${V1_DIR}/blend-contract-sdk/wasm/emitter.wasm"
V1_EMITTER_SHA256="438a5528cff17ede6fe515f095c43c5f15727af17d006971485e52462e7e7b89"
V2_ARTIFACT_DIR="${ROOT_DIR}/.artifacts/blend-contracts-v2/v2.0.0-cli22.0.1"
V2_FACTORY_WASM="${V2_ARTIFACT_DIR}/pool_factory.wasm"
V2_FACTORY_SHA256="31328050548831f63d2b72e37bcfd0bb7371b7907135755dbe09ed434d755ca9"
V2_FACTORY_RELEASE="v2.0.0_pool-factory_cli22.0.1"
V2_BACKSTOP_WASM="${V2_ARTIFACT_DIR}/backstop.wasm"
V2_BACKSTOP_SHA256="c1f4502a757e25c611f5a159bc1ab0eef64085adac6c68123dca66e87faffbc2"
V2_BACKSTOP_RELEASE="v2.0.0_backstop_cli22.0.1"
V2_POOL_WASM="${V2_ARTIFACT_DIR}/pool.wasm"
V2_POOL_SHA256="a41fc53d6753b6c04eb15b021c55052366a4c8e0e21bc72700f461264ec1350e"
V2_POOL_RELEASE="v2.0.0_pool_cli22.0.1"
BACKFILL_WASM="${BACKFILL_DIR}/target/wasm32v1-none/optimized/blnt_backfill_contract.wasm"
BACKFILL_WASM_SHA256="a30dd9dab5b0a41e14ede140dfeb250f610bee8922f3c6ca963ec813d1a209cc"
COMET_WASM="${COMET_DIR}/target/wasm32v1-none/optimized/comet.wasm"
COMET_WASM_SHA256="7613f207c48f69c0299da2cb4a7a2946bbac7479ffcbeb7e428aa1d4ee37d113"
BACKFILL_MANIFEST="${BACKFILL_DIR}/allocations/comet_cpal_backfill.json"
BACKFILL_SOURCE_SHA256="30fbbb6c62c8812a94cfb02f1c9d528235a28dcddfb45fa7f5535e39fd9a4cd3"
CLAIM_LIST=""
RUN_DIR=""

usage() {
    cat <<'EOF'
Usage: scripts/deploy-v2.1.sh COMMAND

Commands:
  plan      Describe the v2.1 deployment without mutation.
  validate  Validate the allocation manifest and build all pinned artifacts.
  start     Start local Protocol-27 Quickstart or check public testnet health.
  deploy    Deploy and verify a fresh v2.1 stack on the selected network.
  run       Validate, start, deploy, and report status.
  status    Read and verify the recorded deployment without submitting transactions.
  stop      Stop the ephemeral local Quickstart container.

Set BLEND_V21_NETWORK=testnet for public testnet. Public state, signing keys,
transaction output, and cost logs remain in the ignored network work directory.
Set BLEND_BLNT_HOME_DOMAIN to an optional BLNT issuer metadata domain.
EOF
}

note() {
    printf '%s\n' "$*" >&2
}

die() {
    note "error: $*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_blnt_home_domain() {
    local label
    local -a labels
    [[ -z "${BLNT_HOME_DOMAIN}" ]] && return
    [[ "${#BLNT_HOME_DOMAIN}" -le 32 ]] ||
        die "BLEND_BLNT_HOME_DOMAIN exceeds Stellar's 32-character limit"
    [[ "${BLNT_HOME_DOMAIN}" != .* && \
        "${BLNT_HOME_DOMAIN}" != *. && \
        "${BLNT_HOME_DOMAIN}" != *..* ]] ||
        die "invalid BLEND_BLNT_HOME_DOMAIN: ${BLNT_HOME_DOMAIN}"
    IFS='.' read -r -a labels <<<"${BLNT_HOME_DOMAIN}"
    [[ "${#labels[@]}" -gt 0 ]] ||
        die "invalid BLEND_BLNT_HOME_DOMAIN: ${BLNT_HOME_DOMAIN}"
    for label in "${labels[@]}"; do
        [[ "${label}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] ||
            die "invalid BLEND_BLNT_HOME_DOMAIN: ${BLNT_HOME_DOMAIN}"
    done
}

sha256_file() {
    local result
    result="$(shasum -a 256 "$1")"
    printf '%s\n' "${result%% *}"
}

stellar_cli() {
    "${DEPLOY_STELLAR}" --config-dir "${CONFIG_DIR}" "$@"
}

normalize_scalar() {
    local raw="$1" decoded
    if decoded="$(printf '%s' "${raw}" | jq -er '
        if type == "string" or type == "number" or type == "boolean"
        then tostring else empty end
    ' 2>/dev/null)"
    then
        printf '%s\n' "${decoded}"
    else
        printf '%s\n' "${raw}"
    fi
}

assert_equal() {
    [[ "$1" == "$2" ]] || die "$3: expected $1, found $2"
}

require_contract_id() {
    [[ "$1" =~ ^C[A-Z2-7]{55}$ ]] || die "invalid contract ID for $2: $1"
}

validate_runtime_tools() {
    local version_text version_line version major
    require_command curl
    require_command jq
    require_command "${DEPLOY_STELLAR}"

    version_text="$("${DEPLOY_STELLAR}" --version)"
    version_line="${version_text%%$'\n'*}"
    version="${version_line#stellar }"
    major="${version%%.*}"
    [[ "${major}" == "27" ]] ||
        die "Stellar CLI major version 27 is required for deployment; found ${version_line}"
}

validate_build_tools() {
    validate_runtime_tools
    require_command cargo
    require_command curl
    require_command git
    require_command make
    require_command shasum
}

validate_manifest() {
    [[ -s "${BACKFILL_MANIFEST}" ]] ||
        die "backfill allocation manifest is missing: ${BACKFILL_MANIFEST}"
    jq -e \
        --arg allocation "${BACKFILL_ALLOCATION}" \
        --arg source_hash "${BACKFILL_SOURCE_SHA256}" \
        '
          .schema_version == 1 and
          .source_file == "comet_cpal_flattened_ownership_before_41c898a1.csv" and
          .source_sha256 == $source_hash and
          .weight_field == "flattened_total_cpal_raw" and
          .allocation_total_raw == $allocation and
          .claimant_count == 434 and
          .claimant_type_counts.account == 423 and
          .claimant_type_counts.contract == 11 and
          (.allocations | length) == 434 and
          ([.allocations[].owner_address] | unique | length) == 434 and
          ([.allocations[].allocation_raw | test("^[1-9][0-9]*$")] | all) and
          (([.allocations[].allocation_raw | tonumber] | add | tostring) == $allocation)
        ' "${BACKFILL_MANIFEST}" >/dev/null ||
        die "backfill allocation manifest failed invariant validation"

    CLAIM_LIST="$(jq -c '[.allocations[] | [.owner_address, .allocation_raw]]' \
        "${BACKFILL_MANIFEST}")"
    jq -e '
        type == "array" and length == 434 and
        ([.[] |
          type == "array" and length == 2 and
          (.[0] | type == "string" and test("^[CG][A-Z2-7]{55}$")) and
          (.[1] | type == "string" and test("^[1-9][0-9]*$"))
        ] | all) and
        ([.[][0]] | unique | length) == 434
    ' <<<"${CLAIM_LIST}" >/dev/null || die "invalid committed claim-list encoding"
    assert_equal "${BACKFILL_PREMINT}" \
        "$((BACKFILL_ALLOCATION + GRANT_ALLOCATION + SWAP_CAPACITY))" \
        "zero-grant backfill funding"
}

build_artifacts() {
    note "Fetching official V2 artifacts and building the two custom contract lanes..."
    make -C "${ROOT_DIR}" build
}

validate_artifacts() {
    local artifact
    for artifact in \
        "${V1_EMITTER_WASM}" \
        "${V2_FACTORY_WASM}" \
        "${V2_BACKSTOP_WASM}" \
        "${V2_POOL_WASM}" \
        "${BACKFILL_WASM}" \
        "${COMET_WASM}"
    do
        [[ -s "${artifact}" ]] || die "missing or empty WASM artifact: ${artifact}"
    done
    assert_equal "${V1_EMITTER_SHA256}" "$(sha256_file "${V1_EMITTER_WASM}")" \
        "committed V1 emitter WASM hash"
    assert_equal "${V2_FACTORY_SHA256}" "$(sha256_file "${V2_FACTORY_WASM}")" \
        "official V2 pool factory release WASM hash"
    assert_equal "${V2_BACKSTOP_SHA256}" "$(sha256_file "${V2_BACKSTOP_WASM}")" \
        "official V2 backstop release WASM hash"
    assert_equal "${V2_POOL_SHA256}" "$(sha256_file "${V2_POOL_WASM}")" \
        "official V2 pool release WASM hash"
    assert_equal "${BACKFILL_WASM_SHA256}" "$(sha256_file "${BACKFILL_WASM}")" \
        "designated BLNT backfill WASM hash"
    assert_equal "${COMET_WASM_SHA256}" "$(sha256_file "${COMET_WASM}")" \
        "designated Comet v1.1 WASM hash"
}

network_healthy() {
    curl --fail --silent --show-error --max-time 5 \
        --header "Content-Type: application/json" \
        --request POST \
        --data '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
        "${RPC_URL}" 2>/dev/null |
        jq -e '.result.status == "healthy"' >/dev/null 2>&1
}

require_network() {
    for _ in {1..30}; do
        if network_healthy; then
            return
        fi
        sleep 2
    done
    die "${NETWORK_LABEL} RPC is unavailable at ${RPC_URL}"
}

require_docker() {
    local active_context
    require_command docker
    docker info >/dev/null 2>&1 || die "Docker daemon is unavailable"
    if [[ -z "${DOCKER_HOST_URI}" ]]; then
        active_context="$(docker context show)"
        DOCKER_HOST_URI="$(docker context inspect "${active_context}" \
            --format '{{.Endpoints.docker.Host}}')"
    fi
    [[ -n "${DOCKER_HOST_URI}" ]] || die "unable to resolve Docker socket"
}

ensure_identity() {
    local identity="$1"
    if ! stellar_cli keys public-key "${identity}" >/dev/null 2>&1; then
        stellar_cli keys generate "${identity}" >/dev/null
    fi
    stellar_cli keys public-key "${identity}"
}

fund_and_wait_for_account() {
    local account="$1"
    for _ in {1..120}; do
        if curl --fail --silent --show-error --max-time 5 \
            "${HORIZON_URL}/accounts/${account}" >/dev/null 2>&1
        then
            return
        fi
        curl --fail --silent --show-error --max-time 10 \
            --get --data-urlencode "addr=${account}" \
            "${FRIENDBOT_URL}" >/dev/null 2>&1 || true
        sleep 1
    done
    die "funded account did not become visible: ${account}"
}

new_run_dir() {
    RUN_DIR="${WORK_DIR}/runs/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "${RUN_DIR}"
}

initialize_state() {
    local operator="$1" blnt_issuer="$2" controller="$3"
    mkdir -p "${WORK_DIR}"
    jq -n \
        --arg network_mode "${NETWORK_MODE}" \
        --arg network_label "${NETWORK_LABEL}" \
        --arg network_passphrase "${NETWORK_PASSPHRASE}" \
        --arg rpc_url "${RPC_URL}" \
        --arg operator "${operator}" \
        --arg blnt_issuer "${blnt_issuer}" \
        --arg comet_controller "${controller}" \
        --argjson blnt_issuer_threshold "${BLNT_ISSUER_THRESHOLD}" \
        --arg run_dir "${RUN_DIR}" \
        --arg root_commit "$(git -C "${ROOT_DIR}" rev-parse HEAD)" \
        --arg v1_commit "$(git -C "${V1_DIR}" rev-parse HEAD)" \
        --arg v2_commit "$(git -C "${V2_DIR}" rev-parse HEAD)" \
        --arg backfill_commit "$(git -C "${BACKFILL_DIR}" rev-parse HEAD)" \
        --arg comet_commit "$(git -C "${COMET_DIR}" rev-parse HEAD)" \
        --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          network_mode: $network_mode,
          network_label: $network_label,
          network_passphrase: $network_passphrase,
          rpc_url: $rpc_url,
          operator: $operator,
          blnt_issuer: $blnt_issuer,
          blnt_issuer_threshold: $blnt_issuer_threshold,
          comet_controller: $comet_controller,
          run_dir: $run_dir,
          source: {
            migration: $root_commit,
            blend_contracts_v1: $v1_commit,
            blend_contracts_v2: $v2_commit,
            backfill: $backfill_commit,
            comet_v11: $comet_commit
          },
          created_at: $created_at,
          phase: "deploying"
        }' >"${STATE_FILE}"
}

state_value() {
    jq -er --arg key "$1" '.[$key]' "${STATE_FILE}"
}

state_set() {
    local key="$1" value="$2" temporary="${STATE_FILE}.tmp"
    jq --arg key "${key}" --arg value "${value}" '.[$key] = $value' \
        "${STATE_FILE}" >"${temporary}"
    mv "${temporary}" "${STATE_FILE}"
}

load_state() {
    [[ -s "${STATE_FILE}" ]] || die "deployment state not found: ${STATE_FILE}"
    assert_equal "${NETWORK_MODE}" "$(state_value network_mode)" "saved network mode"
    assert_equal "${RPC_URL}" "$(state_value rpc_url)" "saved RPC URL"
    assert_equal "${BLNT_ISSUER_THRESHOLD}" \
        "$(state_value blnt_issuer_threshold)" "saved BLNT issuer threshold"
    RUN_DIR="$(state_value run_dir)"
    [[ -d "${RUN_DIR}" ]] || die "saved run directory not found: ${RUN_DIR}"
}

capture() {
    local label="$1" stdout_file stderr_file status suffix=2
    shift
    stdout_file="${RUN_DIR}/${label}.out"
    stderr_file="${RUN_DIR}/${label}.cost.log"
    while [[ -e "${stdout_file}" || -e "${stderr_file}" ]]; do
        stdout_file="${RUN_DIR}/${label}-${suffix}.out"
        stderr_file="${RUN_DIR}/${label}-${suffix}.cost.log"
        suffix=$((suffix + 1))
    done
    note "Executing ${label}..."
    if "$@" >"${stdout_file}" 2> >(tee "${stderr_file}" >&2); then
        status=0
    else
        status=$?
    fi
    cat "${stdout_file}"
    return "${status}"
}

deploy_wasm() {
    local label="$1" wasm="$2" salt="$3" raw contract_id
    local -a command
    shift 3
    command=(
        stellar_cli contract deploy
        --wasm "${wasm}"
        --optimize=false
        --source-account "${OPERATOR_IDENTITY}"
        --rpc-url "${RPC_URL}"
        --network-passphrase "${NETWORK_PASSPHRASE}"
        --cost
    )
    [[ -z "${salt}" ]] || command+=(--salt "${salt}")
    (( $# == 0 )) || command+=(-- "$@")
    raw="$(capture "${label}" "${command[@]}")"
    contract_id="$(normalize_scalar "${raw}")"
    require_contract_id "${contract_id}" "${label}"
    printf '%s\n' "${contract_id}"
}

upload_wasm() {
    local label="$1" wasm="$2" raw hash
    raw="$(capture "${label}" stellar_cli contract upload \
        --wasm "${wasm}" \
        --optimize=false \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost)"
    hash="$(normalize_scalar "${raw}")"
    [[ "${hash}" =~ ^[0-9a-fA-F]{64}$ ]] || die "invalid WASM hash: ${hash}"
    printf '%s\n' "${hash}"
}

deploy_asset() {
    local label="$1" code="$2" issuer="$3" raw contract_id
    raw="$(capture "${label}" stellar_cli contract asset deploy \
        --asset "${code}:${issuer}" \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost)"
    contract_id="$(normalize_scalar "${raw}")"
    require_contract_id "${contract_id}" "${label}"
    printf '%s\n' "${contract_id}"
}

create_trustline() {
    local label="$1" identity="$2" asset="$3"
    capture "${label}" stellar_cli tx new change-trust \
        --source-account "${identity}" \
        --line "${asset}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
}

invoke_transaction_as() {
    local label="$1" source="$2" contract="$3" function="$4"
    shift 4
    capture "${label}" stellar_cli contract invoke \
        --id "${contract}" \
        --source-account "${source}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost -- "${function}" "$@"
}

invoke_transaction() {
    local label="$1" contract="$2" function="$3"
    shift 3
    invoke_transaction_as "${label}" "${OPERATOR_IDENTITY}" \
        "${contract}" "${function}" "$@"
}

invoke_view() {
    local label="$1" contract="$2" function="$3"
    shift 3
    capture "${label}" stellar_cli contract invoke \
        --id "${contract}" \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --send no --cost -- "${function}" "$@"
}

predict_contract_id() {
    local label="$1" salt="$2" raw
    raw="$(capture "${label}" stellar_cli contract id wasm \
        --salt "${salt}" \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}")"
    normalize_scalar "${raw}"
}

sac_balance_key_xdr() {
    local holder="$1" key_json
    require_contract_id "${holder}" "SAC contract-balance holder"
    key_json="$(jq -cn --arg holder "${holder}" \
        '{vec: [{symbol: "Balance"}, {address: $holder}]}')"
    stellar_cli xdr encode --type ScVal --output single-base64 "${key_json}"
}

verify_non_clawbackable_sac_balance() {
    local label="$1" token="$2" holder="$3" key_xdr entry facts
    local amount authorized clawback
    key_xdr="$(sac_balance_key_xdr "${holder}")"
    entry="$(capture "${label}" stellar_cli ledger entry fetch contract-data \
        --contract "${token}" \
        --key-xdr "${key_xdr}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --output json)" || die "${label} contract-balance entry is unavailable"
    facts="$(printf '%s' "${entry}" | jq -ce '
        def field($name):
          ([.[] | select(.key.symbol? == $name) | .val] |
            if length == 1 then .[0] else error("missing or duplicate " + $name) end);
        if (.entries | length) != 1 then error("expected exactly one entry")
        else .entries[0].val.contract_data.val.map as $fields |
          {
            amount: ($fields | field("amount") | .i128),
            authorized: ($fields | field("authorized") | .bool),
            clawback: ($fields | field("clawback") | .bool)
          }
        end
    ')" || die "${label} is not a Protocol-27 SAC contract-balance entry"
    amount="$(printf '%s' "${facts}" | jq -er '.amount | tostring')"
    authorized="$(printf '%s' "${facts}" | jq -er '.authorized | tostring')"
    clawback="$(printf '%s' "${facts}" | jq -er '.clawback | tostring')"
    [[ "${amount}" =~ ^[1-9][0-9]*$ ]] || die "${label} balance is not positive"
    assert_equal "true" "${authorized}" "${label} authorization"
    assert_equal "false" "${clawback}" "${label} clawback flag"
}

require_clean_blnt_issuer() {
    local issuer="$1" account
    account="$(capture "query-blnt-issuer-before-deploy" \
        curl --fail --silent --show-error --max-time 10 \
        "${HORIZON_URL}/accounts/${issuer}")"
    jq -e --arg issuer "${issuer}" '
      .account_id == $issuer and
      .thresholds.low_threshold == 0 and
      .thresholds.med_threshold == 0 and
      .thresholds.high_threshold == 0 and
      (.signers | length) == 1 and
      .signers[0].key == $issuer and
      .signers[0].weight == 1 and
      .home_domain == "" and
      .flags.auth_required == false and
      .flags.auth_revocable == false and
      .flags.auth_immutable == false and
      .flags.auth_clawback_enabled == false
    ' <<<"${account}" >/dev/null ||
        die "BLNT issuer is not a clean, sole-signer account"
}

verify_blnt_issuer_home_domain() {
    local issuer="$1" expected="$2" account domain_matches=false
    for _ in {1..30}; do
        if account="$(capture "query-blnt-issuer-home-domain" \
            curl --fail --silent --show-error --max-time 10 \
            "${HORIZON_URL}/accounts/${issuer}")" &&
            jq -e --arg expected "${expected}" \
                '.home_domain == $expected' <<<"${account}" >/dev/null 2>&1
        then
            domain_matches=true
            break
        fi
        sleep 1
    done
    [[ "${domain_matches}" == "true" ]] ||
        die "BLNT issuer home domain does not match ${expected}"
}

verify_locked_blnt_issuer() {
    local issuer="$1" home_domain="$2" account issuer_locked=false
    for _ in {1..30}; do
        if account="$(capture "query-locked-blnt-issuer" \
            curl --fail --silent --show-error --max-time 10 \
            "${HORIZON_URL}/accounts/${issuer}")" &&
            jq -e --arg issuer "${issuer}" \
            --arg home_domain "${home_domain}" \
            --argjson threshold "${BLNT_ISSUER_THRESHOLD}" '
              .account_id == $issuer and
              .thresholds.low_threshold == $threshold and
              .thresholds.med_threshold == $threshold and
              .thresholds.high_threshold == $threshold and
              (.signers | length) == 1 and
              .signers[0].key == $issuer and
              .signers[0].weight == 0 and
              .home_domain == $home_domain and
              .flags.auth_required == false and
              .flags.auth_revocable == false and
              .flags.auth_immutable == false and
              .flags.auth_clawback_enabled == false
            ' <<<"${account}" >/dev/null 2>&1
        then
            issuer_locked=true
            break
        fi
        sleep 1
    done
    [[ "${issuer_locked}" == "true" ]] ||
        die "BLNT issuer account is not irreversibly locked"
}

verify_comet() {
    local comet="$1" controller="$2" blnt="$3" usdc="$4"
    local tokens blnt_weight usdc_weight total_supply blnt_balance usdc_balance
    local blnt_decimals usdc_decimals comet_decimals
    local controller_account controller_locked=false
    [[ "${comet}" != "${blnt}" && "${comet}" != "${usdc}" && "${blnt}" != "${usdc}" ]] ||
        die "Comet, BLNT, and USDC addresses must be distinct"
    blnt_decimals="$(normalize_scalar "$(invoke_view \
        "query-blnt-decimals" "${blnt}" decimals)")"
    usdc_decimals="$(normalize_scalar "$(invoke_view \
        "query-usdc-decimals" "${usdc}" decimals)")"
    comet_decimals="$(normalize_scalar "$(invoke_view \
        "query-comet-decimals" "${comet}" decimals)")"
    assert_equal "7" "${blnt_decimals}" "BLNT decimals"
    assert_equal "7" "${usdc_decimals}" "USDC decimals"
    assert_equal "7" "${comet_decimals}" "Comet LP decimals"
    tokens="$(invoke_view "query-comet-tokens" "${comet}" get_tokens)"
    printf '%s' "${tokens}" | jq -e \
        --arg blnt "${blnt}" --arg usdc "${usdc}" '. == [$blnt, $usdc]' >/dev/null ||
        die "Comet token pair is not [BLNT, USDC]"
    blnt_weight="$(normalize_scalar "$(invoke_view \
        "query-comet-blnt-weight" "${comet}" get_normalized_weight --token "${blnt}")")"
    usdc_weight="$(normalize_scalar "$(invoke_view \
        "query-comet-usdc-weight" "${comet}" get_normalized_weight --token "${usdc}")")"
    assert_equal "${COMET_BLNT_WEIGHT}" "${blnt_weight}" "Comet BLNT weight"
    assert_equal "${COMET_USDC_WEIGHT}" "${usdc_weight}" "Comet USDC weight"
    assert_equal "${controller}" "$(normalize_scalar "$(invoke_view \
        "query-comet-controller" "${comet}" get_controller)")" "Comet controller"
    total_supply="$(normalize_scalar "$(invoke_view \
        "query-comet-total-supply" "${comet}" get_total_supply)")"
    blnt_balance="$(normalize_scalar "$(invoke_view \
        "query-comet-blnt-balance" "${comet}" get_balance --token "${blnt}")")"
    usdc_balance="$(normalize_scalar "$(invoke_view \
        "query-comet-usdc-balance" "${comet}" get_balance --token "${usdc}")")"
    [[ "${total_supply}" =~ ^[1-9][0-9]*$ ]] || die "Comet LP supply is not positive"
    [[ "${blnt_balance}" =~ ^[1-9][0-9]*$ ]] || die "Comet BLNT reserve is not positive"
    [[ "${usdc_balance}" =~ ^[1-9][0-9]*$ ]] || die "Comet USDC reserve is not positive"
    verify_non_clawbackable_sac_balance \
        "verify-comet-blnt-custody" "${blnt}" "${comet}"
    verify_non_clawbackable_sac_balance \
        "verify-comet-usdc-custody" "${usdc}" "${comet}"

    for _ in {1..30}; do
        if controller_account="$(capture "query-comet-controller-account" \
            curl --fail --silent --show-error --max-time 10 \
            "${HORIZON_URL}/accounts/${controller}")" &&
            jq -e --arg controller "${controller}" \
            --argjson threshold "${COMET_CONTROLLER_THRESHOLD}" '
              .thresholds.low_threshold == $threshold and
              .thresholds.med_threshold == $threshold and
              .thresholds.high_threshold == $threshold and
              (.signers | length) == 1 and
              .signers[0].key == $controller and
              .signers[0].weight == 0
            ' <<<"${controller_account}" >/dev/null 2>&1
        then
            controller_locked=true
            break
        fi
        sleep 1
    done
    [[ "${controller_locked}" == "true" ]] ||
        die "Comet controller account is not irreversibly locked"
}

verify_deployment() {
    local legacy_blnd blnt blnt_issuer usdc emitter backfill comet backstop
    local backfill_balance total_allocated backfill_allocated grants remaining
    legacy_blnd="$(state_value legacy_blnd_token)"
    blnt="$(state_value blnt_token)"
    blnt_issuer="$(state_value blnt_issuer)"
    usdc="$(state_value usdc_token)"
    emitter="$(state_value emitter)"
    backfill="$(state_value backfill)"
    comet="$(state_value comet_blnt_usdc)"
    backstop="$(state_value backstop)"

    verify_locked_blnt_issuer "${blnt_issuer}" "$(state_value blnt_home_domain)"
    verify_comet "${comet}" "$(state_value comet_controller)" "${blnt}" "${usdc}"
    assert_equal "${emitter}" "$(normalize_scalar "$(invoke_view \
        "query-blnt-admin" "${blnt}" admin)")" "BLNT administrator"
    assert_equal "${backstop}" "$(normalize_scalar "$(invoke_view \
        "query-emitter-backstop" "${emitter}" get_backstop)")" "emitter backstop"
    assert_equal "${comet}" "$(normalize_scalar "$(invoke_view \
        "query-backstop-token" "${backstop}" backstop_token)")" "backstop LP token"
    assert_equal "${legacy_blnd}" "$(normalize_scalar "$(invoke_view \
        "query-backfill-legacy-token" "${backfill}" get_legacy_blnd_token)")" \
        "backfill legacy BLND binding"
    assert_equal "${blnt}" "$(normalize_scalar "$(invoke_view \
        "query-backfill-blnt-token" "${backfill}" get_blnt_token)")" \
        "backfill BLNT binding"

    backfill_balance="$(normalize_scalar "$(invoke_view \
        "query-backfill-balance" "${blnt}" balance --id "${backfill}")")"
    total_allocated="$(normalize_scalar "$(invoke_view \
        "query-total-allocated" "${backfill}" get_total_allocated)")"
    backfill_allocated="$(normalize_scalar "$(invoke_view \
        "query-backfill-allocated" "${backfill}" get_backfill_allocated)")"
    grants="$(normalize_scalar "$(invoke_view \
        "query-grant-allocated" "${backfill}" get_grant_allocated)")"
    remaining="$(normalize_scalar "$(invoke_view \
        "query-swap-capacity" "${backfill}" get_remaining_swap_capacity)")"
    assert_equal "${BACKFILL_PREMINT}" "${backfill_balance}" "backfill BLNT custody"
    assert_equal "${BACKFILL_ALLOCATION}" "${total_allocated}" "total claim allocation"
    assert_equal "${BACKFILL_ALLOCATION}" "${backfill_allocated}" "backfill allocation"
    assert_equal "${GRANT_ALLOCATION}" "${grants}" "contributor grant allocation"
    assert_equal "${SWAP_CAPACITY}" "${remaining}" "conversion reserve"
}

command_plan() {
    local legacy_description metadata_description
    validate_blnt_home_domain
    if [[ "${NETWORK_MODE}" == "local" ]]; then
        legacy_description="deploy an isolated seven-decimal BLND fixture"
    else
        legacy_description="bind external legacy BLND ${EXTERNAL_BLND} read-only"
    fi
    if [[ -n "${BLNT_HOME_DOMAIN}" ]]; then
        metadata_description="Set the BLNT issuer home domain to ${BLNT_HOME_DOMAIN}"
    else
        metadata_description="Leave the optional BLNT issuer home domain empty"
    fi
    cat <<EOF
Blend v2.1 ${NETWORK_LABEL} deployment

  1. Validate the committed 434-recipient / 74-million-BLNT manifest, fetch and
     hash-check the official V2.0.0 release WASMs, build backfill and Comet v1.1
     with their pinned toolchains, and verify the committed V1 emitter WASM.
  2. Create BLNT from a dedicated issuer.
     ${metadata_description}.
     Create a USDC fixture from the operator and ${legacy_description}.
  3. Deploy the BLNT backfill contract with the committed claim list and []
     contributor grants, then premint exactly 125,000,000 BLNT to it while the
     issuer still controls BLNT (74,000,000 claims + 0 grants + 51,000,000
     conversion reserve).
  4. Deploy and initialize one 80:20 BLNT:USDC Comet v1.1 LP, then permanently
     lock its controller account.
  5. Predict the backstop address, bind the upstream V2 factory and unchanged V1
     emitter to it, immediately invoke its legacy initialization entry point,
     and transfer BLNT administration to it.
  6. Deploy the unchanged backstop with an empty legacy drop list and initialize
     its emissions checkpoint, then irreversibly lock the dedicated BLNT issuer
     at mainnet BLND's 88/88/88 thresholds with signer weight zero.
  7. Verify every token, LP, authority, allocation, and custody binding and save
     transaction evidence under ${WORK_DIR}.

The plan, validation, and status commands submit no transactions.
EOF
}

command_validate() {
    validate_blnt_home_domain
    validate_build_tools
    validate_manifest
    build_artifacts
    validate_artifacts
    note "Validated v2.1, zero-grant backfill, and Comet v1.1 artifacts."
}

command_start() {
    validate_runtime_tools
    mkdir -p "${CONFIG_DIR}"
    if [[ "${NETWORK_MODE}" == "testnet" ]]; then
        require_network
        note "${NETWORK_LABEL} RPC is healthy at ${RPC_URL}."
        return
    fi
    require_docker
    network_healthy && die "a network already responds at ${RPC_URL}; refusing to replace it"
    note "Starting ${CONTAINER_NAME} at Protocol 27 with testnet limits..."
    stellar_cli container start local \
        --docker-host "${DOCKER_HOST_URI}" \
        --name "${CONTAINER_NAME}" \
        --limits testnet \
        --protocol-version 27 \
        --ports-mapping "${RPC_PORT}:8000"
    require_network
}

command_deploy() {
    local skip_build="${1:-false}"
    local operator blnt_issuer controller legacy_blnd blnt usdc emitter backfill comet
    local pool_hash backstop factory deployed_backstop

    validate_blnt_home_domain
    validate_build_tools
    validate_manifest
    require_network
    [[ ! -e "${STATE_FILE}" ]] ||
        die "state already exists at ${STATE_FILE}; refusing to overwrite it"
    if [[ "${skip_build}" != "true" ]]; then
        build_artifacts
    fi
    validate_artifacts

    mkdir -p "${CONFIG_DIR}"
    operator="$(ensure_identity "${OPERATOR_IDENTITY}")"
    blnt_issuer="$(ensure_identity "${BLNT_ISSUER_IDENTITY}")"
    controller="$(ensure_identity "${CONTROLLER_IDENTITY}")"
    fund_and_wait_for_account "${operator}"
    fund_and_wait_for_account "${blnt_issuer}"
    fund_and_wait_for_account "${controller}"
    [[ "${operator}" != "${blnt_issuer}" && \
        "${operator}" != "${controller}" && \
        "${blnt_issuer}" != "${controller}" ]] ||
        die "operator, BLNT issuer, and Comet controller must be distinct accounts"
    new_run_dir
    require_clean_blnt_issuer "${blnt_issuer}"
    initialize_state "${operator}" "${blnt_issuer}" "${controller}"
    if [[ -n "${BLNT_HOME_DOMAIN}" ]]; then
        capture "set-blnt-issuer-home-domain" stellar_cli tx new set-options \
            --source-account "${BLNT_ISSUER_IDENTITY}" \
            --home-domain "${BLNT_HOME_DOMAIN}" \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
        verify_blnt_issuer_home_domain "${blnt_issuer}" "${BLNT_HOME_DOMAIN}"
    fi
    state_set "blnt_home_domain" "${BLNT_HOME_DOMAIN}"

    state_set "manifest_sha256" "$(sha256_file "${BACKFILL_MANIFEST}")"
    state_set "v1_emitter_wasm_sha256" "$(sha256_file "${V1_EMITTER_WASM}")"
    state_set "v2_factory_wasm_sha256" "$(sha256_file "${V2_FACTORY_WASM}")"
    state_set "v2_factory_release" "${V2_FACTORY_RELEASE}"
    state_set "v2_backstop_wasm_sha256" "$(sha256_file "${V2_BACKSTOP_WASM}")"
    state_set "v2_backstop_release" "${V2_BACKSTOP_RELEASE}"
    state_set "v2_pool_wasm_sha256" "$(sha256_file "${V2_POOL_WASM}")"
    state_set "v2_pool_release" "${V2_POOL_RELEASE}"
    state_set "backfill_wasm_sha256" "$(sha256_file "${BACKFILL_WASM}")"
    state_set "comet_v11_wasm_sha256" "$(sha256_file "${COMET_WASM}")"
    state_set "backfill_claim_allocation" "${BACKFILL_ALLOCATION}"
    state_set "contributor_grant_allocation" "${GRANT_ALLOCATION}"
    state_set "conversion_capacity" "${SWAP_CAPACITY}"
    state_set "backfill_premint" "${BACKFILL_PREMINT}"

    if [[ "${NETWORK_MODE}" == "local" ]]; then
        legacy_blnd="$(deploy_asset "deploy-legacy-blnd" BLND "${operator}")"
    else
        legacy_blnd="${EXTERNAL_BLND}"
        require_contract_id "${legacy_blnd}" "external legacy BLND"
        assert_equal "7" "$(normalize_scalar "$(invoke_view \
            "query-external-blnd-decimals" "${legacy_blnd}" decimals)")" \
            "external legacy BLND decimals"
    fi
    blnt="$(deploy_asset "deploy-blnt" BLNT "${blnt_issuer}")"
    usdc="$(deploy_asset "deploy-usdc" USDC "${operator}")"
    state_set "legacy_blnd_token" "${legacy_blnd}"
    state_set "blnt_token" "${blnt}"
    state_set "usdc_token" "${usdc}"

    create_trustline "trust-controller-blnt" \
        "${CONTROLLER_IDENTITY}" "BLNT:${blnt_issuer}"
    create_trustline "trust-controller-usdc" \
        "${CONTROLLER_IDENTITY}" "USDC:${operator}"

    backfill="$(deploy_wasm "deploy-backfill" "${BACKFILL_WASM}" "" \
        --legacy_blnd_token "${legacy_blnd}" \
        --blnt_token "${blnt}" \
        --claim_list "${CLAIM_LIST}" \
        --grant_list '[]')"
    comet="$(deploy_wasm "deploy-comet-v11" "${COMET_WASM}" "")"
    state_set "backfill" "${backfill}"
    state_set "comet_blnt_usdc" "${comet}"

    invoke_transaction_as "premint-backfill-blnt" "${BLNT_ISSUER_IDENTITY}" \
        "${blnt}" mint \
        --to "${backfill}" --amount "${BACKFILL_PREMINT}" >/dev/null
    invoke_transaction_as "mint-comet-blnt" "${BLNT_ISSUER_IDENTITY}" \
        "${blnt}" mint \
        --to "${controller}" --amount "${COMET_BLNT_BALANCE}" >/dev/null
    invoke_transaction "mint-comet-usdc" "${usdc}" mint \
        --to "${controller}" --amount "${COMET_USDC_BALANCE}" >/dev/null
    invoke_transaction_as "initialize-comet-v11" "${CONTROLLER_IDENTITY}" \
        "${comet}" init \
        --controller "${controller}" \
        --tokens "[\"${blnt}\",\"${usdc}\"]" \
        --weights "[\"${COMET_BLNT_WEIGHT}\",\"${COMET_USDC_WEIGHT}\"]" \
        --balances "[\"${COMET_BLNT_BALANCE}\",\"${COMET_USDC_BALANCE}\"]" \
        --swap_fee "${COMET_SWAP_FEE}" >/dev/null
    capture "lock-comet-controller" stellar_cli tx new set-options \
        --source-account "${CONTROLLER_IDENTITY}" \
        --low-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --med-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --high-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --master-weight 0 \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null

    pool_hash="$(upload_wasm "upload-v2-pool" "${V2_POOL_WASM}")"
    backstop="$(predict_contract_id "predict-v21-backstop" "${BACKSTOP_SALT}")"
    require_contract_id "${backstop}" "predicted backstop"
    factory="$(deploy_wasm "deploy-v2-pool-factory" "${V2_FACTORY_WASM}" "" \
        --pool_init_meta \
        "{\"backstop\":\"${backstop}\",\"blnd_id\":\"${blnt}\",\"pool_hash\":\"${pool_hash}\"}")"
    state_set "pool_wasm_hash" "${pool_hash}"
    state_set "pool_factory" "${factory}"
    state_set "backstop" "${backstop}"

    emitter="$(deploy_wasm "deploy-v1-emitter" "${V1_EMITTER_WASM}" "")"
    state_set "emitter" "${emitter}"
    invoke_transaction "initialize-emitter" "${emitter}" initialize \
        --blnd_token "${blnt}" \
        --backstop "${backstop}" \
        --backstop_token "${comet}" >/dev/null
    invoke_transaction_as "set-emitter-as-blnt-admin" "${BLNT_ISSUER_IDENTITY}" \
        "${blnt}" set_admin \
        --new_admin "${emitter}" >/dev/null
    assert_equal "${emitter}" "$(normalize_scalar "$(invoke_view \
        "verify-blnt-admin-before-issuer-lock" "${blnt}" admin)")" \
        "BLNT administrator before issuer lock"
    deployed_backstop="$(deploy_wasm "deploy-v2-backstop" \
        "${V2_BACKSTOP_WASM}" "${BACKSTOP_SALT}" \
        --backstop_token "${comet}" \
        --emitter "${emitter}" \
        --blnd_token "${blnt}" \
        --usdc_token "${usdc}" \
        --pool_factory "${factory}" \
        --drop_list '[]')"
    assert_equal "${backstop}" "${deployed_backstop}" "predicted backstop address"

    invoke_transaction "initialize-backstop-emissions" \
        "${backstop}" distribute >/dev/null
    capture "lock-blnt-issuer" stellar_cli tx new set-options \
        --source-account "${BLNT_ISSUER_IDENTITY}" \
        --low-threshold "${BLNT_ISSUER_THRESHOLD}" \
        --med-threshold "${BLNT_ISSUER_THRESHOLD}" \
        --high-threshold "${BLNT_ISSUER_THRESHOLD}" \
        --master-weight 0 \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
    verify_deployment
    state_set "phase" "verified"
    state_set "verified_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    stellar_cli ledger latest \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --output json-formatted >"${RUN_DIR}/ledger-after-deploy.json"
    note "Blend v2.1 deployment verified. State: ${STATE_FILE}"
}

command_status() {
    validate_runtime_tools
    require_network
    load_state
    verify_deployment
    jq '{network_label, phase, verified_at, operator, blnt_issuer,
         blnt_issuer_threshold, blnt_home_domain, comet_controller,
         legacy_blnd_token, blnt_token, usdc_token, emitter, backfill,
         comet_blnt_usdc, pool_factory, backstop, backfill_premint,
         backfill_claim_allocation, contributor_grant_allocation,
         conversion_capacity}' "${STATE_FILE}"
}

command_stop() {
    validate_runtime_tools
    [[ "${NETWORK_MODE}" == "local" ]] || die "stop is localnet-only"
    require_docker
    note "Stopping ephemeral container ${CONTAINER_NAME}."
    stellar_cli container stop --docker-host "${DOCKER_HOST_URI}" "${CONTAINER_NAME}"
}

command_run() {
    command_validate
    command_start
    command_deploy true
    command_status
}

main() {
    case "${1:-}" in
        plan) command_plan ;;
        validate) command_validate ;;
        start) command_start ;;
        deploy) command_deploy ;;
        run) command_run ;;
        status) command_status ;;
        stop) command_stop ;;
        -h|--help|help) usage ;;
        *) usage >&2; exit 2 ;;
    esac
}

main "$@"
