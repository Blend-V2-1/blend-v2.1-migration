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
EXTERNAL_BLND_ISSUER="${BLEND_V21_EXTERNAL_BLND_ISSUER:-GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56}"
BLNT_HOME_DOMAIN="${BLEND_BLNT_HOME_DOMAIN:-}"
FUNDING_WALLET="${BLEND_V21_FUNDING_WALLET:-GDPAIYJ2FISB5H7JNWDNRERAIMGZSP4HVQKYMKO42KRB23GANJXNG2ZI}"
WALLET_CONFIG_DIR="${BLEND_V21_WALLET_CONFIG_DIR:-${ROOT_DIR}/../blnt-v3-migration/.testnet-production/stellar-config}"
WALLET_IDENTITY="${BLEND_V21_WALLET_IDENTITY:-blend-v3-ui-testnet-wallet}"

SCALAR_7=10000000
BACKFILL_ALLOCATION=$((74000000 * SCALAR_7))
GRANT_ALLOCATION=0
SWAP_CAPACITY=$((51000000 * SCALAR_7))
BACKFILL_PREMINT=$((125000000 * SCALAR_7))
COMET_BLNT_BALANCE=$((600 * SCALAR_7))
COMET_USDC_BALANCE=$((6 * SCALAR_7))
COMET_INITIAL_LP_SUPPLY=$((100 * SCALAR_7))
COMET_LIQUIDITY_BLNT_FUNDING=$((999996 * SCALAR_7))
COMET_LIQUIDITY_USDC_FUNDING=$((9999 * SCALAR_7 + 9600000))
COMET_ADDITIONAL_LP_SUPPLY=$((166666 * SCALAR_7))
COMET_BACKSTOP_LP_SUPPLY=$((166766 * SCALAR_7))
COMET_FINAL_BLNT_BALANCE=$((COMET_BLNT_BALANCE + COMET_LIQUIDITY_BLNT_FUNDING))
COMET_FINAL_USDC_BALANCE=$((COMET_USDC_BALANCE + COMET_LIQUIDITY_USDC_FUNDING))
COMET_BLNT_WEIGHT=8000000
COMET_USDC_WEIGHT=2000000
COMET_SWAP_FEE=30000
COMET_CONTROLLER_THRESHOLD=100
BLNT_ISSUER_THRESHOLD=88
WALLET_BLNT_FUNDING=$((1000000 * SCALAR_7))
WALLET_USDC_FUNDING=$((1000000 * SCALAR_7))
WALLET_EURC_FUNDING=$((1000000 * SCALAR_7))
WALLET_XLM_FUNDING=$((100000 * SCALAR_7))
FIXED_POOL_USDC_SUPPLY=$((1000 * SCALAR_7))
FIXTURE_ORACLE_RESOLUTION=300
FIXTURE_ORACLE_RECORDS=7
BACKSTOP_SALT="${BLEND_V21_BACKSTOP_SALT:-0000000000000000000000000000000000000000000000000000000000000021}"
FIXED_POOL_SALT="${BLEND_V21_FIXED_POOL_SALT:-000000000000000000000000000000000000000000000000000000000000f121}"

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
ORACLE_DIR="${ROOT_DIR}/test-sep40-oracle"
ORACLE_WASM="${ORACLE_DIR}/target/wasm32v1-none/optimized/blend_v21_test_sep40_oracle.wasm"
ORACLE_WASM_SHA256="d60558a660250bc6c1dc318c0e0f4e0d1ec42ab84341c92d465a0bb378daf262"
FIXED_POOL_FIXTURE="${ROOT_DIR}/fixtures/fixed-pool-v2.json"
FIXED_POOL_FIXTURE_SHA256="39892a921f997390b7b401b3ba5686bb4e1ce982312869154bc11ab02cb7fd28"
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
  resume    Resume the recorded deployment without repeating completed funding.
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

validate_fixed_pool_fixture() {
    [[ -s "${FIXED_POOL_FIXTURE}" ]] ||
        die "Fixed Pool V2 fixture is missing: ${FIXED_POOL_FIXTURE}"
    jq -e '
      .source.mainnet_pool == "CAJJZSGMMM3PD7N33TAPHGBUGTB43OC73HVIK2L2G6BNGGGYOSSYBXBD" and
      .prices == {XLM: 2500000, USDC: 10000000, EURC: 10000000} and
      .pool.name == "Fixed" and
      .pool.backstop_take_rate == 2000000 and
      .pool.max_positions == 6 and
      .pool.min_collateral == 50000000 and
      ([.pool.reserves[].asset] == ["XLM", "USDC", "EURC"]) and
      (.pool.reserves | length == 3) and
      .pool.emissions == [
        {res_index: 0, res_type: 1, share: 2000000},
        {res_index: 1, res_type: 0, share: 4000000},
        {res_index: 2, res_type: 0, share: 4000000}
      ]
    ' "${FIXED_POOL_FIXTURE}" >/dev/null ||
        die "Fixed Pool V2 fixture failed invariant validation"
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
        "${COMET_WASM}" \
        "${ORACLE_WASM}"
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
    assert_equal "${ORACLE_WASM_SHA256}" "$(sha256_file "${ORACLE_WASM}")" \
        "designated test SEP-40 oracle WASM hash"
    assert_equal "${FIXED_POOL_FIXTURE_SHA256}" \
        "$(sha256_file "${FIXED_POOL_FIXTURE}")" \
        "designated Fixed Pool V2 fixture hash"
    validate_fixed_pool_fixture
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
        --arg blnt_home_domain "${BLNT_HOME_DOMAIN}" \
        --arg comet_controller "${controller}" \
        --argjson blnt_issuer_threshold "${BLNT_ISSUER_THRESHOLD}" \
        --arg run_dir "${RUN_DIR}" \
        --arg root_commit "$(git -C "${ROOT_DIR}" rev-parse HEAD)" \
        --arg v1_commit "$(git -C "${V1_DIR}" rev-parse HEAD)" \
        --arg v2_commit "$(git -C "${V2_DIR}" rev-parse HEAD)" \
        --arg backfill_commit "$(git -C "${BACKFILL_DIR}" rev-parse HEAD)" \
        --arg comet_commit "$(git -C "${COMET_DIR}" rev-parse HEAD)" \
        --arg root_dirty "$(git -C "${ROOT_DIR}" status --porcelain=v1)" \
        --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          network_mode: $network_mode,
          network_label: $network_label,
          network_passphrase: $network_passphrase,
          rpc_url: $rpc_url,
          operator: $operator,
          blnt_issuer: $blnt_issuer,
          blnt_issuer_threshold: $blnt_issuer_threshold,
          blnt_home_domain: $blnt_home_domain,
          comet_controller: $comet_controller,
          run_dir: $run_dir,
          source: {
            migration: $root_commit,
            migration_dirty: ($root_dirty != ""),
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

state_optional() {
    jq -er --arg key "$1" '.[$key] // empty' "${STATE_FILE}" 2>/dev/null || true
}

state_has() {
    jq -e --arg key "$1" 'has($key)' "${STATE_FILE}" >/dev/null 2>&1
}

state_set() {
    local key="$1" value="$2" temporary="${STATE_FILE}.tmp"
    jq --arg key "${key}" --arg value "${value}" '.[$key] = $value' \
        "${STATE_FILE}" >"${temporary}"
    mv "${temporary}" "${STATE_FILE}"
}

state_record() {
    local key="$1" expected="$2" recorded
    recorded="$(state_optional "${key}")"
    if [[ -z "${recorded}" ]]; then
        state_set "${key}" "${expected}"
    else
        assert_equal "${expected}" "${recorded}" "saved ${key}"
    fi
}

record_deployment_inputs() {
    state_record "manifest_sha256" "$(sha256_file "${BACKFILL_MANIFEST}")"
    state_record "v1_emitter_wasm_sha256" "$(sha256_file "${V1_EMITTER_WASM}")"
    state_record "v2_factory_wasm_sha256" "$(sha256_file "${V2_FACTORY_WASM}")"
    state_record "v2_factory_release" "${V2_FACTORY_RELEASE}"
    state_record "v2_backstop_wasm_sha256" "$(sha256_file "${V2_BACKSTOP_WASM}")"
    state_record "v2_backstop_release" "${V2_BACKSTOP_RELEASE}"
    state_record "v2_pool_wasm_sha256" "$(sha256_file "${V2_POOL_WASM}")"
    state_record "v2_pool_release" "${V2_POOL_RELEASE}"
    state_record "backfill_wasm_sha256" "$(sha256_file "${BACKFILL_WASM}")"
    state_record "comet_v11_wasm_sha256" "$(sha256_file "${COMET_WASM}")"
    state_record "fixed_oracle_wasm_sha256" "$(sha256_file "${ORACLE_WASM}")"
    state_record "fixed_pool_fixture_sha256" "$(sha256_file "${FIXED_POOL_FIXTURE}")"
    state_record "backfill_claim_allocation" "${BACKFILL_ALLOCATION}"
    state_record "contributor_grant_allocation" "${GRANT_ALLOCATION}"
    state_record "conversion_capacity" "${SWAP_CAPACITY}"
    state_record "backfill_premint" "${BACKFILL_PREMINT}"
    state_record "comet_initial_blnt" "${COMET_BLNT_BALANCE}"
    state_record "comet_initial_usdc" "${COMET_USDC_BALANCE}"
    state_record "comet_initial_lp_supply" "${COMET_INITIAL_LP_SUPPLY}"
    state_record "comet_liquidity_blnt_funding" \
        "${COMET_LIQUIDITY_BLNT_FUNDING}"
    state_record "comet_liquidity_usdc_funding" \
        "${COMET_LIQUIDITY_USDC_FUNDING}"
    state_record "comet_additional_lp_supply" "${COMET_ADDITIONAL_LP_SUPPLY}"
    state_record "comet_backstop_lp_supply" "${COMET_BACKSTOP_LP_SUPPLY}"
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

capture_combined() {
    local label="$1" output_file status suffix=2
    shift
    output_file="${RUN_DIR}/${label}.log"
    while [[ -e "${output_file}" ]]; do
        output_file="${RUN_DIR}/${label}-${suffix}.log"
        suffix=$((suffix + 1))
    done
    note "Executing ${label}..."
    if "$@" >"${output_file}" 2>&1; then
        status=0
    else
        status=$?
    fi
    cat "${output_file}"
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

resolve_asset() {
    local label="$1" asset="$2" raw contract_id
    raw="$(capture "${label}" stellar_cli contract id asset \
        --asset "${asset}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}")"
    contract_id="$(normalize_scalar "${raw}")"
    require_contract_id "${contract_id}" "${label}"
    printf '%s\n' "${contract_id}"
}

ensure_asset() {
    local label="$1" code="$2" issuer="$3" expected deployed
    expected="$(resolve_asset "resolve-${label}" "${code}:${issuer}")"
    if invoke_view "probe-${label}" "${expected}" decimals >/dev/null 2>&1; then
        deployed="${expected}"
    else
        deployed="$(deploy_asset "deploy-${label}" "${code}" "${issuer}")"
    fi
    assert_equal "${expected}" "${deployed}" "${label} SAC address"
    assert_equal "7" "$(normalize_scalar "$(invoke_view \
        "verify-${label}-decimals" "${deployed}" decimals)")" "${label} decimals"
    assert_equal "${code}" "$(normalize_scalar "$(invoke_view \
        "verify-${label}-symbol" "${deployed}" symbol)")" "${label} symbol"
    printf '%s\n' "${deployed}"
}

create_trustline() {
    local label="$1" identity="$2" asset="$3"
    capture "${label}" stellar_cli tx new change-trust \
        --source-account "${identity}" \
        --line "${asset}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
}

wallet_stellar_cli() {
    "${DEPLOY_STELLAR}" --config-dir "${WALLET_CONFIG_DIR}" "$@"
}

require_funding_wallet_access() {
    local configured_wallet
    [[ "${NETWORK_MODE}" == "testnet" ]] || return
    [[ -d "${WALLET_CONFIG_DIR}" ]] ||
        die "wallet Stellar config directory not found: ${WALLET_CONFIG_DIR}"
    configured_wallet="$(wallet_stellar_cli keys public-key "${WALLET_IDENTITY}")" ||
        die "wallet identity is unavailable: ${WALLET_IDENTITY}"
    assert_equal "${FUNDING_WALLET}" "${configured_wallet}" \
        "configured funding-wallet identity"
}

create_wallet_trustline() {
    local label="$1" asset="$2"
    capture "${label}" wallet_stellar_cli tx new change-trust \
        --source-account "${WALLET_IDENTITY}" \
        --line "${asset}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
}

ensure_wallet_trustline() {
    local label="$1" code="$2" issuer="$3" account
    account="$(capture "query-wallet-${label}-trustline" \
        curl --fail --silent --show-error --max-time 10 \
        "${HORIZON_URL}/accounts/${FUNDING_WALLET}")"
    if printf '%s' "${account}" | jq -e \
        --arg code "${code}" --arg issuer "${issuer}" '
          any(.balances[];
            .asset_type != "native" and
            .asset_code == $code and
            .asset_issuer == $issuer)
        ' >/dev/null
    then
        return
    fi
    create_wallet_trustline "trust-wallet-${label}" "${code}:${issuer}"
}

ensure_wallet_token_funding() {
    local label="$1" token="$2" source="$3" expected="$4"
    local state_key recorded balance
    state_key="wallet_${label}_funded"
    recorded="$(state_optional "${state_key}")"
    if [[ -n "${recorded}" ]]; then
        assert_equal "${expected}" "${recorded}" "recorded wallet ${label} funding"
        return
    fi
    balance="$(normalize_scalar "$(invoke_view \
        "query-wallet-${label}-before-funding" "${token}" balance \
        --id "${FUNDING_WALLET}")")"
    if (( balance == 0 )); then
        invoke_transaction_as "fund-wallet-${label}" "${source}" \
            "${token}" mint --to "${FUNDING_WALLET}" --amount "${expected}" \
            >/dev/null
    else
        assert_equal "${expected}" "${balance}" \
            "unrecorded wallet ${label} balance"
    fi
    balance="$(normalize_scalar "$(invoke_view \
        "verify-wallet-${label}-funding" "${token}" balance \
        --id "${FUNDING_WALLET}")")"
    assert_equal "${expected}" "${balance}" "wallet ${label} funding"
    state_set "${state_key}" "${expected}"
}

resolve_native_asset() {
    local label="$1" raw contract_id
    raw="$(capture "${label}" stellar_cli contract id asset \
        --asset native \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}")"
    contract_id="$(normalize_scalar "${raw}")"
    require_contract_id "${contract_id}" "${label}"
    printf '%s\n' "${contract_id}"
}

fund_testnet_wallet_xlm() {
    local donor identity amount index completed total=0 payments
    [[ "${NETWORK_MODE}" == "testnet" ]] || return
    completed="$(state_optional wallet_xlm_donors_completed)"
    completed="${completed:-0}"
    for index in {1..12}; do
        if (( index <= completed )); then
            if (( index < 12 )); then
                total=$((total + 9000 * SCALAR_7))
            else
                total=$((total + 1000 * SCALAR_7))
            fi
            continue
        fi
        identity="blend-v21-testnet-xlm-donor-${index}"
        donor="$(ensure_identity "${identity}")"
        fund_and_wait_for_account "${donor}"
        if (( index < 12 )); then
            amount=$((9000 * SCALAR_7))
        else
            amount=$((1000 * SCALAR_7))
        fi
        payments="$(capture "query-wallet-xlm-${index}-payments" \
            curl --fail --silent --show-error --max-time 10 \
            "${HORIZON_URL}/accounts/${donor}/payments?limit=200&order=desc")"
        if printf '%s' "${payments}" | jq -e \
            --arg donor "${donor}" --arg wallet "${FUNDING_WALLET}" \
            --arg expected "${amount}" '
              def raw:
                split(".") as $parts |
                ((($parts[0] | tonumber) * 10000000) +
                 (((($parts[1] // "") + "0000000")[0:7]) | tonumber) | tostring);
              any(._embedded.records[];
                .type == "payment" and .from == $donor and .to == $wallet and
                .asset_type == "native" and (.amount | raw) == $expected)
            ' >/dev/null
        then
            total=$((total + amount))
            state_set "wallet_xlm_donors_completed" "${index}"
            continue
        fi
        capture "fund-wallet-xlm-${index}" stellar_cli tx new payment \
            --source-account "${identity}" \
            --destination "${FUNDING_WALLET}" \
            --asset native \
            --amount "${amount}" \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
        total=$((total + amount))
        state_set "wallet_xlm_donors_completed" "${index}"
    done
    assert_equal "${WALLET_XLM_FUNDING}" "${total}" "wallet XLM transfer total"
    state_set "wallet_xlm_funded" "${total}"
}

verify_comet_controller_empty() {
    local blnt="$1" usdc="$2" controller="$3"
    assert_equal "0" "$(normalize_scalar "$(invoke_view \
        "verify-controller-blnt-empty" "${blnt}" balance \
        --id "${controller}")")" "controller BLNT balance before lock"
    assert_equal "0" "$(normalize_scalar "$(invoke_view \
        "verify-controller-usdc-empty" "${usdc}" balance \
        --id "${controller}")")" "controller USDC balance before lock"
}

provision_comet_liquidity() {
    local comet="$1" blnt="$2" usdc="$3" controller="$4" operator="$5"
    local controller_lp operator_lp balance

    controller_lp="$(normalize_scalar "$(invoke_view \
        "query-controller-additional-comet-lp" "${comet}" balance \
        --id "${controller}")")"
    operator_lp="$(normalize_scalar "$(invoke_view \
        "query-operator-comet-lp-before-liquidity" "${comet}" balance \
        --id "${operator}")")"

    if (( operator_lp == COMET_BACKSTOP_LP_SUPPLY )); then
        assert_equal "0" "${controller_lp}" "controller Comet LP balance"
        verify_comet_controller_empty "${blnt}" "${usdc}" "${controller}"
        state_set "comet_liquidity_joined" "true"
        state_set "comet_liquidity_transferred" "true"
        return
    fi
    assert_equal "${COMET_INITIAL_LP_SUPPLY}" "${operator_lp}" \
        "operator Comet LP balance before liquidity provision"

    if (( controller_lp == 0 )); then
        balance="$(normalize_scalar "$(invoke_view \
            "query-controller-liquidity-blnt" "${blnt}" balance \
            --id "${controller}")")"
        (( balance <= COMET_LIQUIDITY_BLNT_FUNDING )) ||
            die "controller BLNT exceeds the additional Comet liquidity funding"
        if (( balance < COMET_LIQUIDITY_BLNT_FUNDING )); then
            invoke_transaction_as "mint-comet-liquidity-blnt" \
                "${BLNT_ISSUER_IDENTITY}" "${blnt}" mint \
                --to "${controller}" \
                --amount "$((COMET_LIQUIDITY_BLNT_FUNDING - balance))" >/dev/null
        fi
        balance="$(normalize_scalar "$(invoke_view \
            "query-controller-liquidity-usdc" "${usdc}" balance \
            --id "${controller}")")"
        (( balance <= COMET_LIQUIDITY_USDC_FUNDING )) ||
            die "controller USDC exceeds the additional Comet liquidity funding"
        if (( balance < COMET_LIQUIDITY_USDC_FUNDING )); then
            invoke_transaction "mint-comet-liquidity-usdc" "${usdc}" mint \
                --to "${controller}" \
                --amount "$((COMET_LIQUIDITY_USDC_FUNDING - balance))" >/dev/null
        fi
        state_set "comet_liquidity_funded" "true"
        invoke_transaction_as "join-comet-liquidity" "${CONTROLLER_IDENTITY}" \
            "${comet}" join_pool \
            --pool_amount_out "${COMET_ADDITIONAL_LP_SUPPLY}" \
            --max_amounts_in \
            "[\"${COMET_LIQUIDITY_BLNT_FUNDING}\",\"${COMET_LIQUIDITY_USDC_FUNDING}\"]" \
            --user "${controller}" >/dev/null
        controller_lp="${COMET_ADDITIONAL_LP_SUPPLY}"
    else
        assert_equal "${COMET_ADDITIONAL_LP_SUPPLY}" "${controller_lp}" \
            "existing controller additional Comet LP balance"
    fi
    state_set "comet_liquidity_joined" "true"
    verify_comet_controller_empty "${blnt}" "${usdc}" "${controller}"
    invoke_transaction_as "transfer-additional-comet-lp" \
        "${CONTROLLER_IDENTITY}" "${comet}" transfer \
        --from "${controller}" --to "${operator}" \
        --amount "${COMET_ADDITIONAL_LP_SUPPLY}" >/dev/null
    state_set "comet_liquidity_transferred" "true"
    assert_equal "${COMET_BACKSTOP_LP_SUPPLY}" \
        "$(normalize_scalar "$(invoke_view \
            "verify-operator-comet-lp-after-liquidity" "${comet}" balance \
            --id "${operator}")")" "operator Comet LP balance"
}

fixture_price_series() {
    local price="$1" now newest
    now="$(date +%s)"
    newest=$(((now / FIXTURE_ORACLE_RESOLUTION - 1) * FIXTURE_ORACLE_RESOLUTION))
    jq -nc \
        --arg price "${price}" \
        --argjson newest "${newest}" \
        --argjson resolution "${FIXTURE_ORACLE_RESOLUTION}" \
        --argjson records "${FIXTURE_ORACLE_RECORDS}" \
        '[range(0; $records) | {
          price: $price,
          timestamp: ($newest - (($records - 1 - .) * $resolution))
        }]'
}

fixed_asset_id() {
    case "$1" in
        XLM) state_value xlm_token ;;
        USDC) state_value usdc_token ;;
        EURC) state_value eurc_token ;;
        *) die "unknown Fixed Pool asset: $1" ;;
    esac
}

seed_fixed_oracle() {
    local oracle="$1" asset token price prices label
    for asset in XLM USDC EURC; do
        label="$(printf '%s' "${asset}" | tr '[:upper:]' '[:lower:]')"
        token="$(fixed_asset_id "${asset}")"
        price="$(jq -er --arg asset "${asset}" '.prices[$asset]' \
            "${FIXED_POOL_FIXTURE}")"
        prices="$(fixture_price_series "${price}")"
        if ! invoke_transaction "seed-fixed-oracle-${label}" \
            "${oracle}" set_prices \
            --asset "{\"Stellar\":\"${token}\"}" \
            --prices "${prices}" >/dev/null
        then
            note "Failed to refresh Fixed oracle ${asset} price history."
            return 1
        fi
    done
    state_set "fixed_oracle_refreshed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

fixed_reserve_config() {
    local index="$1"
    jq -c --argjson index "${index}" \
        '.pool.reserves[$index].config + {
          decimals: 7,
          enabled: true,
          index: $index
        }' "${FIXED_POOL_FIXTURE}"
}

deploy_fixed_pool() {
    local factory="$1" backstop="$2" operator="$3"
    local xlm usdc eurc oracle pool raw name take_rate max_positions min_collateral
    local asset token metadata label index=0 status reward_zone positions shares
    local reserve_list available

    xlm="$(state_value xlm_token)"
    usdc="$(state_value usdc_token)"
    eurc="$(state_value eurc_token)"
    oracle="$(state_optional fixed_pool_oracle)"
    if [[ -z "${oracle}" ]]; then
        oracle="$(deploy_wasm "deploy-fixed-v2-oracle" "${ORACLE_WASM}" "" \
            --admin "${operator}" \
            --base '{"Other":"USD"}' \
            --assets "[{\"Stellar\":\"${xlm}\"},{\"Stellar\":\"${usdc}\"},{\"Stellar\":\"${eurc}\"}]" \
            --decimals 7 \
            --resolution "${FIXTURE_ORACLE_RESOLUTION}")"
        state_set "fixed_pool_oracle" "${oracle}"
    fi
    seed_fixed_oracle "${oracle}"

    name="$(jq -er '.pool.name' "${FIXED_POOL_FIXTURE}")"
    take_rate="$(jq -er '.pool.backstop_take_rate' "${FIXED_POOL_FIXTURE}")"
    max_positions="$(jq -er '.pool.max_positions' "${FIXED_POOL_FIXTURE}")"
    min_collateral="$(jq -er '.pool.min_collateral' "${FIXED_POOL_FIXTURE}")"
    pool="$(state_optional fixed_pool)"
    if [[ -z "${pool}" ]]; then
        raw="$(invoke_view "predict-fixed-v2-pool" "${factory}" deploy \
            --admin "${operator}" \
            --name "${name}" \
            --salt "${FIXED_POOL_SALT}" \
            --oracle "${oracle}" \
            --backstop_take_rate "${take_rate}" \
            --max_positions "${max_positions}" \
            --min_collateral "${min_collateral}")"
        pool="$(normalize_scalar "${raw}")"
        require_contract_id "${pool}" "Fixed Pool V2"
        state_set "fixed_pool" "${pool}"
    fi
    if [[ "$(normalize_scalar "$(invoke_view \
        "query-fixed-pool-registration-before-deploy" "${factory}" is_pool \
        --pool_address "${pool}")")" != "true" ]]
    then
        raw="$(invoke_transaction "deploy-fixed-v2-pool" "${factory}" deploy \
            --admin "${operator}" \
            --name "${name}" \
            --salt "${FIXED_POOL_SALT}" \
            --oracle "${oracle}" \
            --backstop_take_rate "${take_rate}" \
            --max_positions "${max_positions}" \
            --min_collateral "${min_collateral}")"
        assert_equal "${pool}" "$(normalize_scalar "${raw}")" \
            "predicted Fixed Pool V2 address"
    fi

    reserve_list="$(invoke_view "query-fixed-reserves-before-configuration" \
        "${pool}" get_reserve_list)"
    for asset in XLM USDC EURC; do
        label="$(printf '%s' "${asset}" | tr '[:upper:]' '[:lower:]')"
        token="$(fixed_asset_id "${asset}")"
        metadata="$(fixed_reserve_config "${index}")"
        if ! printf '%s' "${reserve_list}" | jq -e --arg token "${token}" \
            'index($token) != null' >/dev/null
        then
            if invoke_view "probe-fixed-queued-reserve-${label}" \
                "${pool}" set_reserve --asset "${token}" >/dev/null
            then
                invoke_transaction "resume-fixed-reserve-${label}" \
                    "${pool}" set_reserve --asset "${token}" >/dev/null
            else
                invoke_transaction "queue-fixed-reserve-${label}" \
                    "${pool}" queue_set_reserve \
                    --asset "${token}" --metadata "${metadata}" >/dev/null
                invoke_transaction "set-fixed-reserve-${label}" \
                    "${pool}" set_reserve --asset "${token}" >/dev/null
            fi
            reserve_list="$(invoke_view "query-fixed-reserves-after-${label}" \
                "${pool}" get_reserve_list)"
        fi
        index=$((index + 1))
    done

    status="$(invoke_view "query-fixed-pool-config-before-deposit" \
        "${pool}" get_config | jq -er '.status | tostring')"
    if [[ "${status}" == "6" ]]; then
        invoke_transaction "put-fixed-pool-on-ice" \
            "${pool}" set_status --pool_status 2 >/dev/null
    fi

    shares="$(invoke_view "query-fixed-pool-backstop-before-deposit" \
        "${backstop}" user_balance --pool "${pool}" --user "${operator}" |
        jq -er '.shares | tostring')"
    if (( shares == 0 )); then
        invoke_transaction "deposit-fixed-pool-backstop" \
            "${backstop}" deposit \
            --from "${operator}" \
            --pool_address "${pool}" \
            --amount "${COMET_BACKSTOP_LP_SUPPLY}" >/dev/null
    else
        assert_equal "${COMET_BACKSTOP_LP_SUPPLY}" "${shares}" \
            "existing Fixed Pool backstop shares"
    fi
    status="$(invoke_view "query-fixed-pool-status-before-activation" \
        "${pool}" get_config | jq -er '.status | tostring')"
    if [[ "${status}" != "0" ]]; then
        invoke_transaction "activate-fixed-pool" \
            "${pool}" set_status --pool_status 0 >/dev/null
    fi
    reward_zone="$(invoke_view "query-fixed-reward-zone-before-add" \
        "${backstop}" reward_zone)"
    if ! printf '%s' "${reward_zone}" | jq -e --arg pool "${pool}" \
        'index($pool) != null' >/dev/null
    then
        invoke_transaction "add-fixed-pool-to-reward-zone" \
            "${backstop}" add_reward \
            --to_add "${pool}" --to_remove null >/dev/null
    fi
    invoke_transaction "configure-fixed-pool-emissions" \
        "${pool}" set_emissions_config \
        --res_emission_metadata "$(jq -c '.pool.emissions' "${FIXED_POOL_FIXTURE}")" \
        >/dev/null

    positions="$(invoke_view "query-fixed-pool-usdc-supply-before-seed" \
        "${pool}" get_positions --address "${operator}")"
    shares="$(printf '%s' "${positions}" | jq -er \
        '(.supply["1"] // "0") | tostring')"
    if (( shares == 0 )); then
        available="$(normalize_scalar "$(invoke_view \
            "query-fixed-pool-usdc-available" "${usdc}" balance \
            --id "${operator}")")"
        if (( available < FIXED_POOL_USDC_SUPPLY )); then
            invoke_transaction "mint-fixed-pool-usdc-supply" \
                "${usdc}" mint --to "${operator}" \
                --amount "$((FIXED_POOL_USDC_SUPPLY - available))" >/dev/null
        fi
        invoke_transaction "seed-fixed-pool-usdc-supply" \
            "${pool}" submit \
            --from "${operator}" --spender "${operator}" --to "${operator}" \
            --requests "[{\"address\":\"${usdc}\",\"amount\":\"${FIXED_POOL_USDC_SUPPLY}\",\"request_type\":0}]" \
            >/dev/null
    else
        assert_equal "${FIXED_POOL_USDC_SUPPLY}" "${shares}" \
            "existing Fixed Pool USDC supply"
    fi

    assert_equal "true" "$(normalize_scalar "$(invoke_view \
        "verify-fixed-pool-factory-registration" "${factory}" is_pool \
        --pool_address "${pool}")")" "Fixed Pool factory registration"
    assert_equal "${operator}" "$(normalize_scalar "$(invoke_view \
        "verify-fixed-pool-admin" "${pool}" get_admin)")" "Fixed Pool admin"
    assert_equal "0" "$(invoke_view "verify-fixed-pool-config" \
        "${pool}" get_config | jq -er '.status | tostring')" "Fixed Pool status"
    invoke_view "verify-fixed-pool-config-fields" "${pool}" get_config | jq -e \
        --arg oracle "${oracle}" \
        --argjson take_rate "${take_rate}" \
        --argjson max_positions "${max_positions}" \
        --arg min_collateral "${min_collateral}" '
          .oracle == $oracle and
          .bstop_rate == $take_rate and
          .max_positions == $max_positions and
          (.min_collateral | tostring) == $min_collateral
        ' >/dev/null || die "Fixed Pool config differs from fixture"
    invoke_view "verify-fixed-pool-reserves" "${pool}" get_reserve_list | jq -e \
        --arg xlm "${xlm}" --arg usdc "${usdc}" --arg eurc "${eurc}" \
        '. == [$xlm, $usdc, $eurc]' >/dev/null ||
        die "Fixed Pool reserve order differs from [XLM, USDC, EURC]"
    reward_zone="$(invoke_view "verify-fixed-pool-reward-zone" \
        "${backstop}" reward_zone)"
    printf '%s' "${reward_zone}" | jq -e --arg pool "${pool}" \
        'index($pool) != null' >/dev/null || die "Fixed Pool is absent from reward zone"
    shares="$(invoke_view "verify-fixed-pool-backstop-shares" \
        "${backstop}" user_balance --pool "${pool}" --user "${operator}" |
        jq -er '.shares | tostring')"
    assert_equal "${COMET_BACKSTOP_LP_SUPPLY}" "${shares}" \
        "Fixed Pool backstop shares"
    positions="$(invoke_view "verify-fixed-pool-usdc-supply" \
        "${pool}" get_positions --address "${operator}")"
    assert_equal "${FIXED_POOL_USDC_SUPPLY}" \
        "$(printf '%s' "${positions}" | jq -er '(.supply["1"] // "0") | tostring')" \
        "Fixed Pool USDC supply"
    state_set "fixed_pool_backstop_deposit" "${COMET_BACKSTOP_LP_SUPPLY}"
    state_set "fixed_pool_usdc_supply" "${FIXED_POOL_USDC_SUPPLY}"
    state_set "fixed_pool_emissions" \
        "$(jq -c '.pool.emissions' "${FIXED_POOL_FIXTURE}")"
}

require_external_blnd() {
    local legacy_blnd="$1"
    require_contract_id "${legacy_blnd}" "external legacy BLND"
    assert_equal "7" "$(normalize_scalar "$(invoke_view \
        "query-external-blnd-decimals" "${legacy_blnd}" decimals)")" \
        "external legacy BLND decimals"
    assert_equal "BLND" "$(normalize_scalar "$(invoke_view \
        "query-external-blnd-symbol" "${legacy_blnd}" symbol)")" \
        "external legacy BLND symbol"
}

fund_testnet_wallet_assets() {
    local blnt="$1" blnt_issuer="$2" usdc="$3" eurc="$4"
    [[ "${NETWORK_MODE}" == "testnet" ]] || return
    require_funding_wallet_access
    ensure_wallet_trustline "blnt" BLNT "${blnt_issuer}"
    ensure_wallet_trustline "usdc" USDC "$(state_value operator)"
    ensure_wallet_trustline "eurc" EURC "$(state_value operator)"
    ensure_wallet_token_funding \
        "blnt" "${blnt}" "${BLNT_ISSUER_IDENTITY}" "${WALLET_BLNT_FUNDING}"
    ensure_wallet_token_funding \
        "usdc" "${usdc}" "${OPERATOR_IDENTITY}" "${WALLET_USDC_FUNDING}"
    ensure_wallet_token_funding \
        "eurc" "${eurc}" "${OPERATOR_IDENTITY}" "${WALLET_EURC_FUNDING}"
    state_set "funding_wallet" "${FUNDING_WALLET}"
    fund_testnet_wallet_xlm
}

verify_fixed_pool_deployment() {
    local operator factory backstop oracle pool xlm usdc eurc config reserves reward shares
    local asset token expected reserve prices emissions_raw emissions_actual emissions_expected index=0
    operator="$(state_value operator)"
    factory="$(state_value pool_factory)"
    backstop="$(state_value backstop)"
    oracle="$(state_value fixed_pool_oracle)"
    pool="$(state_value fixed_pool)"
    xlm="$(state_value xlm_token)"
    usdc="$(state_value usdc_token)"
    eurc="$(state_value eurc_token)"
    assert_equal "true" "$(normalize_scalar "$(invoke_view \
        "query-fixed-pool-registration" "${factory}" is_pool \
        --pool_address "${pool}")")" \
        "Fixed Pool factory registration"
    assert_equal "${operator}" "$(normalize_scalar "$(invoke_view \
        "query-fixed-pool-admin" "${pool}" get_admin)")" "Fixed Pool admin"
    config="$(invoke_view "query-fixed-pool-config" "${pool}" get_config)"
    printf '%s' "${config}" | jq -e \
        --arg oracle "${oracle}" \
        --argjson take_rate "$(jq -er '.pool.backstop_take_rate' "${FIXED_POOL_FIXTURE}")" \
        --argjson max_positions "$(jq -er '.pool.max_positions' "${FIXED_POOL_FIXTURE}")" \
        --arg min_collateral "$(jq -er '.pool.min_collateral | tostring' "${FIXED_POOL_FIXTURE}")" '
          .oracle == $oracle and .status == 0 and
          .bstop_rate == $take_rate and .max_positions == $max_positions and
          (.min_collateral | tostring) == $min_collateral
        ' >/dev/null || die "Fixed Pool config differs from the Fixed Pool V2 fixture"
    reserves="$(invoke_view "query-fixed-pool-reserves" "${pool}" get_reserve_list)"
    printf '%s' "${reserves}" | jq -e \
        --arg xlm "${xlm}" --arg usdc "${usdc}" --arg eurc "${eurc}" \
        '. == [$xlm, $usdc, $eurc]' >/dev/null ||
        die "Fixed Pool reserve order differs from [XLM, USDC, EURC]"
    for asset in XLM USDC EURC; do
        token="$(fixed_asset_id "${asset}")"
        expected="$(fixed_reserve_config "${index}")"
        reserve="$(invoke_view "query-fixed-pool-${asset}-reserve" \
            "${pool}" get_reserve --asset "${token}")"
        printf '%s' "${reserve}" | jq -e \
            --arg token "${token}" --argjson expected "${expected}" \
            '.asset == $token and .config == $expected' >/dev/null ||
            die "Fixed Pool ${asset} reserve configuration differs from fixture"
        index=$((index + 1))
    done
    emissions_raw="$(capture "query-fixed-pool-emissions" stellar_cli contract read \
        --id "${pool}" --key PoolEmis --durability persistent --output string \
        --rpc-url "${RPC_URL}" --network-passphrase "${NETWORK_PASSPHRASE}")"
    emissions_actual="${emissions_raw#*,\"}"
    emissions_actual="${emissions_actual%\",*}"
    emissions_actual="${emissions_actual//\"\"/\"}"
    emissions_actual="$(printf '%s' "${emissions_actual}" | jq -cS .)" ||
        die "unable to parse Fixed Pool emissions"
    emissions_expected="$(jq -cS '
      .pool.emissions |
      map({key: ((.res_index * 2 + .res_type) | tostring), value: .share}) |
      from_entries
    ' "${FIXED_POOL_FIXTURE}")"
    assert_equal "${emissions_expected}" "${emissions_actual}" \
        "Fixed Pool emission allocations"
    reward="$(invoke_view "query-fixed-pool-reward-zone" "${backstop}" reward_zone)"
    printf '%s' "${reward}" | jq -e --arg pool "${pool}" \
        'index($pool) != null' >/dev/null || die "Fixed Pool is absent from reward zone"
    shares="$(invoke_view "query-fixed-pool-backstop-balance" \
        "${backstop}" user_balance --pool "${pool}" --user "${operator}" |
        jq -er '.shares | tostring')"
    assert_equal "${COMET_BACKSTOP_LP_SUPPLY}" "${shares}" \
        "Fixed Pool backstop shares"
    assert_equal "${operator}" "$(normalize_scalar "$(invoke_view \
        "query-fixed-oracle-admin" "${oracle}" admin)")" "Fixed oracle admin"
    assert_equal "7" "$(normalize_scalar "$(invoke_view \
        "query-fixed-oracle-decimals" "${oracle}" decimals)")" "Fixed oracle decimals"
    assert_equal "${FIXTURE_ORACLE_RESOLUTION}" "$(normalize_scalar "$(invoke_view \
        "query-fixed-oracle-resolution" "${oracle}" resolution)")" \
        "Fixed oracle resolution"
    invoke_view "query-fixed-oracle-assets" "${oracle}" assets | jq -e \
        --arg xlm "${xlm}" --arg usdc "${usdc}" --arg eurc "${eurc}" \
        '. == [{Stellar:$xlm},{Stellar:$usdc},{Stellar:$eurc}]' >/dev/null ||
        die "Fixed oracle assets differ from [XLM, USDC, EURC]"
    for asset in XLM USDC EURC; do
        token="$(fixed_asset_id "${asset}")"
        expected="$(jq -er --arg asset "${asset}" '.prices[$asset] | tostring' \
            "${FIXED_POOL_FIXTURE}")"
        prices="$(invoke_view "query-fixed-oracle-${asset}-prices" \
            "${oracle}" prices --asset "{\"Stellar\":\"${token}\"}" \
            --records "${FIXTURE_ORACLE_RECORDS}")"
        printf '%s' "${prices}" | jq -e \
            --arg expected "${expected}" \
            --argjson records "${FIXTURE_ORACLE_RECORDS}" '
              length == $records and
              all(.[]; (.price | tostring) == $expected)
            ' >/dev/null || die "Fixed oracle ${asset} history differs from fixture"
    done
}

verify_wallet_funding() {
    local token expected label balance wallet_account xlm_balance
    [[ "${NETWORK_MODE}" == "testnet" ]] || return
    for token_spec in \
        "$(state_value blnt_token):${WALLET_BLNT_FUNDING}:blnt" \
        "$(state_value usdc_token):${WALLET_USDC_FUNDING}:usdc" \
        "$(state_value eurc_token):${WALLET_EURC_FUNDING}:eurc"
    do
        IFS=: read -r token expected label <<<"${token_spec}"
        balance="$(normalize_scalar "$(invoke_view \
            "query-wallet-${label}-funding" "${token}" balance \
            --id "${FUNDING_WALLET}")")"
        assert_equal "${expected}" "${balance}" "wallet ${label} balance"
    done
    wallet_account="$(capture "query-funded-wallet" \
        curl --fail --silent --show-error --max-time 10 \
        "${HORIZON_URL}/accounts/${FUNDING_WALLET}")"
    xlm_balance="$(printf '%s' "${wallet_account}" | jq -er '
      def raw:
        split(".") as $parts |
        (($parts[0] | tonumber) * 10000000) +
        (((($parts[1] // "") + "0000000")[0:7]) | tonumber);
      .balances[] | select(.asset_type == "native") | .balance | raw | tostring
    ')"
    (( xlm_balance >= WALLET_XLM_FUNDING )) ||
        die "wallet native XLM balance is below the requested funding amount"
}

verify_wallet_funding_record() {
    [[ "${NETWORK_MODE}" == "testnet" ]] || return
    assert_equal "${FUNDING_WALLET}" "$(state_value funding_wallet)" \
        "recorded funding wallet"
    assert_equal "${WALLET_BLNT_FUNDING}" "$(state_value wallet_blnt_funded)" \
        "recorded wallet BLNT funding"
    assert_equal "${WALLET_USDC_FUNDING}" "$(state_value wallet_usdc_funded)" \
        "recorded wallet USDC funding"
    assert_equal "${WALLET_EURC_FUNDING}" "$(state_value wallet_eurc_funded)" \
        "recorded wallet EURC funding"
    assert_equal "${WALLET_XLM_FUNDING}" "$(state_value wallet_xlm_funded)" \
        "recorded wallet XLM funding"
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

invoke_probe() {
    local label="$1" contract="$2" function="$3"
    shift 3
    capture_combined "${label}" stellar_cli contract invoke \
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
      (.home_domain // "") == "" and
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
              (.home_domain // "") == $home_domain and
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
    local verify_initial_balances="${5:-true}"
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
    if [[ "${verify_initial_balances}" == "true" ]]; then
        assert_equal "${COMET_BACKSTOP_LP_SUPPLY}" "${total_supply}" "Comet LP supply"
        assert_equal "${COMET_FINAL_BLNT_BALANCE}" "${blnt_balance}" "Comet BLNT reserve"
        assert_equal "${COMET_FINAL_USDC_BALANCE}" "${usdc_balance}" "Comet USDC reserve"
    else
        [[ "${total_supply}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet LP supply is not positive"
        [[ "${blnt_balance}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet BLNT reserve is not positive"
        [[ "${usdc_balance}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet USDC reserve is not positive"
    fi
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
    local verify_initial_balances="${1:-true}"
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

    if [[ "${NETWORK_MODE}" == "testnet" ]]; then
        require_external_blnd "${legacy_blnd}"
    fi
    verify_locked_blnt_issuer "${blnt_issuer}" "$(state_value blnt_home_domain)"
    verify_comet "${comet}" "$(state_value comet_controller)" \
        "${blnt}" "${usdc}" "${verify_initial_balances}"
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
    assert_equal "${BACKFILL_ALLOCATION}" "${total_allocated}" "total claim allocation"
    assert_equal "${BACKFILL_ALLOCATION}" "${backfill_allocated}" "backfill allocation"
    assert_equal "${GRANT_ALLOCATION}" "${grants}" "contributor grant allocation"
    if [[ "${verify_initial_balances}" == "true" ]]; then
        assert_equal "${BACKFILL_PREMINT}" "${backfill_balance}" "backfill BLNT custody"
        assert_equal "${SWAP_CAPACITY}" "${remaining}" "conversion reserve"
    else
        [[ "${backfill_balance}" =~ ^[0-9]+$ ]] ||
            die "backfill BLNT custody is invalid"
        [[ "${remaining}" =~ ^[0-9]+$ ]] ||
            die "remaining conversion capacity is invalid"
        (( backfill_balance <= BACKFILL_PREMINT )) ||
            die "backfill BLNT custody exceeds its initial funding"
        (( remaining <= SWAP_CAPACITY )) ||
            die "remaining conversion capacity exceeds its initial funding"
    fi
    verify_fixed_pool_deployment
    verify_wallet_funding_record
    if [[ "${verify_initial_balances}" == "true" ]]; then
        verify_wallet_funding
    fi
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
     Create USDC and EURC fixtures from the operator and ${legacy_description}.
  3. Deploy the BLNT backfill contract with the committed claim list and []
     contributor grants, then premint exactly 125,000,000 BLNT to it while the
     issuer still controls BLNT (74,000,000 claims + 0 grants + 51,000,000
     conversion reserve).
  4. Initialize one seven-decimal 80:20 BLNT:USDC Comet v1.1 LP with 600 BLNT
     and 6 USDC, establishing 100 LP shares at the intended initial price.
     Mint exactly 999,996 BLNT and 9,999.96 USDC to join proportionally for
     166,666 more shares without changing that price, transfer all 166,766
     shares to the operator, then permanently lock its empty controller account.
  5. Predict the backstop address, bind the upstream V2 factory and unchanged V1
     emitter to it, immediately invoke its legacy initialization entry point,
     and transfer BLNT administration to it.
  6. Deploy the unchanged backstop with an empty legacy drop list and initialize
     its emissions checkpoint. Deploy an authenticated test-only SEP-40 oracle
     and a Fixed Pool modeled on mainnet Fixed Pool V2, deposit all 166,766 LP
     shares, activate it, add it to the reward zone, mirror the mainnet emission
     split, and seed 1,000 USDC of supply.
  7. On testnet, send 1,000,000 each of new BLNT, USDC, and EURC plus exactly
     100,000 native XLM to ${FUNDING_WALLET}.
  8. Irreversibly lock the BLNT issuer at mainnet BLND's 88/88/88 thresholds,
     verify every token, LP, authority, allocation, pool, oracle, funding, and
     custody binding, and save transaction evidence under ${WORK_DIR}.

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
    local operator blnt_issuer controller legacy_blnd legacy_blnd_issuer
    local blnt usdc eurc xlm
    local emitter backfill comet pool_hash backstop factory deployed_backstop

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

    record_deployment_inputs

    if [[ "${NETWORK_MODE}" == "local" ]]; then
        legacy_blnd="$(deploy_asset "deploy-legacy-blnd" BLND "${operator}")"
        legacy_blnd_issuer="${operator}"
    else
        legacy_blnd="${EXTERNAL_BLND}"
        legacy_blnd_issuer="${EXTERNAL_BLND_ISSUER}"
        require_external_blnd "${legacy_blnd}"
    fi
    state_set "legacy_blnd_token" "${legacy_blnd}"
    state_set "legacy_blnd_issuer" "${legacy_blnd_issuer}"
    blnt="$(deploy_asset "deploy-blnt" BLNT "${blnt_issuer}")"
    state_set "blnt_token" "${blnt}"
    usdc="$(deploy_asset "deploy-usdc" USDC "${operator}")"
    state_set "usdc_token" "${usdc}"
    eurc="$(deploy_asset "deploy-eurc" EURC "${operator}")"
    state_set "eurc_token" "${eurc}"
    xlm="$(resolve_native_asset "resolve-native-xlm")"
    state_set "xlm_token" "${xlm}"

    fund_testnet_wallet_assets "${blnt}" "${blnt_issuer}" "${usdc}" "${eurc}"

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
    state_set "backfill_premint_completed" "true"
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
    state_set "comet_initialized" "true"
    invoke_transaction_as "transfer-initial-comet-lp" "${CONTROLLER_IDENTITY}" \
        "${comet}" transfer \
        --from "${controller}" --to "${operator}" \
        --amount "${COMET_INITIAL_LP_SUPPLY}" >/dev/null
    state_set "comet_lp_transferred" "true"
    provision_comet_liquidity \
        "${comet}" "${blnt}" "${usdc}" "${controller}" "${operator}"
    capture "lock-comet-controller" stellar_cli tx new set-options \
        --source-account "${CONTROLLER_IDENTITY}" \
        --low-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --med-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --high-threshold "${COMET_CONTROLLER_THRESHOLD}" \
        --master-weight 0 \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
    state_set "comet_controller_locked" "true"

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
    state_set "emitter_initialized" "true"
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
    state_set "backstop_deployed" "true"

    invoke_transaction "initialize-backstop-emissions" \
        "${backstop}" distribute >/dev/null
    state_set "backstop_emissions_initialized" "true"
    deploy_fixed_pool "${factory}" "${backstop}" "${operator}"
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

command_resume() {
    local operator blnt_issuer controller legacy_blnd legacy_blnd_issuer
    local blnt usdc eurc xlm recorded
    local backfill comet balance initialized pool_hash backstop factory emitter
    local deployed_backstop admin account saved_home current_home recipient probe

    validate_blnt_home_domain
    validate_build_tools
    validate_manifest
    require_network
    validate_artifacts
    load_state
    assert_equal "deploying" "$(state_value phase)" "resumable deployment phase"
    record_deployment_inputs
    operator="$(state_value operator)"
    blnt_issuer="$(state_value blnt_issuer)"
    controller="$(state_value comet_controller)"
    assert_equal "${operator}" "$(stellar_cli keys public-key "${OPERATOR_IDENTITY}")" \
        "saved operator identity"
    assert_equal "${blnt_issuer}" "$(stellar_cli keys public-key "${BLNT_ISSUER_IDENTITY}")" \
        "saved BLNT issuer identity"
    assert_equal "${controller}" "$(stellar_cli keys public-key "${CONTROLLER_IDENTITY}")" \
        "saved Comet controller identity"

    if ! state_has blnt_home_domain; then
        saved_home="${BLNT_HOME_DOMAIN}"
        state_set "blnt_home_domain" "${saved_home}"
    else
        saved_home="$(state_value blnt_home_domain)"
    fi
    if [[ -n "${BLNT_HOME_DOMAIN}" ]]; then
        assert_equal "${saved_home}" "${BLNT_HOME_DOMAIN}" \
            "saved BLNT issuer home domain"
    fi
    account="$(capture "resume-query-blnt-issuer-home-domain" \
        curl --fail --silent --show-error --max-time 10 \
        "${HORIZON_URL}/accounts/${blnt_issuer}")"
    current_home="$(printf '%s' "${account}" | jq -er '.home_domain // ""')"
    if [[ -z "${current_home}" && -n "${saved_home}" ]]; then
        capture "resume-set-blnt-issuer-home-domain" stellar_cli tx new set-options \
            --source-account "${BLNT_ISSUER_IDENTITY}" \
            --home-domain "${saved_home}" \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
    else
        assert_equal "${saved_home}" "${current_home}" \
            "current BLNT issuer home domain"
    fi

    if [[ "${NETWORK_MODE}" == "testnet" ]]; then
        recorded="$(state_optional legacy_blnd_token)"
        [[ -z "${recorded}" ]] ||
            assert_equal "${EXTERNAL_BLND}" "${recorded}" "saved legacy BLND token"
        legacy_blnd="${EXTERNAL_BLND}"
        legacy_blnd_issuer="${EXTERNAL_BLND_ISSUER}"
        require_external_blnd "${legacy_blnd}"
    else
        legacy_blnd="$(ensure_asset "legacy-blnd" BLND "${operator}")"
        legacy_blnd_issuer="${operator}"
    fi
    state_set "legacy_blnd_token" "${legacy_blnd}"
    state_set "legacy_blnd_issuer" "${legacy_blnd_issuer}"

    blnt="$(ensure_asset "blnt" BLNT "${blnt_issuer}")"
    recorded="$(state_optional blnt_token)"
    [[ -z "${recorded}" ]] ||
        assert_equal "${recorded}" "${blnt}" "saved BLNT token"
    state_set "blnt_token" "${blnt}"
    usdc="$(ensure_asset "usdc" USDC "${operator}")"
    recorded="$(state_optional usdc_token)"
    [[ -z "${recorded}" ]] ||
        assert_equal "${recorded}" "${usdc}" "saved USDC token"
    state_set "usdc_token" "${usdc}"
    eurc="$(ensure_asset "eurc" EURC "${operator}")"
    recorded="$(state_optional eurc_token)"
    [[ -z "${recorded}" ]] ||
        assert_equal "${recorded}" "${eurc}" "saved EURC token"
    state_set "eurc_token" "${eurc}"
    xlm="$(resolve_native_asset "resume-resolve-native-xlm")"
    recorded="$(state_optional xlm_token)"
    [[ -z "${recorded}" ]] ||
        assert_equal "${recorded}" "${xlm}" "saved native XLM token"
    state_set "xlm_token" "${xlm}"

    fund_testnet_wallet_assets "${blnt}" "${blnt_issuer}" "${usdc}" "${eurc}"
    verify_wallet_funding

    if [[ "$(state_optional comet_controller_locked)" != "true" ]]; then
        account="$(capture "resume-query-comet-controller-lock" \
            curl --fail --silent --show-error --max-time 10 \
            "${HORIZON_URL}/accounts/${controller}")"
        if printf '%s' "${account}" | jq -e \
            --arg controller "${controller}" \
            --argjson threshold "${COMET_CONTROLLER_THRESHOLD}" '
              .thresholds.low_threshold == $threshold and
              .thresholds.med_threshold == $threshold and
              .thresholds.high_threshold == $threshold and
              (.signers | length) == 1 and
              .signers[0].key == $controller and
              .signers[0].weight == 0
            ' >/dev/null
        then
            state_set "comet_controller_locked" "true"
        fi
    fi
    if [[ "$(state_optional comet_controller_locked)" != "true" ]]; then
        create_trustline "resume-trust-controller-blnt" \
            "${CONTROLLER_IDENTITY}" "BLNT:${blnt_issuer}"
        create_trustline "resume-trust-controller-usdc" \
            "${CONTROLLER_IDENTITY}" "USDC:${operator}"
    fi

    backfill="$(state_optional backfill)"
    if [[ -z "${backfill}" ]]; then
        backfill="$(deploy_wasm "deploy-backfill" "${BACKFILL_WASM}" "" \
            --legacy_blnd_token "${legacy_blnd}" \
            --blnt_token "${blnt}" \
            --claim_list "${CLAIM_LIST}" \
            --grant_list '[]')"
        state_set "backfill" "${backfill}"
    fi
    comet="$(state_optional comet_blnt_usdc)"
    if [[ -z "${comet}" ]]; then
        comet="$(deploy_wasm "deploy-comet-v11" "${COMET_WASM}" "")"
        state_set "comet_blnt_usdc" "${comet}"
    fi

    balance="$(normalize_scalar "$(invoke_view \
        "resume-query-backfill-blnt" "${blnt}" balance --id "${backfill}")")"
    if [[ "$(state_optional backfill_premint_completed)" != "true" ]]; then
        if (( balance == 0 )); then
            invoke_transaction_as "premint-backfill-blnt" "${BLNT_ISSUER_IDENTITY}" \
                "${blnt}" mint --to "${backfill}" \
                --amount "${BACKFILL_PREMINT}" >/dev/null
        else
            assert_equal "${BACKFILL_PREMINT}" "${balance}" \
                "unrecorded backfill BLNT premint"
        fi
        state_set "backfill_premint_completed" "true"
    fi

    initialized="$(state_optional comet_initialized)"
    if [[ "${initialized}" != "true" ]]; then
        if admin="$(invoke_view "resume-probe-comet-initialized" \
            "${comet}" get_controller)"
        then
            assert_equal "${controller}" "$(normalize_scalar "${admin}")" \
                "initialized Comet controller"
            state_set "comet_initialized" "true"
            initialized="true"
        fi
    fi
    if [[ "${initialized}" != "true" ]]; then
        balance="$(normalize_scalar "$(invoke_view \
            "resume-query-controller-blnt" "${blnt}" balance --id "${controller}")")"
        (( balance <= COMET_BLNT_BALANCE )) || die "controller BLNT exceeds Comet seed"
        if (( balance < COMET_BLNT_BALANCE )); then
            invoke_transaction_as "mint-comet-blnt" "${BLNT_ISSUER_IDENTITY}" \
                "${blnt}" mint --to "${controller}" \
                --amount "$((COMET_BLNT_BALANCE - balance))" >/dev/null
        fi
        balance="$(normalize_scalar "$(invoke_view \
            "resume-query-controller-usdc" "${usdc}" balance --id "${controller}")")"
        (( balance <= COMET_USDC_BALANCE )) || die "controller USDC exceeds Comet seed"
        if (( balance < COMET_USDC_BALANCE )); then
            invoke_transaction "mint-comet-usdc" "${usdc}" mint \
                --to "${controller}" --amount "$((COMET_USDC_BALANCE - balance))" >/dev/null
        fi
        invoke_transaction_as "initialize-comet-v11" "${CONTROLLER_IDENTITY}" \
            "${comet}" init \
            --controller "${controller}" \
            --tokens "[\"${blnt}\",\"${usdc}\"]" \
            --weights "[\"${COMET_BLNT_WEIGHT}\",\"${COMET_USDC_WEIGHT}\"]" \
            --balances "[\"${COMET_BLNT_BALANCE}\",\"${COMET_USDC_BALANCE}\"]" \
            --swap_fee "${COMET_SWAP_FEE}" >/dev/null
        state_set "comet_initialized" "true"
    fi
    if [[ "$(state_optional comet_lp_transferred)" != "true" ]]; then
        balance="$(normalize_scalar "$(invoke_view \
            "resume-query-operator-comet-lp" "${comet}" balance --id "${operator}")")"
        if (( balance == 0 )); then
            invoke_transaction_as "transfer-initial-comet-lp" "${CONTROLLER_IDENTITY}" \
                "${comet}" transfer --from "${controller}" --to "${operator}" \
                --amount "${COMET_INITIAL_LP_SUPPLY}" >/dev/null
        else
            assert_equal "${COMET_INITIAL_LP_SUPPLY}" "${balance}" \
                "existing operator Comet LP balance"
        fi
        state_set "comet_lp_transferred" "true"
    fi
    provision_comet_liquidity \
        "${comet}" "${blnt}" "${usdc}" "${controller}" "${operator}"
    if [[ "$(state_optional comet_controller_locked)" != "true" ]]; then
        capture "lock-comet-controller" stellar_cli tx new set-options \
            --source-account "${CONTROLLER_IDENTITY}" \
            --low-threshold "${COMET_CONTROLLER_THRESHOLD}" \
            --med-threshold "${COMET_CONTROLLER_THRESHOLD}" \
            --high-threshold "${COMET_CONTROLLER_THRESHOLD}" \
            --master-weight 0 \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
        state_set "comet_controller_locked" "true"
    fi

    factory="$(state_optional pool_factory)"
    if [[ -z "${factory}" ]]; then
        pool_hash="$(upload_wasm "upload-v2-pool" "${V2_POOL_WASM}")"
        backstop="$(predict_contract_id "predict-v21-backstop" "${BACKSTOP_SALT}")"
        require_contract_id "${backstop}" "predicted backstop"
        factory="$(deploy_wasm "deploy-v2-pool-factory" "${V2_FACTORY_WASM}" "" \
            --pool_init_meta \
            "{\"backstop\":\"${backstop}\",\"blnd_id\":\"${blnt}\",\"pool_hash\":\"${pool_hash}\"}")"
        state_set "pool_wasm_hash" "${pool_hash}"
        state_set "pool_factory" "${factory}"
        state_set "backstop" "${backstop}"
    else
        pool_hash="$(state_value pool_wasm_hash)"
        backstop="$(state_value backstop)"
    fi

    emitter="$(state_optional emitter)"
    if [[ -z "${emitter}" ]]; then
        emitter="$(deploy_wasm "deploy-v1-emitter" "${V1_EMITTER_WASM}" "")"
        state_set "emitter" "${emitter}"
    fi
    if [[ "$(state_optional emitter_initialized)" != "true" ]]; then
        if recipient="$(invoke_view "resume-probe-emitter-initialized" \
            "${emitter}" get_backstop)"
        then
            assert_equal "${backstop}" "$(normalize_scalar "${recipient}")" \
                "initialized emitter backstop"
        else
            invoke_transaction "initialize-emitter" "${emitter}" initialize \
                --blnd_token "${blnt}" --backstop "${backstop}" \
                --backstop_token "${comet}" >/dev/null
        fi
        state_set "emitter_initialized" "true"
    fi
    admin="$(normalize_scalar "$(invoke_view \
        "resume-query-blnt-admin" "${blnt}" admin)")"
    if [[ "${admin}" == "${blnt_issuer}" ]]; then
        invoke_transaction_as "set-emitter-as-blnt-admin" "${BLNT_ISSUER_IDENTITY}" \
            "${blnt}" set_admin --new_admin "${emitter}" >/dev/null
    else
        assert_equal "${emitter}" "${admin}" "existing BLNT administrator"
    fi

    if [[ "$(state_optional backstop_deployed)" != "true" ]]; then
        if invoke_view "probe-existing-v2-backstop" \
            "${backstop}" backstop_token >/dev/null
        then
            deployed_backstop="${backstop}"
        else
            deployed_backstop="$(deploy_wasm "deploy-v2-backstop" \
                "${V2_BACKSTOP_WASM}" "${BACKSTOP_SALT}" \
                --backstop_token "${comet}" --emitter "${emitter}" \
                --blnd_token "${blnt}" --usdc_token "${usdc}" \
                --pool_factory "${factory}" --drop_list '[]')"
        fi
        assert_equal "${backstop}" "${deployed_backstop}" "predicted backstop address"
        state_set "backstop_deployed" "true"
    fi
    if [[ "$(state_optional backstop_emissions_initialized)" != "true" ]]; then
        if probe="$(invoke_probe "resume-probe-backstop-emissions" \
            "${backstop}" distribute)"
        then
            invoke_transaction "initialize-backstop-emissions" \
                "${backstop}" distribute >/dev/null
        elif [[ ! "${probe}" =~ \#1000([^0-9]|$) ]]; then
            die "unable to establish backstop emissions checkpoint: ${probe}"
        fi
        state_set "backstop_emissions_initialized" "true"
    fi
    deploy_fixed_pool "${factory}" "${backstop}" "${operator}"

    account="$(curl --fail --silent --show-error --max-time 10 \
        "${HORIZON_URL}/accounts/${blnt_issuer}")"
    if ! printf '%s' "${account}" | jq -e \
        --argjson threshold "${BLNT_ISSUER_THRESHOLD}" '
          .thresholds.low_threshold == $threshold and
          .thresholds.med_threshold == $threshold and
          .thresholds.high_threshold == $threshold and
          .signers[0].weight == 0
        ' >/dev/null
    then
        capture "lock-blnt-issuer" stellar_cli tx new set-options \
            --source-account "${BLNT_ISSUER_IDENTITY}" \
            --low-threshold "${BLNT_ISSUER_THRESHOLD}" \
            --med-threshold "${BLNT_ISSUER_THRESHOLD}" \
            --high-threshold "${BLNT_ISSUER_THRESHOLD}" \
            --master-weight 0 \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" >/dev/null
    fi
    verify_deployment
    state_set "phase" "verified"
    state_set "verified_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    stellar_cli ledger latest \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --output json-formatted >"${RUN_DIR}/ledger-after-deploy.json"
    note "Blend v2.1 resumed deployment verified. State: ${STATE_FILE}"
}

command_status() {
    validate_runtime_tools
    require_network
    load_state
    verify_deployment false
    jq '{network_label, phase, verified_at, operator, blnt_issuer,
         blnt_issuer_threshold, blnt_home_domain, comet_controller,
         legacy_blnd_token, legacy_blnd_issuer, blnt_token, usdc_token,
         eurc_token, xlm_token, emitter, backfill, comet_blnt_usdc,
         pool_factory, backstop, fixed_pool_oracle, fixed_pool,
         funding_wallet, wallet_blnt_funded,
         wallet_usdc_funded, wallet_eurc_funded, wallet_xlm_funded,
         backfill_premint,
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
        resume) command_resume ;;
        run) command_run ;;
        status) command_status ;;
        stop) command_stop ;;
        -h|--help|help) usage ;;
        *) usage >&2; exit 2 ;;
    esac
}

if [[ "${BLEND_V21_LIBRARY_ONLY:-false}" != "true" ]]; then
    main "$@"
fi
