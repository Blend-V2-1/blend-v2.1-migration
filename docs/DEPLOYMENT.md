# Blend v2.1 deployment runbook

The deployment runner follows an ordered, evidence-producing workflow while retaining the existing BLND asset and V1 emitter.

## Toolchains

- `blend-contracts`: the exact committed V1 emitter WASM, used only for the isolated localnet legacy fixture.
- `blend-contracts-v2`: the official V2.0.0 backstop, pool-factory, and pool release WASMs built with Stellar CLI 22.0.1. The runner downloads and verifies their fixed SHA-256 hashes instead of rebuilding them. Rust 1.81.0 is needed only when running the upstream V2 source tests through `make test`.
- `comet-contracts-v1.1`: its pinned Rust 1.92.0 / SDK 25 toolchain.
- `test-sep40-oracle`: its pinned Rust 1.91.1 / SDK 27 toolchain, used only by the localnet mirror. Public testnet reuses TestnetV2's existing oracle.
- deployment and verification: Stellar CLI major version 27.

Verified V2 artifacts are cached below ignored `.artifacts/`. A valid cached copy can be reused offline; an absent or invalid copy is downloaded again and must pass hash verification before replacing the cache.

The runner also fixes designated hashes for the locally built Comet and test-oracle WASMs. Localnet and testnet runs may use uncommitted migration-runner changes, but every deployed contract artifact must match its designated hash.

## Launch topology

Public testnet reuses the existing BLND Stellar Asset Contract. The runner verifies its address against the configured BLND issuer, reads the contract administrator to identify the existing V1 emitter, and verifies that the emitter still targets the configured existing Blend backstop. It neither deploys nor initializes a replacement emitter and never changes BLND administration.

The new Comet pool is initialized with 600 BLND and 6 of TestnetV2's existing USDC for exactly 100 LP shares. The controller transfers all 100 shares to the configured funding wallet and is verified empty before its key is permanently locked. The deployment does not deposit those shares into the Blend backstop; the user funds the backstop separately.

On public testnet, the runner cannot mint BLND. Explicitly configure a wallet that holds both the required BLND and TestnetV2 USDC and can authenticate their transfers:

```sh
BLEND_V21_WALLET_CONFIG_DIR=/path/to/stellar-config \
BLEND_V21_WALLET_IDENTITY=my-testnet-wallet \
make testnet-deploy
```

The wallet requires at least 600 BLND and 6 TestnetV2 USDC. The BLND source config and identity default to the wallet values; set `BLEND_V21_BLND_SOURCE_CONFIG_DIR` and `BLEND_V21_BLND_SOURCE_IDENTITY` as well when a separate account supplies BLND. Before creating local identities, requesting Friendbot funds, writing deployment state, or submitting transactions, the runner requires these settings and verifies that the wallet identity resolves to the configured funding-wallet address. The BLND source public key is recorded in deployment state.

The runner verifies the live TestnetV2 source pool before submitting deployment transactions. It reuses that pool's XLM, USDC, wETH, and wBTC contracts and SEP-40 oracle, and pins its pool and reserve configuration in `fixtures/testnet-v2.json`. It then uploads the unchanged V2 pool WASM, predicts the V2.1 backstop address, deploys the unchanged pool factory and backstop, and deploys one `TestnetV2.1` pool. The pool is left admin-on-ice, outside the reward zone, and with zero backstop shares.

## Legacy V2 backfill before the upgrade

The pre-swap backfill is intentional, but it does not begin during the initial unfunded deployment. After the user funds the TestnetV2.1 backstop, the administrator can activate the pool, make it the reward-zone member, configure the TestnetV2 emission split, and checkpoint the unchanged V2 backstop. From that point, while the existing emitter still targets the incumbent backstop, the unchanged V2 backstop accounts for legacy emissions at one BLND per second, capped at 10,000,000 BLND. The accounted BLND is not minted into V2.1 until the emitter swap completes and `backstop.drop` succeeds.

Run the retry-safe activation after the deposited Comet LP clears the unchanged V2 threshold:

```sh
make testnet-activate-pool
make testnet-keeper-once
make testnet-keeper
```

During that later phase the keeper reuses the externally maintained TestnetV2 oracle, calls `backstop.distribute`, and calls `pool.gulp_emissions`. It deliberately does not call `emitter.distribute`, because that would advance emissions for the incumbent backstop rather than V2.1. Keep the scheduled keeper running throughout the pre-swap period. Immediately before `swap_backstop`, stop the scheduled keeper and run one final `make testnet-keeper-once` pass so the stored backfill includes all emissions accrued through that checkpoint.

## Normal Blend emitter upgrade

The normal V1 emitter upgrade is a separate public process. Its candidate-size check uses the emitter's current backstop LP token, not the new Comet v1.1 LP. To nominate V2.1, supporters must transfer enough of the incumbent backstop LP token to the deployed V2.1 backstop address to exceed the incumbent backstop's balance, call `queue_swap_backstop` with that address and the new Comet LP, maintain the balance condition for 31 days, and call `swap_backstop` after unlock.

The migration runner does not queue or execute this swap. After the swap is complete and `get_backstop` returns the V2.1 backstop, enable emissions with:

```sh
make testnet-enable-emissions
```

Stop the pre-swap keeper before running this command. The command verifies the emitter target, completes the one-time `backstop.drop` that mints the accumulated legacy backfill, and calls `backstop.distribute` to transition to normal emitter accounting. Both steps are retry-safe: an already-completed drop or a recent/already-completed distribution is accepted rather than requiring the caller to observe a particular zero result.

After finalization, run one keeper pass or restart the scheduled loop. The keeper now calls `emitter.distribute`, `backstop.distribute`, and `pool.gulp_emissions` in order:

```sh
make testnet-keeper-once
make testnet-keeper
```

## Localnet

```sh
make localnet-plan
make localnet-validate
make localnet-run
make localnet-status
make localnet-stop
```

Localnet uses an isolated Protocol 27 Quickstart network. It deploys local BLND, USDC, wETH, and wBTC SACs, an unchanged V1 emitter, and a controlled oracle as mirrors of the public-testnet dependencies. The fixture emitter initially targets a distinct legacy address.

## Public testnet

```sh
make testnet-plan
make testnet-validate
make testnet-start
make testnet-deploy
make testnet-status
make testnet-activate-pool
make testnet-keeper-once
make testnet-keeper
# Immediately before the swap, stop the scheduled keeper and run:
make testnet-keeper-once
# After completing the normal emitter swap:
make testnet-enable-emissions
```

`testnet-start` only checks network health. `testnet-deploy` is the first public-testnet command that submits transactions and deploys the unfunded candidate. `testnet-keeper` is a foreground scheduled process; stop it, run one final `testnet-keeper-once` checkpoint, and only then execute the external emitter swap. `testnet-enable-emissions` is not applicable until the pool has been separately funded and activated and the recorded emitter points to the deployed V2.1 backstop. By default the runner uses BLND contract `CB22KRA3YZVCNCQI64JQ5WE7UY2VAV7WFLK6A2JN3HEX56T2EDAFO7QF`, incumbent backstop `CBDVWXT433PRVTUNM56C3JREF3HIZHRBA64NB2C3B2UNCKIS65ZYCLZA`, and the assets and oracle pinned from TestnetV2. Override them only after independent verification.

Generated identities, state, transaction output, and cost logs are retained in `.localnet/` or `.testnet/` and ignored by Git. A second deployment is rejected while the matching `state.json` exists. State from an incompatible earlier topology cannot be resumed; use a fresh state file for this deployment.

On public testnet the explicitly configured wallet contributes 600 BLND and 6 TestnetV2 USDC to initialize Comet and receives the 100 resulting LP shares. No asset is minted or faucet-funded by this deployment.
