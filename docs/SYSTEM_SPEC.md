# Blend v2.1 migration system specification

Normative terms `MUST`, `MUST NOT`, `SHOULD`, and `MAY` are acceptance criteria.

## Scope

This repository MUST deploy and verify a fresh Blend V2.1 stack on localnet or Stellar public testnet. The stack consists of:

- the official unchanged V2.0.0 backstop, pool-factory, and pool release WASMs, with their upstream source tracked by the Blend V2 `main` checkout;
- the existing seven-decimal BLND Stellar Asset Contract and its existing V1 emitter on public testnet;
- the existing seven-decimal XLM, USDC, wETH, and wBTC Stellar Asset Contracts used by the public-testnet TestnetV2 pool;
- one Comet v1.1 pool containing exactly BLND and USDC at normalized 80:20 weights;
- the existing SEP-40 oracle used by the public-testnet TestnetV2 pool; and
- one XLM/wETH/wBTC/USDC pool named `TestnetV2.1`, modeled on the TestnetV2 pool displayed by testnet.blend.capital.

The deployment MUST NOT create a replacement emissions asset, deploy an incident-remediation backfill contract, allocate replacement tokens, configure a token conversion, deploy a replacement public-testnet emitter, or mutate the existing Blend V1/V2 stack.

Localnet MAY deploy an isolated BLND and V1-emitter fixture so the public-testnet topology can be exercised without external state. That emitter MUST initially target a distinct legacy fixture address rather than the V2.1 backstop.

## Artifact integrity

The migration repository MUST track V1 and V2 source directly through the `blend-capital/blend-contracts` and `blend-capital/blend-contracts-v2` submodules. The runner MUST verify the committed V1 emitter WASM used by the localnet fixture. It MUST fetch the three official V2.0.0 backstop, pool-factory, and pool release WASMs built with Stellar CLI 22.0.1 and MUST reject artifacts whose SHA-256 differs from the fixed expected hashes. It MUST NOT rebuild those deployment artifacts locally.

Localnet and public-testnet deployments MAY execute from a modified migration worktree. Worktree cleanliness is not a deployment precondition. The runner MUST reject any Comet or test-oracle build whose SHA-256 differs from its designated hash. No contract WASM with an undesignated hash may be deployed.

## Existing BLND and emitter

On public testnet, the runner MUST bind the configured existing BLND contract, verify that it is the canonical Stellar Asset Contract derived from the configured BLND issuer, verify seven decimals and symbol `BLND`, obtain its administrator, and require that administrator to be a V1 emitter contract whose current backstop equals the configured existing Blend backstop. The runner MUST use that same emitter in the new V2.1 backstop constructor.

The runner MUST NOT call the existing emitter's `initialize`, change BLND administration, mint BLND directly, call `emitter.drop` directly, queue an emitter swap, or execute an emitter swap. BLND used for Comet liquidity MUST be transferred from an explicitly configured holder that authenticates the transfer. After the normal swap, the runner MUST use the unchanged backstop's `drop` entry point to request the standard legacy-emissions backfill from the emitter.

## Backstop asset

The V2.1 backstop token MUST be an initialized Comet v1.1 LP with:

- token order `[BLND, USDC]`;
- normalized weights `[8,000,000, 2,000,000]`;
- seven token decimals;
- exactly 600 BLND and 6 USDC in custody at initialization, producing exactly 100 seven-decimal LP shares;
- all 100 initial LP shares transferred from the controller to the configured funding wallet before the controller is locked;
- authorized, non-clawbackable SAC custody entries for both reserve assets; and
- a controller account irreversibly locked at thresholds 100/100/100 with master weight zero after initialization.

The deployment runner, rather than the unchanged backstop contract, MUST enforce these LP requirements. It MUST reject colliding LP, BLND, or USDC addresses and any deauthorized or clawbackable reserve custody entry held by the LP.

The backstop's `blnd_token` constructor field MUST bind the existing BLND contract. Its `emitter` field MUST bind the existing V1 emitter. Its legacy drop list MUST be empty.

## TestnetV2.1 pool and funding wallet

The runner MUST verify the live TestnetV2 source pool before mutation and MUST deploy exactly one pool named `TestnetV2.1`. On public testnet it MUST reuse TestnetV2's XLM, wETH, wBTC, and USDC contracts and oracle. It MUST preserve reserve order `[XLM, wETH, wBTC, USDC]`, backstop take rate 1,000,000, maximum positions 8, minimum collateral zero, and every committed reserve risk parameter.

The initial deployment MUST leave TestnetV2.1 admin-on-ice, outside the reward zone, without an emissions configuration, and with zero backstop shares. It MUST NOT activate or seed the pool. The configured wallet MUST receive all 100 initial Comet LP shares so the user can fund the backstop separately.

The runner MUST NOT mutate TestnetV2's oracle. A localnet mirror MAY deploy an authenticated test oracle with the same asset set, decimals, and 300-second resolution.

## Intentional legacy-emissions backfill

The initial deployment MUST NOT start legacy-emissions accounting. After the user funds the backstop, a separate activation step MUST:

- activate TestnetV2.1 only after the unchanged V2 threshold check succeeds;
- make TestnetV2.1 the sole reward-zone member and configure the TestnetV2 emission split;
- call `backstop.distribute` to initialize the unchanged V2 legacy-backfill clock;
- run the keeper to advance `backstop.distribute` and `pool.gulp_emissions` without mutating the reused oracle; and
- omit `emitter.distribute`, `emitter.drop`, and `backstop.drop`.

This is the unchanged V2 backfill mechanism, not an incident-remediation token backfill. After activation it accrues one BLND per second up to the contract's 10 million BLND cap while the emitter does not recognize V2.1. TestnetV2.1 participants before the swap MUST remain eligible for their share. The accounting is allocated through the backstop and pool, but the BLND is not minted into V2.1 until the post-swap `backstop.drop` succeeds.

V2.1 MUST NOT receive any other one-time BLND allocation. The emitter swap itself MUST NOT mint or allocate BLND to V2.1. The only permitted one-time BLND mint for V2.1 is the unchanged post-swap legacy-emissions `backstop.drop`, which MUST mint exactly the accrued backfill amount, MUST NOT exceed 10 million BLND, and MUST include no legacy drop-list allocation. Normal ongoing BLND emissions after the swap are separate from this one-time backfill mint.

## Normal emitter upgrade and emissions activation

V2.1 MUST receive BLND emissions only through the unchanged V1 emitter's normal `queue_swap_backstop` and `swap_backstop` lifecycle. The migration deployment MUST NOT bypass or pre-complete that process.

The legacy V1 emitter compares balances of its current backstop token when evaluating a candidate. Therefore, the new BLND:USDC Comet v1.1 LP does not satisfy the upgrade threshold. Supporters of the V2.1 candidate must place more of the emitter's current backstop LP token at the deployed V2.1 backstop address than is held at the incumbent backstop, queue the swap with the V2.1 backstop and new Comet LP addresses, maintain the balance condition through the 31-day queue period, and then execute the permissionless swap. Those incumbent LP tokens are separate from the new Comet LP deposits accounted by the V2.1 backstop.

Only after `emitter.get_backstop()` equals the V2.1 backstop MAY the runner enable normal emissions. It MUST then:

1. call `backstop.drop` to mint the accumulated legacy backfill through the unchanged emitter, or verify that the drop has already completed;
2. call `backstop.distribute` to transition from backfill accounting to normal emitter accounting, or accept the contract's recent-distribution error if another caller already completed the transition; and
3. atomically record that the backfill is inactive and normal emissions are enabled.

Finalization MUST be safe to retry after any submitted transaction and MUST NOT assume it is the first caller or require a particular zero result from `backstop.distribute`. A pre-swap keeper MUST stop when it observes that the emitter already targets V2.1 but local activation state is incomplete. After activation, the keeper MUST verify the emitter recipient and TestnetV2.1 reward-zone membership before calling `emitter.distribute`, `backstop.distribute`, and `pool.gulp_emissions` in that order. On public testnet it MUST reuse the external oracle without attempting to update it.

## Evidence and safety

Every transaction and read-only verification MUST be written to the ignored network-specific run directory. Deployment MUST refuse to overwrite an existing state file. The saved state MUST include source checkout commits, authoritative release tags and hashes, network identity, existing BLND and emitter bindings, the BLND liquidity source, contract IDs, Comet funding, emission-activation state, and the final verification phase.

Public-testnet deployment MUST require explicit funding-wallet signer configuration. Before generating deployment identities, requesting account funding, creating deployment state, or submitting transactions, the runner MUST verify that the configured wallet identity resolves to the expected funding-wallet address and that the configured BLND source identity is available. A separate BLND source MAY be configured; otherwise it MUST inherit the funding-wallet signer configuration.

The `plan`, `validate`, and `status` commands MUST NOT submit transactions. State files from incompatible earlier deployment topologies MUST NOT be resumed as V2.1 deployments. A new deployment MUST use a fresh state file.
