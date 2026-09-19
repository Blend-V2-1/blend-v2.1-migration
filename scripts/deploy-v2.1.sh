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
EXTERNAL_BLEND_BACKSTOP="${BLEND_V21_EXTERNAL_BLEND_BACKSTOP:-CBDVWXT433PRVTUNM56C3JREF3HIZHRBA64NB2C3B2UNCKIS65ZYCLZA}"
EXTERNAL_TESTNET_USDC="${BLEND_V21_EXTERNAL_TESTNET_USDC:-CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU}"
EXTERNAL_TESTNET_USDC_ISSUER="${BLEND_V21_EXTERNAL_TESTNET_USDC_ISSUER:-GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56}"
EXTERNAL_TESTNET_WETH="${BLEND_V21_EXTERNAL_TESTNET_WETH:-CAZAQB3D7KSLSNOSQKYD2V4JP5V2Y3B4RDJZRLBFCCIXDCTE3WHSY3UE}"
EXTERNAL_TESTNET_WBTC="${BLEND_V21_EXTERNAL_TESTNET_WBTC:-CAP5AMC2OHNVREO66DFIN6DHJMPOBAJ2KCDDIMFBR7WWJH5RZBFM3UEI}"
EXTERNAL_TESTNET_ORACLE="${BLEND_V21_EXTERNAL_TESTNET_ORACLE:-CAZOKR2Y5E2OSWSIBRVZMJ47RUTQPIGVWSAQ2UISGAVC46XKPGDG5PKI}"
EXTERNAL_TESTNET_V2_POOL="${BLEND_V21_EXTERNAL_TESTNET_V2_POOL:-CCEBVDYM32YNYCVNRXQKDFFPISJJCV557CDZEIRBEE4NCV4KHPQ44HGF}"
FUNDING_WALLET="${BLEND_V21_FUNDING_WALLET:-GDPAIYJ2FISB5H7JNWDNRERAIMGZSP4HVQKYMKO42KRB23GANJXNG2ZI}"
WALLET_CONFIG_DIR="${BLEND_V21_WALLET_CONFIG_DIR:-}"
WALLET_IDENTITY="${BLEND_V21_WALLET_IDENTITY:-}"
BLND_SOURCE_CONFIG_DIR="${BLEND_V21_BLND_SOURCE_CONFIG_DIR:-${WALLET_CONFIG_DIR}}"
BLND_SOURCE_IDENTITY="${BLEND_V21_BLND_SOURCE_IDENTITY:-${WALLET_IDENTITY}}"

SCALAR_7=10000000
COMET_BLND_BALANCE=$((600 * SCALAR_7))
COMET_USDC_BALANCE=$((6 * SCALAR_7))
COMET_INITIAL_LP_SUPPLY=$((100 * SCALAR_7))
COMET_BLND_WEIGHT=8000000
COMET_USDC_WEIGHT=2000000
COMET_SWAP_FEE=30000
COMET_CONTROLLER_THRESHOLD=100
FIXTURE_ORACLE_RESOLUTION=300
FIXTURE_ORACLE_RECORDS=7
BACKSTOP_SALT="${BLEND_V21_BACKSTOP_SALT:-0000000000000000000000000000000000000000000000000000000000000021}"
TESTNET_V21_POOL_SALT="${BLEND_V21_POOL_SALT:-000000000000000000000000000000000000000000000000000000000000f121}"

V1_DIR="${ROOT_DIR}/blend-contracts"
V2_DIR="${ROOT_DIR}/blend-contracts-v2"
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
COMET_WASM="${COMET_DIR}/target/wasm32v1-none/optimized/comet.wasm"
COMET_WASM_SHA256="7613f207c48f69c0299da2cb4a7a2946bbac7479ffcbeb7e428aa1d4ee37d113"
ORACLE_DIR="${ROOT_DIR}/test-sep40-oracle"
ORACLE_WASM="${ORACLE_DIR}/target/wasm32v1-none/optimized/blend_v21_test_sep40_oracle.wasm"
ORACLE_WASM_SHA256="d60558a660250bc6c1dc318c0e0f4e0d1ec42ab84341c92d465a0bb378daf262"
TESTNET_V2_FIXTURE="${ROOT_DIR}/fixtures/testnet-v2.json"
TESTNET_V2_FIXTURE_SHA256="cc81042982380d7cc1ee4a2bd65f294c73c8110444908722d3d8187027a3ca7b"
RUN_DIR=""

usage() {
    cat <<'EOF'
Usage: scripts/deploy-v2.1.sh COMMAND

Commands:
  plan      Describe the v2.1 deployment without mutation.
  validate  Build and validate all pinned contract artifacts.
  start     Start local Protocol-27 Quickstart or check public testnet health.
  deploy    Deploy and verify a fresh unfunded v2.1 TestnetV2.1 stack.
  resume    Resume pool configuration after an interrupted deployment.
  activate-pool
            After user funding, activate borrowing, enroll TestnetV2.1 in the
            reward zone, and start legacy backfill accounting.
  enable-emissions
            Finalize the legacy backfill drop and normal emissions after the
            emitter completes its normal backstop swap to V2.1.
  run       Validate, start, deploy, and report status.
  status    Read and verify the recorded deployment without submitting transactions.
  stop      Stop the ephemeral local Quickstart container.

Set BLEND_V21_NETWORK=testnet for public testnet. Public state, signing keys,
transaction output, and cost logs remain in the ignored network work directory.
Testnet deployment reuses the existing BLND asset and emitter. Set
BLEND_V21_WALLET_CONFIG_DIR and BLEND_V21_WALLET_IDENTITY to the funding-wallet
signer. Set the BLEND_V21_BLND_SOURCE_* overrides only when another signer
supplies BLND.
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

validate_testnet_v2_fixture() {
    [[ -s "${TESTNET_V2_FIXTURE}" ]] ||
        die "TestnetV2 fixture is missing: ${TESTNET_V2_FIXTURE}"
    jq -e '
      .source.network == "testnet" and
      .source.pool == "CCEBVDYM32YNYCVNRXQKDFFPISJJCV557CDZEIRBEE4NCV4KHPQ44HGF" and
      .source.oracle == "CAZOKR2Y5E2OSWSIBRVZMJ47RUTQPIGVWSAQ2UISGAVC46XKPGDG5PKI" and
      .assets == {
        XLM: "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC",
        USDC: "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU",
        wETH: "CAZAQB3D7KSLSNOSQKYD2V4JP5V2Y3B4RDJZRLBFCCIXDCTE3WHSY3UE",
        wBTC: "CAP5AMC2OHNVREO66DFIN6DHJMPOBAJ2KCDDIMFBR7WWJH5RZBFM3UEI"
      } and
      .pool.name == "TestnetV2.1" and
      .pool.backstop_take_rate == 1000000 and
      .pool.max_positions == 8 and
      .pool.min_collateral == "0" and
      ([.pool.reserves[].asset] == ["XLM", "wETH", "wBTC", "USDC"]) and
      (.pool.reserves | length == 4) and
      .pool.emissions == [
        {res_index: 1, res_type: 0, share: 4000000},
        {res_index: 2, res_type: 1, share: 2000000},
        {res_index: 3, res_type: 0, share: 4000000}
      ]
    ' "${TESTNET_V2_FIXTURE}" >/dev/null ||
        die "TestnetV2 fixture failed invariant validation"
}

build_artifacts() {
    note "Fetching official V2 artifacts and building Comet v1.1 and the test oracle..."
    make -C "${ROOT_DIR}" build
}

validate_artifacts() {
    local artifact
    for artifact in \
        "${V1_EMITTER_WASM}" \
        "${V2_FACTORY_WASM}" \
        "${V2_BACKSTOP_WASM}" \
        "${V2_POOL_WASM}" \
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
    assert_equal "${COMET_WASM_SHA256}" "$(sha256_file "${COMET_WASM}")" \
        "designated Comet v1.1 WASM hash"
    assert_equal "${ORACLE_WASM_SHA256}" "$(sha256_file "${ORACLE_WASM}")" \
        "designated test SEP-40 oracle WASM hash"
    assert_equal "${TESTNET_V2_FIXTURE_SHA256}" \
        "$(sha256_file "${TESTNET_V2_FIXTURE}")" \
        "designated TestnetV2 fixture hash"
    validate_testnet_v2_fixture
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
    local operator="$1" controller="$2"
    mkdir -p "${WORK_DIR}"
    jq -n \
        --arg network_mode "${NETWORK_MODE}" \
        --arg network_label "${NETWORK_LABEL}" \
        --arg network_passphrase "${NETWORK_PASSPHRASE}" \
        --arg rpc_url "${RPC_URL}" \
        --arg operator "${operator}" \
        --arg comet_controller "${controller}" \
        --arg run_dir "${RUN_DIR}" \
        --arg root_commit "$(git -C "${ROOT_DIR}" rev-parse HEAD)" \
        --arg v1_commit "$(git -C "${V1_DIR}" rev-parse HEAD)" \
        --arg v2_commit "$(git -C "${V2_DIR}" rev-parse HEAD)" \
        --arg comet_commit "$(git -C "${COMET_DIR}" rev-parse HEAD)" \
        --arg root_dirty "$(git -C "${ROOT_DIR}" status --porcelain=v1)" \
        --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          network_mode: $network_mode,
          network_label: $network_label,
          network_passphrase: $network_passphrase,
          rpc_url: $rpc_url,
          operator: $operator,
          comet_controller: $comet_controller,
          run_dir: $run_dir,
          source: {
            migration: $root_commit,
            migration_dirty: ($root_dirty != ""),
            blend_contracts_v1: $v1_commit,
            blend_contracts_v2: $v2_commit,
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

state_mark_emissions_enabled() {
    local timestamp temporary="${STATE_FILE}.tmp"
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq --arg timestamp "${timestamp}" '
      .emissions_enabled = "true" |
      .backfill_active = "false" |
      .emissions_enabled_at = $timestamp |
      .phase = "verified" |
      .verified_at = $timestamp
    ' "${STATE_FILE}" >"${temporary}"
    mv "${temporary}" "${STATE_FILE}"
}

state_mark_pool_activated() {
    local timestamp fixture_sha256 temporary="${STATE_FILE}.tmp"
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    fixture_sha256="$(sha256_file "${TESTNET_V2_FIXTURE}")"
    jq --arg timestamp "${timestamp}" --arg fixture_sha256 "${fixture_sha256}" '
      .pool_backstop_funded = "true" |
      .pool_activation_pending = "false" |
      .backfill_enabled = "true" |
      .backfill_active = "true" |
      .emissions_enabled = "false" |
      .pool_activated_at = $timestamp |
      .testnet_v2_fixture_sha256 = $fixture_sha256 |
      .phase = "verified" |
      .verified_at = $timestamp
    ' "${STATE_FILE}" >"${temporary}"
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
    state_record "v1_emitter_wasm_sha256" "$(sha256_file "${V1_EMITTER_WASM}")"
    state_record "v2_factory_wasm_sha256" "$(sha256_file "${V2_FACTORY_WASM}")"
    state_record "v2_factory_release" "${V2_FACTORY_RELEASE}"
    state_record "v2_backstop_wasm_sha256" "$(sha256_file "${V2_BACKSTOP_WASM}")"
    state_record "v2_backstop_release" "${V2_BACKSTOP_RELEASE}"
    state_record "v2_pool_wasm_sha256" "$(sha256_file "${V2_POOL_WASM}")"
    state_record "v2_pool_release" "${V2_POOL_RELEASE}"
    state_record "comet_v11_wasm_sha256" "$(sha256_file "${COMET_WASM}")"
    state_record "local_oracle_wasm_sha256" "$(sha256_file "${ORACLE_WASM}")"
    state_record "testnet_v2_fixture_sha256" "$(sha256_file "${TESTNET_V2_FIXTURE}")"
    state_record "comet_initial_blnd" "${COMET_BLND_BALANCE}"
    state_record "comet_initial_usdc" "${COMET_USDC_BALANCE}"
    state_record "comet_initial_lp_supply" "${COMET_INITIAL_LP_SUPPLY}"
    state_record "backstop_salt" "${BACKSTOP_SALT}"
    state_record "pool_salt" "${TESTNET_V21_POOL_SALT}"
}

load_state() {
    [[ -s "${STATE_FILE}" ]] || die "deployment state not found: ${STATE_FILE}"
    assert_equal "${NETWORK_MODE}" "$(state_value network_mode)" "saved network mode"
    assert_equal "${RPC_URL}" "$(state_value rpc_url)" "saved RPC URL"
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

blnd_source_stellar_cli() {
    "${DEPLOY_STELLAR}" --config-dir "${BLND_SOURCE_CONFIG_DIR}" "$@"
}

require_blnd_source_access() {
    local expected="$1" configured
    [[ "${NETWORK_MODE}" == "testnet" ]] || return 0
    [[ -n "${BLND_SOURCE_CONFIG_DIR}" ]] ||
        die "BLEND_V21_BLND_SOURCE_CONFIG_DIR or BLEND_V21_WALLET_CONFIG_DIR is required on public testnet"
    [[ -n "${BLND_SOURCE_IDENTITY}" ]] ||
        die "BLEND_V21_BLND_SOURCE_IDENTITY or BLEND_V21_WALLET_IDENTITY is required on public testnet"
    [[ -d "${BLND_SOURCE_CONFIG_DIR}" ]] ||
        die "BLND source Stellar config directory not found: ${BLND_SOURCE_CONFIG_DIR}"
    configured="$(blnd_source_stellar_cli keys public-key "${BLND_SOURCE_IDENTITY}")" ||
        die "BLND source identity is unavailable: ${BLND_SOURCE_IDENTITY}"
    assert_equal "${expected}" "${configured}" "configured BLND source identity"
}

fund_controller_blnd() {
    local blnd="$1" controller="$2" target="$3" source="$4"
    local balance difference available
    balance="$(normalize_scalar "$(invoke_view \
        "query-controller-blnd-funding" "${blnd}" balance --id "${controller}")")"
    (( balance <= target )) || die "controller BLND exceeds expected funding"
    difference=$((target - balance))
    (( difference > 0 )) || return 0
    if [[ "${NETWORK_MODE}" == "local" ]]; then
        invoke_transaction "mint-controller-blnd" "${blnd}" mint \
            --to "${controller}" --amount "${difference}" >/dev/null
        return
    fi
    require_blnd_source_access "${source}"
    available="$(normalize_scalar "$(invoke_view \
        "query-blnd-source-balance" "${blnd}" balance --id "${source}")")"
    (( available >= difference )) ||
        die "BLND source requires ${difference}, only ${available} is available"
    capture "transfer-controller-blnd" blnd_source_stellar_cli contract invoke \
        --id "${blnd}" \
        --source-account "${BLND_SOURCE_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost -- transfer --from "${source}" --to "${controller}" \
        --amount "${difference}" >/dev/null
}

require_funding_wallet_access() {
    local configured_wallet
    [[ "${NETWORK_MODE}" == "testnet" ]] || return 0
    [[ -n "${WALLET_CONFIG_DIR}" ]] ||
        die "BLEND_V21_WALLET_CONFIG_DIR is required on public testnet"
    [[ -n "${WALLET_IDENTITY}" ]] ||
        die "BLEND_V21_WALLET_IDENTITY is required on public testnet"
    [[ -d "${WALLET_CONFIG_DIR}" ]] ||
        die "wallet Stellar config directory not found: ${WALLET_CONFIG_DIR}"
    configured_wallet="$(wallet_stellar_cli keys public-key "${WALLET_IDENTITY}")" ||
        die "wallet identity is unavailable: ${WALLET_IDENTITY}"
    assert_equal "${FUNDING_WALLET}" "${configured_wallet}" \
        "configured funding-wallet identity"
}

fund_controller_usdc() {
    local usdc="$1" controller="$2" target="$3"
    local balance difference available
    balance="$(normalize_scalar "$(invoke_view \
        "query-controller-usdc-funding" "${usdc}" balance --id "${controller}")")"
    (( balance <= target )) || die "controller USDC exceeds expected funding"
    difference=$((target - balance))
    (( difference > 0 )) || return 0
    if [[ "${NETWORK_MODE}" == "local" ]]; then
        invoke_transaction "mint-controller-usdc" "${usdc}" mint \
            --to "${controller}" --amount "${difference}" >/dev/null
        return
    fi
    require_funding_wallet_access
    available="$(normalize_scalar "$(invoke_view \
        "query-usdc-source-balance" "${usdc}" balance --id "${FUNDING_WALLET}")")"
    (( available >= difference )) ||
        die "funding wallet requires ${difference} USDC stroops, only ${available} are available"
    capture "transfer-controller-usdc" wallet_stellar_cli contract invoke \
        --id "${usdc}" \
        --source-account "${WALLET_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost -- transfer --from "${FUNDING_WALLET}" --to "${controller}" \
        --amount "${difference}" >/dev/null
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

verify_comet_controller_empty() {
    local blnd="$1" usdc="$2" controller="$3"
    assert_equal "0" "$(normalize_scalar "$(invoke_view \
        "verify-controller-blnd-empty" "${blnd}" balance \
        --id "${controller}")")" "controller BLND balance before lock"
    assert_equal "0" "$(normalize_scalar "$(invoke_view \
        "verify-controller-usdc-empty" "${usdc}" balance \
        --id "${controller}")")" "controller USDC balance before lock"
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

modeled_asset_id() {
    case "$1" in
        XLM) state_value xlm_token ;;
        USDC) state_value usdc_token ;;
        wETH) state_value weth_token ;;
        wBTC) state_value wbtc_token ;;
        *) die "unknown TestnetV2 asset: $1" ;;
    esac
}

seed_modeled_oracle() {
    local oracle="$1" asset token price prices label
    for asset in USDC XLM wETH wBTC; do
        label="$(printf '%s' "${asset}" | tr '[:upper:]' '[:lower:]')"
        token="$(modeled_asset_id "${asset}")"
        case "${asset}" in
            USDC) price=10000000 ;;
            XLM) price=2500000 ;;
            wETH) price=25000000000 ;;
            wBTC) price=1000000000000 ;;
        esac
        prices="$(fixture_price_series "${price}")"
        if ! invoke_transaction "seed-testnet-v21-oracle-${label}" \
            "${oracle}" set_prices \
            --asset "{\"Stellar\":\"${token}\"}" \
            --prices "${prices}" >/dev/null
        then
            note "Failed to refresh local TestnetV2.1 oracle ${asset} price history."
            return 1
        fi
    done
    state_set "pool_oracle_refreshed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

modeled_reserve_config() {
    local index="$1"
    jq -c --argjson index "${index}" \
        '.pool.reserves[$index].config + {
          decimals: 7,
          enabled: true,
          index: $index
        }' "${TESTNET_V2_FIXTURE}"
}

validate_live_testnet_v2_source() {
    local config reserves asset token expected index=0
    [[ "${NETWORK_MODE}" == "testnet" ]] || return 0
    config="$(invoke_view "query-source-testnet-v2-config" \
        "${EXTERNAL_TESTNET_V2_POOL}" get_config)"
    printf '%s' "${config}" | jq -e \
        --arg oracle "${EXTERNAL_TESTNET_ORACLE}" '
          .oracle == $oracle and .bstop_rate == 1000000 and
          .max_positions == 8 and (.min_collateral | tostring) == "0"
        ' >/dev/null || die "live TestnetV2 pool configuration differs from fixture"
    reserves="$(invoke_view "query-source-testnet-v2-reserves" \
        "${EXTERNAL_TESTNET_V2_POOL}" get_reserve_list)"
    printf '%s' "${reserves}" | jq -e \
        --arg xlm "$(state_value xlm_token)" \
        --arg weth "$(state_value weth_token)" \
        --arg wbtc "$(state_value wbtc_token)" \
        --arg usdc "$(state_value usdc_token)" \
        '. == [$xlm, $weth, $wbtc, $usdc]' >/dev/null ||
        die "live TestnetV2 reserve order differs from fixture"
    for asset in XLM wETH wBTC USDC; do
        token="$(modeled_asset_id "${asset}")"
        expected="$(modeled_reserve_config "${index}")"
        invoke_view "query-source-testnet-v2-${asset}-reserve" \
            "${EXTERNAL_TESTNET_V2_POOL}" get_reserve --asset "${token}" | jq -e \
            --arg token "${token}" --argjson expected "${expected}" \
            '.asset == $token and .config == $expected' >/dev/null ||
            die "live TestnetV2 ${asset} reserve differs from fixture"
        index=$((index + 1))
    done
}

deploy_testnet_v21_pool() {
    local factory="$1" backstop="$2" operator="$3"
    local xlm usdc weth wbtc oracle pool raw name take_rate max_positions min_collateral
    local asset token metadata label index=0 status reward_zone shares reserve_list

    xlm="$(state_value xlm_token)"
    usdc="$(state_value usdc_token)"
    weth="$(state_value weth_token)"
    wbtc="$(state_value wbtc_token)"
    oracle="$(state_optional pool_oracle)"
    if [[ -z "${oracle}" ]]; then
        [[ "${NETWORK_MODE}" == "local" ]] ||
            die "recorded TestnetV2 oracle is missing"
        oracle="$(deploy_wasm "deploy-testnet-v21-oracle" "${ORACLE_WASM}" "" \
            --admin "${operator}" \
            --base '{"Other":"USD"}' \
            --assets "[{\"Stellar\":\"${usdc}\"},{\"Stellar\":\"${xlm}\"},{\"Stellar\":\"${weth}\"},{\"Stellar\":\"${wbtc}\"}]" \
            --decimals 7 \
            --resolution "${FIXTURE_ORACLE_RESOLUTION}")"
        state_set "pool_oracle" "${oracle}"
    fi
    if [[ "${NETWORK_MODE}" == "local" ]]; then
        seed_modeled_oracle "${oracle}"
    fi

    name="$(jq -er '.pool.name' "${TESTNET_V2_FIXTURE}")"
    take_rate="$(jq -er '.pool.backstop_take_rate' "${TESTNET_V2_FIXTURE}")"
    max_positions="$(jq -er '.pool.max_positions' "${TESTNET_V2_FIXTURE}")"
    min_collateral="$(jq -er '.pool.min_collateral' "${TESTNET_V2_FIXTURE}")"
    pool="$(state_optional pool)"
    if [[ -z "${pool}" ]]; then
        raw="$(invoke_view "predict-testnet-v21-pool" "${factory}" deploy \
            --admin "${operator}" \
            --name "${name}" \
            --salt "${TESTNET_V21_POOL_SALT}" \
            --oracle "${oracle}" \
            --backstop_take_rate "${take_rate}" \
            --max_positions "${max_positions}" \
            --min_collateral "${min_collateral}")"
        pool="$(normalize_scalar "${raw}")"
        require_contract_id "${pool}" "TestnetV2.1 pool"
        state_set "pool" "${pool}"
    fi
    if [[ "$(normalize_scalar "$(invoke_view \
        "query-testnet-v21-registration-before-deploy" "${factory}" is_pool \
        --pool_address "${pool}")")" != "true" ]]
    then
        raw="$(invoke_transaction "deploy-testnet-v21-pool" "${factory}" deploy \
            --admin "${operator}" \
            --name "${name}" \
            --salt "${TESTNET_V21_POOL_SALT}" \
            --oracle "${oracle}" \
            --backstop_take_rate "${take_rate}" \
            --max_positions "${max_positions}" \
            --min_collateral "${min_collateral}")"
        assert_equal "${pool}" "$(normalize_scalar "${raw}")" \
            "predicted TestnetV2.1 pool address"
    fi

    reserve_list="$(invoke_view "query-testnet-v21-reserves-before-configuration" \
        "${pool}" get_reserve_list)"
    for asset in XLM wETH wBTC USDC; do
        label="$(printf '%s' "${asset}" | tr '[:upper:]' '[:lower:]')"
        token="$(modeled_asset_id "${asset}")"
        metadata="$(modeled_reserve_config "${index}")"
        if ! printf '%s' "${reserve_list}" | jq -e --arg token "${token}" \
            'index($token) != null' >/dev/null
        then
            if invoke_view "probe-testnet-v21-queued-reserve-${label}" \
                "${pool}" set_reserve --asset "${token}" >/dev/null
            then
                invoke_transaction "resume-testnet-v21-reserve-${label}" \
                    "${pool}" set_reserve --asset "${token}" >/dev/null
            else
                invoke_transaction "queue-testnet-v21-reserve-${label}" \
                    "${pool}" queue_set_reserve \
                    --asset "${token}" --metadata "${metadata}" >/dev/null
                invoke_transaction "set-testnet-v21-reserve-${label}" \
                    "${pool}" set_reserve --asset "${token}" >/dev/null
            fi
            reserve_list="$(invoke_view "query-testnet-v21-reserves-after-${label}" \
                "${pool}" get_reserve_list)"
        fi
        index=$((index + 1))
    done

    status="$(invoke_view "query-testnet-v21-config-before-on-ice" \
        "${pool}" get_config | jq -er '.status | tostring')"
    if [[ "${status}" == "6" ]]; then
        invoke_transaction "put-testnet-v21-pool-on-ice" \
            "${pool}" set_status --pool_status 2 >/dev/null
    fi
    assert_equal "true" "$(normalize_scalar "$(invoke_view \
        "verify-testnet-v21-factory-registration" "${factory}" is_pool \
        --pool_address "${pool}")")" "TestnetV2.1 factory registration"
    assert_equal "${operator}" "$(normalize_scalar "$(invoke_view \
        "verify-testnet-v21-admin" "${pool}" get_admin)")" "TestnetV2.1 admin"
    assert_equal "2" "$(invoke_view "verify-testnet-v21-status" \
        "${pool}" get_config | jq -er '.status | tostring')" "TestnetV2.1 status"
    invoke_view "verify-testnet-v21-config" "${pool}" get_config | jq -e \
        --arg oracle "${oracle}" \
        --argjson take_rate "${take_rate}" \
        --argjson max_positions "${max_positions}" \
        --arg min_collateral "${min_collateral}" '
          .oracle == $oracle and
          .bstop_rate == $take_rate and
          .max_positions == $max_positions and
          (.min_collateral | tostring) == $min_collateral
        ' >/dev/null || die "TestnetV2.1 config differs from fixture"
    invoke_view "verify-testnet-v21-reserves" "${pool}" get_reserve_list | jq -e \
        --arg xlm "${xlm}" --arg weth "${weth}" --arg wbtc "${wbtc}" --arg usdc "${usdc}" \
        '. == [$xlm, $weth, $wbtc, $usdc]' >/dev/null ||
        die "TestnetV2.1 reserve order differs from TestnetV2"
    reward_zone="$(invoke_view "verify-testnet-v21-reward-zone-empty" \
        "${backstop}" reward_zone)"
    printf '%s' "${reward_zone}" | jq -e 'length == 0' >/dev/null ||
        die "new V2.1 backstop reward zone is not empty"
    shares="$(invoke_view "verify-testnet-v21-backstop-unfunded" \
        "${backstop}" user_balance --pool "${pool}" --user "${FUNDING_WALLET}" |
        jq -er '.shares | tostring')"
    assert_equal "0" "${shares}" "TestnetV2.1 backstop shares"
    state_set "pool_backstop_funded" "false"
    state_set "pool_activation_pending" "true"
    state_set "backfill_enabled" "false"
    state_set "backfill_active" "false"
    state_set "emissions_enabled" "false"
}

require_existing_blnd() {
    local blnd="$1" issuer="$2" resolved
    require_contract_id "${blnd}" "existing BLND"
    resolved="$(resolve_asset "resolve-existing-blnd" "BLND:${issuer}")"
    assert_equal "${blnd}" "${resolved}" "existing BLND SAC address"
    assert_equal "7" "$(normalize_scalar "$(invoke_view \
        "query-existing-blnd-decimals" "${blnd}" decimals)")" \
        "existing BLND decimals"
    assert_equal "BLND" "$(normalize_scalar "$(invoke_view \
        "query-existing-blnd-symbol" "${blnd}" symbol)")" \
        "existing BLND symbol"
}

resolve_testnet_emitter() {
    local blnd="$1" emitter recipient
    emitter="$(normalize_scalar "$(invoke_view \
        "query-existing-blnd-admin" "${blnd}" admin)")"
    require_contract_id "${emitter}" "existing BLND emitter"
    recipient="$(normalize_scalar "$(invoke_view \
        "query-existing-emitter-backstop" "${emitter}" get_backstop)")"
    assert_equal "${EXTERNAL_BLEND_BACKSTOP}" "${recipient}" \
        "existing emitter backstop"
    printf '%s\n' "${emitter}"
}

verify_testnet_v21_pool_deployment() {
    local operator factory backstop oracle pool xlm usdc weth wbtc config reserves reward shares
    local asset token expected reserve activation_pending expected_status index=0
    local emissions_raw emissions_actual emissions_expected
    operator="$(state_value operator)"
    factory="$(state_value pool_factory)"
    backstop="$(state_value backstop)"
    oracle="$(state_value pool_oracle)"
    pool="$(state_value pool)"
    xlm="$(state_value xlm_token)"
    usdc="$(state_value usdc_token)"
    weth="$(state_value weth_token)"
    wbtc="$(state_value wbtc_token)"
    activation_pending="$(state_optional pool_activation_pending)"
    activation_pending="${activation_pending:-true}"
    if [[ "${activation_pending}" == "true" ]]; then
        expected_status=2
    else
        expected_status=0
    fi
    assert_equal "true" "$(normalize_scalar "$(invoke_view \
        "query-testnet-v21-pool-registration" "${factory}" is_pool \
        --pool_address "${pool}")")" \
        "TestnetV2.1 factory registration"
    assert_equal "${operator}" "$(normalize_scalar "$(invoke_view \
        "query-testnet-v21-pool-admin" "${pool}" get_admin)")" "TestnetV2.1 admin"
    config="$(invoke_view "query-testnet-v21-pool-config" "${pool}" get_config)"
    printf '%s' "${config}" | jq -e \
        --arg oracle "${oracle}" \
        --argjson take_rate "$(jq -er '.pool.backstop_take_rate' "${TESTNET_V2_FIXTURE}")" \
        --argjson max_positions "$(jq -er '.pool.max_positions' "${TESTNET_V2_FIXTURE}")" \
        --argjson expected_status "${expected_status}" \
        --arg min_collateral "$(jq -er '.pool.min_collateral | tostring' "${TESTNET_V2_FIXTURE}")" '
          .oracle == $oracle and .status == $expected_status and
          .bstop_rate == $take_rate and .max_positions == $max_positions and
          (.min_collateral | tostring) == $min_collateral
        ' >/dev/null || die "TestnetV2.1 pool config differs from fixture"
    reserves="$(invoke_view "query-testnet-v21-pool-reserves" "${pool}" get_reserve_list)"
    printf '%s' "${reserves}" | jq -e \
        --arg xlm "${xlm}" --arg weth "${weth}" --arg wbtc "${wbtc}" --arg usdc "${usdc}" \
        '. == [$xlm, $weth, $wbtc, $usdc]' >/dev/null ||
        die "TestnetV2.1 reserve order differs from TestnetV2"
    for asset in XLM wETH wBTC USDC; do
        token="$(modeled_asset_id "${asset}")"
        expected="$(modeled_reserve_config "${index}")"
        reserve="$(invoke_view "query-testnet-v21-${asset}-reserve" \
            "${pool}" get_reserve --asset "${token}")"
        printf '%s' "${reserve}" | jq -e \
            --arg token "${token}" --argjson expected "${expected}" \
            '.asset == $token and .config == $expected' >/dev/null ||
            die "TestnetV2.1 ${asset} reserve differs from TestnetV2"
        index=$((index + 1))
    done
    reward="$(invoke_view "query-testnet-v21-reward-zone" "${backstop}" reward_zone)"
    if [[ "${activation_pending}" == "true" ]]; then
        printf '%s' "${reward}" | jq -e 'length == 0' >/dev/null ||
            die "new V2.1 reward zone is not empty"
    else
        printf '%s' "${reward}" | jq -e --arg pool "${pool}" \
            'length == 1 and .[0] == $pool' >/dev/null ||
            die "TestnetV2.1 is not the sole reward-zone member"
        emissions_raw="$(capture "query-testnet-v21-pool-emissions" \
            stellar_cli contract read \
            --id "${pool}" --key PoolEmis --durability persistent --output string \
            --rpc-url "${RPC_URL}" --network-passphrase "${NETWORK_PASSPHRASE}")"
        emissions_actual="${emissions_raw#*,\"}"
        emissions_actual="${emissions_actual%\",*}"
        emissions_actual="${emissions_actual//\"\"/\"}"
        emissions_actual="$(printf '%s' "${emissions_actual}" | jq -cS .)" ||
            die "unable to parse TestnetV2.1 emissions"
        emissions_expected="$(jq -cS '
          .pool.emissions |
          map({key: ((.res_index * 2 + .res_type) | tostring), value: .share}) |
          from_entries
        ' "${TESTNET_V2_FIXTURE}")"
        assert_equal "${emissions_expected}" "${emissions_actual}" \
            "TestnetV2.1 emission allocations"
    fi
    shares="$(invoke_view "query-testnet-v21-backstop-balance" \
        "${backstop}" pool_data --pool "${pool}" | jq -er '.shares | tostring')"
    if [[ "${activation_pending}" != "true" ]]; then
        [[ "${shares}" =~ ^[1-9][0-9]*$ ]] ||
            die "TestnetV2.1 funding-wallet backstop shares are not positive"
    fi
    assert_equal "7" "$(normalize_scalar "$(invoke_view \
        "query-testnet-v21-oracle-decimals" "${oracle}" decimals)")" \
        "TestnetV2.1 oracle decimals"
    assert_equal "${FIXTURE_ORACLE_RESOLUTION}" "$(normalize_scalar "$(invoke_view \
        "query-testnet-v21-oracle-resolution" "${oracle}" resolution)")" \
        "TestnetV2.1 oracle resolution"
    invoke_view "query-testnet-v21-oracle-assets" "${oracle}" assets | jq -e \
        --arg xlm "${xlm}" --arg usdc "${usdc}" \
        --arg weth "${weth}" --arg wbtc "${wbtc}" \
        '. == [{Stellar:$usdc},{Stellar:$xlm},{Stellar:$weth},{Stellar:$wbtc}]' \
        >/dev/null || die "TestnetV2.1 oracle assets differ from TestnetV2"
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
    local label="$1" contract="$2" function="$3" output status attempt
    shift 3
    for attempt in 1 2 3 4 5; do
        set +e
        output="$(capture "${label}" stellar_cli contract invoke \
            --id "${contract}" \
            --source-account "${OPERATOR_IDENTITY}" \
            --rpc-url "${RPC_URL}" \
            --network-passphrase "${NETWORK_PASSPHRASE}" \
            --send no --cost -- "${function}" "$@")"
        status=$?
        set -e
        if (( status == 0 )); then
            printf '%s' "${output}"
            return 0
        fi
        (( attempt == 5 )) || sleep 2
    done
    return "${status}"
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

ensure_backstop_emissions_checkpoint() {
    local backstop="$1" output
    if output="$(capture_combined "advance-backstop-emissions" \
        stellar_cli contract invoke \
        --id "${backstop}" \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost -- distribute)"
    then
        note "V2.1 backstop emissions checkpoint advanced."
        return
    fi
    if [[ "${output}" =~ \#1000([^0-9]|$) ]]; then
        note "V2.1 backstop emissions checkpoint was already recent."
        return
    fi
    die "unable to advance the V2.1 backstop emissions checkpoint: ${output}"
}

ensure_backfill_drop() {
    local backstop="$1" output
    if [[ "$(state_optional backfill_drop_completed)" == "true" ]]; then
        return
    fi
    if output="$(capture_combined "complete-v2-backfill-drop" \
        stellar_cli contract invoke \
        --id "${backstop}" \
        --source-account "${OPERATOR_IDENTITY}" \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --cost -- drop)"
    then
        note "V2.1 legacy backfill drop completed."
    elif [[ "${output}" =~ \#1101([^0-9]|$) ]]; then
        note "V2.1 legacy backfill drop was already completed."
    else
        die "unable to complete the V2.1 legacy backfill drop: ${output}"
    fi
    state_set "backfill_drop_completed" "true"
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

verify_comet() {
    local comet="$1" controller="$2" blnd="$3" usdc="$4"
    local verify_initial_balances="${5:-true}"
    local tokens blnd_weight usdc_weight total_supply blnd_balance usdc_balance
    local blnd_decimals usdc_decimals comet_decimals
    local controller_account controller_locked=false
    [[ "${comet}" != "${blnd}" && "${comet}" != "${usdc}" && "${blnd}" != "${usdc}" ]] ||
        die "Comet, BLND, and USDC addresses must be distinct"
    blnd_decimals="$(normalize_scalar "$(invoke_view \
        "query-blnd-decimals" "${blnd}" decimals)")"
    usdc_decimals="$(normalize_scalar "$(invoke_view \
        "query-usdc-decimals" "${usdc}" decimals)")"
    comet_decimals="$(normalize_scalar "$(invoke_view \
        "query-comet-decimals" "${comet}" decimals)")"
    assert_equal "7" "${blnd_decimals}" "BLND decimals"
    assert_equal "7" "${usdc_decimals}" "USDC decimals"
    assert_equal "7" "${comet_decimals}" "Comet LP decimals"
    tokens="$(invoke_view "query-comet-tokens" "${comet}" get_tokens)"
    printf '%s' "${tokens}" | jq -e \
        --arg blnd "${blnd}" --arg usdc "${usdc}" '. == [$blnd, $usdc]' >/dev/null ||
        die "Comet token pair is not [BLND, USDC]"
    blnd_weight="$(normalize_scalar "$(invoke_view \
        "query-comet-blnd-weight" "${comet}" get_normalized_weight --token "${blnd}")")"
    usdc_weight="$(normalize_scalar "$(invoke_view \
        "query-comet-usdc-weight" "${comet}" get_normalized_weight --token "${usdc}")")"
    assert_equal "${COMET_BLND_WEIGHT}" "${blnd_weight}" "Comet BLND weight"
    assert_equal "${COMET_USDC_WEIGHT}" "${usdc_weight}" "Comet USDC weight"
    assert_equal "${controller}" "$(normalize_scalar "$(invoke_view \
        "query-comet-controller" "${comet}" get_controller)")" "Comet controller"
    total_supply="$(normalize_scalar "$(invoke_view \
        "query-comet-total-supply" "${comet}" get_total_supply)")"
    blnd_balance="$(normalize_scalar "$(invoke_view \
        "query-comet-blnd-balance" "${comet}" get_balance --token "${blnd}")")"
    usdc_balance="$(normalize_scalar "$(invoke_view \
        "query-comet-usdc-balance" "${comet}" get_balance --token "${usdc}")")"
    if [[ "${verify_initial_balances}" == "true" ]]; then
        assert_equal "${COMET_INITIAL_LP_SUPPLY}" "${total_supply}" "Comet LP supply"
        assert_equal "${COMET_BLND_BALANCE}" "${blnd_balance}" "Comet BLND reserve"
        assert_equal "${COMET_USDC_BALANCE}" "${usdc_balance}" "Comet USDC reserve"
    else
        [[ "${total_supply}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet LP supply is not positive"
        [[ "${blnd_balance}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet BLND reserve is not positive"
        [[ "${usdc_balance}" =~ ^[1-9][0-9]*$ ]] ||
            die "Comet USDC reserve is not positive"
    fi
    verify_non_clawbackable_sac_balance \
        "verify-comet-blnd-custody" "${blnd}" "${comet}"
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
    local blnd usdc emitter comet backstop recipient initial_recipient emissions_enabled
    local lp_recipient lp_balance
    blnd="$(state_value blnd_token)"
    usdc="$(state_value usdc_token)"
    emitter="$(state_value emitter)"
    comet="$(state_value comet_blnd_usdc)"
    backstop="$(state_value backstop)"
    initial_recipient="$(state_value emitter_initial_backstop)"
    emissions_enabled="$(state_optional emissions_enabled)"
    emissions_enabled="${emissions_enabled:-false}"

    require_existing_blnd "${blnd}" "$(state_value blnd_issuer)"
    verify_comet "${comet}" "$(state_value comet_controller)" \
        "${blnd}" "${usdc}" "${verify_initial_balances}"
    assert_equal "${emitter}" "$(normalize_scalar "$(invoke_view \
        "query-blnd-admin" "${blnd}" admin)")" "BLND administrator"
    recipient="$(normalize_scalar "$(invoke_view \
        "query-emitter-backstop" "${emitter}" get_backstop)")"
    if [[ "${emissions_enabled}" == "true" ]]; then
        assert_equal "${backstop}" "${recipient}" "emitter backstop"
    elif [[ "${recipient}" != "${initial_recipient}" && "${recipient}" != "${backstop}" ]]; then
        die "emitter targets neither its recorded initial backstop nor V2.1"
    fi
    assert_equal "${comet}" "$(normalize_scalar "$(invoke_view \
        "query-backstop-token" "${backstop}" backstop_token)")" "backstop LP token"
    if [[ "${verify_initial_balances}" == "true" ]]; then
        lp_recipient="$(state_value comet_lp_recipient)"
        lp_balance="$(normalize_scalar "$(invoke_view \
            "query-comet-lp-recipient-balance" "${comet}" balance \
            --id "${lp_recipient}")")"
        assert_equal "${COMET_INITIAL_LP_SUPPLY}" "${lp_balance}" \
            "initial Comet LP recipient balance"
    fi
    verify_testnet_v21_pool_deployment
}

command_plan() {
    local blnd_description
    if [[ "${NETWORK_MODE}" == "local" ]]; then
        blnd_description="deploy a local BLND and legacy-emitter fixture"
    else
        blnd_description="reuse BLND ${EXTERNAL_BLND} and its existing emitter"
    fi
    cat <<EOF
Blend v2.1 ${NETWORK_LABEL} deployment

  1. Fetch and hash-check the official unchanged V2.0.0 release WASMs and
     build Comet v1.1 with its pinned toolchain.
  2. ${blnd_description}. On testnet, reuse TestnetV2's existing XLM, USDC,
     wETH, and wBTC assets and its existing SEP-40 oracle.
  3. Initialize one seven-decimal 80:20 BLND:USDC Comet v1.1 LP with 600 BLND
     and 6 USDC, transfer all 100 initial LP shares to ${FUNDING_WALLET}, then
     permanently lock its empty controller account.
  4. Predict the backstop address and deploy the unchanged V2 factory and
     backstop bound to the existing BLND asset, existing V1 emitter, and new LP.
  5. Deploy the single TestnetV2.1 pool with the live TestnetV2 pool settings,
     reserve order, reserve configurations, assets, and oracle. Leave it
     admin-on-ice, outside the reward zone, and with an unfunded backstop.
  6. Verify every token, LP, emitter, pool, oracle, and custody binding and save
     transaction evidence under ${WORK_DIR}.

The user funds the TestnetV2.1 backstop after deployment. Pool activation,
reward-zone enrollment, legacy backfill accounting, and the normal V1-emitter
upgrade are deliberately outside this deployment step.

The plan, validation, and status commands submit no transactions.
EOF
}

command_validate() {
    validate_build_tools
    build_artifacts
    validate_artifacts
    note "Validated unchanged V2, Comet v1.1, and test-oracle artifacts."
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
    local operator controller blnd blnd_issuer blnd_source usdc usdc_issuer weth wbtc xlm oracle
    local lp_recipient
    local emitter initial_backstop comet pool_hash backstop factory deployed_backstop

    validate_build_tools
    [[ ! -e "${STATE_FILE}" ]] ||
        die "state already exists at ${STATE_FILE}; refusing to overwrite it"
    if [[ "${NETWORK_MODE}" == "testnet" ]]; then
        require_funding_wallet_access
        blnd_source="$(blnd_source_stellar_cli keys public-key "${BLND_SOURCE_IDENTITY}")" ||
            die "BLND source identity is unavailable: ${BLND_SOURCE_IDENTITY}"
        require_blnd_source_access "${blnd_source}"
    fi
    require_network
    if [[ "${skip_build}" != "true" ]]; then
        build_artifacts
    fi
    validate_artifacts

    mkdir -p "${CONFIG_DIR}"
    operator="$(ensure_identity "${OPERATOR_IDENTITY}")"
    controller="$(ensure_identity "${CONTROLLER_IDENTITY}")"
    fund_and_wait_for_account "${operator}"
    fund_and_wait_for_account "${controller}"
    [[ "${operator}" != "${controller}" ]] ||
        die "operator and Comet controller must be distinct accounts"
    new_run_dir
    initialize_state "${operator}" "${controller}"
    record_deployment_inputs

    if [[ "${NETWORK_MODE}" == "local" ]]; then
        blnd="$(deploy_asset "deploy-blnd" BLND "${operator}")"
        blnd_issuer="${operator}"
        blnd_source="${operator}"
        usdc_issuer="${operator}"
        usdc="$(deploy_asset "deploy-usdc" USDC "${usdc_issuer}")"
        weth="$(deploy_asset "deploy-weth" wETH "${operator}")"
        wbtc="$(deploy_asset "deploy-wbtc" wBTC "${operator}")"
        lp_recipient="${operator}"
    else
        blnd="${EXTERNAL_BLND}"
        blnd_issuer="${EXTERNAL_BLND_ISSUER}"
        require_existing_blnd "${blnd}" "${blnd_issuer}"
        usdc="${EXTERNAL_TESTNET_USDC}"
        usdc_issuer="${EXTERNAL_TESTNET_USDC_ISSUER}"
        weth="${EXTERNAL_TESTNET_WETH}"
        wbtc="${EXTERNAL_TESTNET_WBTC}"
        oracle="${EXTERNAL_TESTNET_ORACLE}"
        lp_recipient="${FUNDING_WALLET}"
    fi
    state_set "blnd_token" "${blnd}"
    state_set "blnd_issuer" "${blnd_issuer}"
    state_set "blnd_liquidity_source" "${blnd_source}"
    state_set "usdc_token" "${usdc}"
    state_set "usdc_issuer" "${usdc_issuer}"
    state_set "weth_token" "${weth}"
    state_set "wbtc_token" "${wbtc}"
    xlm="$(resolve_native_asset "resolve-native-xlm")"
    state_set "xlm_token" "${xlm}"
    state_set "funding_wallet" "${FUNDING_WALLET}"
    state_set "comet_lp_recipient" "${lp_recipient}"
    if [[ "${NETWORK_MODE}" == "testnet" ]]; then
        state_set "pool_oracle" "${oracle}"
        assert_equal "USDC" "$(normalize_scalar "$(invoke_view \
            "verify-testnet-v2-usdc-symbol" "${usdc}" symbol)")" \
            "TestnetV2 USDC symbol"
        assert_equal "wETH" "$(normalize_scalar "$(invoke_view \
            "verify-testnet-v2-weth-symbol" "${weth}" symbol)")" \
            "TestnetV2 wETH symbol"
        assert_equal "wBTC" "$(normalize_scalar "$(invoke_view \
            "verify-testnet-v2-wbtc-symbol" "${wbtc}" symbol)")" \
            "TestnetV2 wBTC symbol"
        validate_live_testnet_v2_source
    fi

    create_trustline "trust-controller-blnd" \
        "${CONTROLLER_IDENTITY}" "BLND:${blnd_issuer}"
    create_trustline "trust-controller-usdc" \
        "${CONTROLLER_IDENTITY}" "USDC:${usdc_issuer}"

    comet="$(deploy_wasm "deploy-comet-v11" "${COMET_WASM}" "")"
    state_set "comet_blnd_usdc" "${comet}"

    fund_controller_blnd "${blnd}" "${controller}" \
        "${COMET_BLND_BALANCE}" "${blnd_source}"
    fund_controller_usdc "${usdc}" "${controller}" "${COMET_USDC_BALANCE}"
    invoke_transaction_as "initialize-comet-v11" "${CONTROLLER_IDENTITY}" \
        "${comet}" init \
        --controller "${controller}" \
        --tokens "[\"${blnd}\",\"${usdc}\"]" \
        --weights "[\"${COMET_BLND_WEIGHT}\",\"${COMET_USDC_WEIGHT}\"]" \
        --balances "[\"${COMET_BLND_BALANCE}\",\"${COMET_USDC_BALANCE}\"]" \
        --swap_fee "${COMET_SWAP_FEE}" >/dev/null
    state_set "comet_initialized" "true"
    invoke_transaction_as "transfer-initial-comet-lp" "${CONTROLLER_IDENTITY}" \
        "${comet}" transfer \
        --from "${controller}" --to "${lp_recipient}" \
        --amount "${COMET_INITIAL_LP_SUPPLY}" >/dev/null
    state_set "comet_lp_transferred" "true"
    verify_comet_controller_empty "${blnd}" "${usdc}" "${controller}"
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
        "{\"backstop\":\"${backstop}\",\"blnd_id\":\"${blnd}\",\"pool_hash\":\"${pool_hash}\"}")"
    state_set "pool_wasm_hash" "${pool_hash}"
    state_set "pool_factory" "${factory}"
    state_set "backstop" "${backstop}"

    if [[ "${NETWORK_MODE}" == "local" ]]; then
        emitter="$(deploy_wasm "deploy-local-v1-emitter" "${V1_EMITTER_WASM}" "")"
        initial_backstop="${operator}"
        invoke_transaction "initialize-local-emitter" "${emitter}" initialize \
            --blnd_token "${blnd}" \
            --backstop "${initial_backstop}" \
            --backstop_token "${comet}" >/dev/null
        invoke_transaction "set-local-emitter-as-blnd-admin" \
            "${blnd}" set_admin --new_admin "${emitter}" >/dev/null
    else
        emitter="$(resolve_testnet_emitter "${blnd}")"
        initial_backstop="${EXTERNAL_BLEND_BACKSTOP}"
    fi
    state_set "emitter" "${emitter}"
    state_set "emitter_initial_backstop" "${initial_backstop}"
    assert_equal "${emitter}" "$(normalize_scalar "$(invoke_view \
        "verify-blnd-admin" "${blnd}" admin)")" "BLND administrator"
    deployed_backstop="$(deploy_wasm "deploy-v2-backstop" \
        "${V2_BACKSTOP_WASM}" "${BACKSTOP_SALT}" \
        --backstop_token "${comet}" \
        --emitter "${emitter}" \
        --blnd_token "${blnd}" \
        --usdc_token "${usdc}" \
        --pool_factory "${factory}" \
        --drop_list '[]')"
    assert_equal "${backstop}" "${deployed_backstop}" "predicted backstop address"
    state_set "backstop_deployed" "true"

    deploy_testnet_v21_pool "${factory}" "${backstop}" "${operator}"
    state_set "pool_deployed" "true"
    verify_deployment
    state_set "phase" "verified"
    state_set "verified_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    stellar_cli ledger latest \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --output json-formatted >"${RUN_DIR}/ledger-after-deploy.json"
    note "Blend v2.1 TestnetV2.1 deployment verified. State: ${STATE_FILE}"
}

command_resume() {
    local operator factory backstop
    validate_runtime_tools
    require_network
    load_state
    assert_equal "deploying" "$(state_value phase)" "deployment phase"
    validate_artifacts
    operator="$(state_value operator)"
    factory="$(state_value pool_factory)"
    backstop="$(state_value backstop)"
    deploy_testnet_v21_pool "${factory}" "${backstop}" "${operator}"
    state_set "pool_deployed" "true"
    verify_deployment
    state_set "phase" "verified"
    state_set "verified_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    stellar_cli ledger latest \
        --rpc-url "${RPC_URL}" \
        --network-passphrase "${NETWORK_PASSPHRASE}" \
        --output json-formatted >"${RUN_DIR}/ledger-after-deploy.json"
    note "Blend v2.1 TestnetV2.1 deployment resumed and verified. State: ${STATE_FILE}"
}

command_activate_pool() {
    local pool backstop emitter initial_recipient recipient status reward pool_data shares tokens
    validate_runtime_tools
    require_network
    load_state
    assert_equal "verified" "$(state_value phase)" "deployment phase"
    assert_equal "${TESTNET_V2_FIXTURE_SHA256}" \
        "$(sha256_file "${TESTNET_V2_FIXTURE}")" \
        "designated TestnetV2 fixture hash"
    validate_testnet_v2_fixture
    pool="$(state_value pool)"
    backstop="$(state_value backstop)"
    emitter="$(state_value emitter)"
    initial_recipient="$(state_value emitter_initial_backstop)"

    if [[ "$(state_optional pool_activation_pending)" == "false" ]]; then
        verify_deployment false
        note "TestnetV2.1 is already active for borrowing and in the reward zone."
        return
    fi

    recipient="$(normalize_scalar "$(invoke_view \
        "activate-query-emitter-backstop" "${emitter}" get_backstop)")"
    assert_equal "${initial_recipient}" "${recipient}" \
        "emitter backstop before legacy backfill activation"

    pool_data="$(invoke_view "activate-query-pool-backstop-data" \
        "${backstop}" pool_data --pool "${pool}")"
    shares="$(printf '%s' "${pool_data}" | jq -er '.shares | tostring')"
    tokens="$(printf '%s' "${pool_data}" | jq -er '.tokens | tostring')"
    [[ "${shares}" =~ ^[1-9][0-9]*$ ]] ||
        die "TestnetV2.1 backstop has no deposited shares"
    [[ "${tokens}" =~ ^[1-9][0-9]*$ ]] ||
        die "TestnetV2.1 backstop has no deposited LP tokens"

    status="$(invoke_view "activate-query-pool-status" "${pool}" get_config |
        jq -er '.status | tostring')"
    if [[ "${status}" != "0" ]]; then
        assert_equal "2" "${status}" "TestnetV2.1 pre-activation status"
        invoke_transaction "activate-testnet-v21-borrowing" \
            "${pool}" set_status --pool_status 0 >/dev/null
    fi

    invoke_transaction "configure-testnet-v21-emissions" \
        "${pool}" set_emissions_config \
        --res_emission_metadata "$(jq -c '.pool.emissions' "${TESTNET_V2_FIXTURE}")" \
        >/dev/null

    reward="$(invoke_view "activate-query-reward-zone" "${backstop}" reward_zone)"
    if printf '%s' "${reward}" | jq -e 'length == 0' >/dev/null; then
        invoke_transaction "activate-testnet-v21-reward-zone" \
            "${backstop}" add_reward --to_add "${pool}" --to_remove null >/dev/null
    else
        printf '%s' "${reward}" | jq -e --arg pool "${pool}" \
            'length == 1 and .[0] == $pool' >/dev/null ||
            die "unexpected V2.1 reward-zone contents"
    fi

    ensure_backstop_emissions_checkpoint "${backstop}"
    state_mark_pool_activated
    verify_deployment false
    note "TestnetV2.1 borrowing and reward-zone activation verified."
}

command_enable_emissions() {
    local emitter backstop recipient
    validate_runtime_tools
    require_network
    load_state
    assert_equal "verified" "$(state_value phase)" "deployment phase"
    if [[ "$(state_optional emissions_enabled)" == "true" ]]; then
        verify_deployment false
        note "V2.1 emissions are already enabled."
        return
    fi
    assert_equal "true" "$(state_value backfill_enabled)" \
        "V2.1 legacy backfill activation"
    emitter="$(state_value emitter)"
    backstop="$(state_value backstop)"
    recipient="$(normalize_scalar "$(invoke_view \
        "enable-query-emitter-backstop" "${emitter}" get_backstop)")"
    assert_equal "${backstop}" "${recipient}" \
        "emitter backstop after the normal upgrade"
    ensure_backfill_drop "${backstop}"
    ensure_backstop_emissions_checkpoint "${backstop}"
    state_set "emissions_transition_completed" "true"
    state_mark_emissions_enabled
    verify_deployment false
    note "V2.1 backfill was dropped and normal BLND emissions are enabled."
}

command_status() {
    validate_runtime_tools
    require_network
    load_state
    verify_deployment false
    jq '{network_label, phase, verified_at, operator, comet_controller,
         blnd_token, blnd_issuer, blnd_liquidity_source, usdc_token,
         weth_token, wbtc_token, xlm_token, emitter, emitter_initial_backstop,
         comet_blnd_usdc, comet_lp_recipient, pool_factory, backstop,
         pool_oracle, pool, funding_wallet,
         backstop_deployed, pool_deployed, pool_backstop_funded,
         pool_activation_pending, backfill_enabled,
         backfill_active, backfill_drop_completed, emissions_transition_completed, emissions_enabled,
         emissions_enabled_at}' "${STATE_FILE}"
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
        activate-pool) command_activate_pool ;;
        enable-emissions) command_enable_emissions ;;
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
