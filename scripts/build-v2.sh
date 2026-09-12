#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V1_EMITTER_WASM="${ROOT_DIR}/blend-contracts/blend-contract-sdk/wasm/emitter.wasm"
V1_EMITTER_SHA256="438a5528cff17ede6fe515f095c43c5f15727af17d006971485e52462e7e7b89"
V2_ARTIFACT_DIR="${ROOT_DIR}/.artifacts/blend-contracts-v2/v2.0.0-cli22.0.1"
MAX_WASM_BYTES=120000

fetch_artifact() {
    local name="$1" expected_sha256="$2" url="$3"
    local output="${V2_ARTIFACT_DIR}/${name}.wasm" temporary actual_sha256 size

    if [[ -s "${output}" ]]; then
        actual_sha256="$(shasum -a 256 "${output}")"
        actual_sha256="${actual_sha256%% *}"
        if [[ "${actual_sha256}" == "${expected_sha256}" ]]; then
            printf 'Using verified cached V2 artifact %s.wasm\n' "${name}"
            return
        fi
    fi

    temporary="$(mktemp "${output}.tmp.XXXXXX")"
    if ! curl --fail --location --silent --show-error --retry 3 \
        --output "${temporary}" "${url}"
    then
        rm -f -- "${temporary}"
        printf 'error: failed to download official V2 artifact %s.wasm\n' \
            "${name}" >&2
        exit 1
    fi
    actual_sha256="$(shasum -a 256 "${temporary}")"
    actual_sha256="${actual_sha256%% *}"
    if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
        rm -f -- "${temporary}"
        printf 'error: official V2 %s.wasm hash mismatch: %s\n' \
            "${name}" "${actual_sha256}" >&2
        exit 1
    fi
    size="$(wc -c <"${temporary}")"
    if [[ "${size}" -gt "${MAX_WASM_BYTES}" ]]; then
        rm -f -- "${temporary}"
        printf 'error: official V2 %s.wasm exceeds %s-byte deployment guard\n' \
            "${name}" "${MAX_WASM_BYTES}" >&2
        exit 1
    fi
    mv "${temporary}" "${output}"
    printf 'Downloaded and verified official V2 artifact %s.wasm\n' "${name}"
}

for command in curl shasum; do
    command -v "${command}" >/dev/null 2>&1 || {
        printf 'error: required command not found: %s\n' "${command}" >&2
        exit 1
    }
done
actual_emitter_sha256="$(shasum -a 256 "${V1_EMITTER_WASM}")"
actual_emitter_sha256="${actual_emitter_sha256%% *}"
[[ "${actual_emitter_sha256}" == "${V1_EMITTER_SHA256}" ]] || {
    printf 'error: committed V1 emitter WASM hash mismatch: %s\n' \
        "${actual_emitter_sha256}" >&2
    exit 1
}

mkdir -p "${V2_ARTIFACT_DIR}"
fetch_artifact \
    backstop \
    c1f4502a757e25c611f5a159bc1ab0eef64085adac6c68123dca66e87faffbc2 \
    https://github.com/blend-capital/blend-contracts-v2/releases/download/v2.0.0_backstop_cli22.0.1/backstop_v2.0.0.wasm
fetch_artifact \
    pool_factory \
    31328050548831f63d2b72e37bcfd0bb7371b7907135755dbe09ed434d755ca9 \
    https://github.com/blend-capital/blend-contracts-v2/releases/download/v2.0.0_pool-factory_cli22.0.1/pool-factory_v2.0.0.wasm
fetch_artifact \
    pool \
    a41fc53d6753b6c04eb15b021c55052366a4c8e0e21bc72700f461264ec1350e \
    https://github.com/blend-capital/blend-contracts-v2/releases/download/v2.0.0_pool_cli22.0.1/pool_v2.0.0.wasm
