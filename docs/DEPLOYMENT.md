# Blend v2.1 deployment runbook

The deployment runner uses the same ordered, evidence-producing pattern as
the v3 migration runner while keeping each repository's pinned build lane.

## Toolchains

- `blend-contracts`: the exact committed V1 emitter WASM; it is not rebuilt or
  modified by the migration repository.
- `blend-contracts-v2`: the official V2.0.0 backstop, pool-factory, and pool
  release WASMs built with Stellar CLI 22.0.1. The runner downloads and verifies
  their fixed SHA-256 hashes instead of rebuilding them. Rust 1.81.0 is needed
  only when running the upstream V2 source tests through `make test`.
- `blnt-backfill-contract`: its pinned Rust 1.91.1 / SDK 27 toolchain.
- `comet-contracts-v1.1`: its pinned Rust 1.92.0 / SDK 25 toolchain.
- deployment and verification: Stellar CLI major version 27.

Verified V2 artifacts are cached below ignored `.artifacts/`. A valid cached
copy can be reused offline; an absent or invalid copy is downloaded again and
must pass hash verification before replacing the cache.

The runner also fixes designated hashes for the locally built backfill and
Comet WASMs. Localnet and testnet runs may use uncommitted migration-runner
changes, but every deployed contract artifact must match its designated hash.
Source commits in deployment state describe the checked-out context; the saved
WASM hashes are the authoritative record of deployed contract code. Updating a
contract requires an explicit review and update of its designated hash.

## Launch funding and emissions

The runner creates a dedicated BLNT issuer distinct from the deployment
operator and Comet controller. While that issuer still controls BLNT, it mints
exactly 125 million BLNT directly to the deployed backfill contract and mints
the BLNT portion of the Comet seed. The operator separately issues the USDC
fixture. The runner then deploys an unchanged V1 emitter, immediately invokes
its legacy `initialize` entry point, and transfers BLNT administration to it
only after initialization succeeds. The unchanged V2 backstop is deployed with
an empty legacy drop list; neither emitter nor backstop `drop` is used for the
launch allocation.

After all issuer-authorized mints and the SAC administrator transfer, the
runner verifies the emitter as administrator and permanently locks the classic
BLNT issuer at mainnet BLND's `88/88/88` thresholds with its only signer weight
set to zero. Final and status verification read the issuer from Horizon and
require that lock plus the same disabled authorization, revocation,
immutability, and clawback flags as mainnet BLND.

The unchanged V1 initializer is permissionless. To minimize its initialization
window, the runner deploys the emitter only after every prerequisite is ready
and initializes it in the immediately following transaction. If initialization
does not bind the expected addresses, deployment stops while the issuer still
controls BLNT. The saved transaction evidence and final emitter-backstop check
detect an incorrect binding, but deployment and initialization remain separate
transactions.

The emitter and backstop retain separate permissionless distribution calls.
For ongoing operation, invoke `emitter.distribute` before
`backstop.distribute`. The deployment runner makes one initial backstop call to
establish its inherited emissions checkpoint.

## Localnet

```sh
make localnet-plan
make localnet-validate
make localnet-run
make localnet-status
make localnet-stop
```

Localnet uses an isolated Protocol 27 Quickstart network and deploys a legacy
BLND fixture only for exercising the backfill contract's immutable binding.

## Public testnet

```sh
make testnet-plan
make testnet-validate
make testnet-start
make testnet-deploy
make testnet-status
```

`testnet-start` only checks network health. `testnet-deploy` is the first
public-testnet command that submits transactions. By default the backfill
contract binds legacy BLND contract
`CB22KRA3YZVCNCQI64JQ5WE7UY2VAV7WFLK6A2JN3HEX56T2EDAFO7QF`; override it only
with the explicit `BLEND_V21_EXTERNAL_BLND` environment variable.

Generated identities, state, transaction output, and cost logs are retained in
`.localnet/` or `.testnet/` and are intentionally ignored by Git. A second
deployment is rejected while the matching `state.json` exists.

Override the dedicated issuer identity name with
`BLEND_V21_BLNT_ISSUER_IDENTITY` when required. The supplied identity MUST be a
clean account with default thresholds, exactly one signer of weight one, an
empty home domain, and no authorization, revocation, immutability, or clawback
flags; the runner rejects any other configuration before deploying BLNT.

## Optional BLNT asset metadata

Set the issuer home domain during deployment with the same variable used by the
v3 migration:

```sh
BLEND_BLNT_HOME_DOMAIN=blent.trade make testnet-deploy
```

The value MUST be a DNS hostname no longer than Stellar's 32-character account
limit. It MUST NOT include a URL scheme, path, port, empty label, or label that
starts or ends with a hyphen. The runner sets it before relinquishing the
issuer key, records it in deployment state, and verifies the exact value from
Horizon after the issuer is locked. When the variable is unset, the home domain
remains empty.

The domain should publish a `stellar.toml` currency entry for `BLNT` whose
`issuer` is the dedicated BLNT issuer recorded in deployment state. Human-
readable token names and icons are metadata hosted by that domain; they are not
stored in the classic asset or SAC.
