# Blend v2.1 migration system specification

Normative terms `MUST`, `MUST NOT`, `SHOULD`, and `MAY` are acceptance
criteria.

## Scope

This repository MUST deploy and verify a fresh Blend v2.1 stack on localnet or
Stellar public testnet. The stack consists of:

- the BLNT backfill contract with the committed 74 million BLNT claimant list
  and an empty contributor-grant list;
- a new instance of the exact committed upstream V1 emitter WASM configured
  for BLNT;
- the official unchanged V2.0.0 backstop, pool-factory, and pool release WASMs,
  with their upstream source tracked by the Blend V2 `main` checkout;
- a seven-decimal BLNT Stellar Asset Contract created from a dedicated classic
  issuer, administered by the emitter, and backed by an irreversibly locked
  issuer account;
- a seven-decimal USDC fixture Stellar Asset Contract; and
- one Comet v1.1 pool containing exactly BLNT and USDC at normalized 80:20
  weights.

Public-testnet BLND-to-BLNT conversion MUST bind the existing legacy BLND
Stellar Asset Contract. Localnet MAY deploy an isolated legacy BLND fixture.
The runner MUST NOT deploy or mutate a legacy Blend protocol stack.

The migration repository MUST track V1 and V2 source directly through the
`blend-capital/blend-contracts` and `blend-capital/blend-contracts-v2`
submodules. It MUST NOT depend on a V2.1 contract fork. The runner MUST verify
the committed V1 emitter WASM hash before deployment. It MUST fetch the three
official V2.0.0 backstop, pool-factory, and pool release WASMs built with
Stellar CLI 22.0.1 and MUST reject any artifact whose SHA-256 differs from the
fixed expected hash. It MUST NOT rebuild those deployment artifacts locally.

Localnet and public-testnet deployments MAY execute from a modified migration
repository worktree so runner changes can be exercised before commit. Worktree
cleanliness is therefore not a deployment precondition. Regardless of source
state, the runner MUST reject any backfill or Comet build whose SHA-256 differs
from its designated hash, just as it rejects mismatched V1 emitter and official
V2 release WASMs. No contract WASM with an undesignated hash may be deployed.

## Initial BLNT allocation

While the dedicated BLNT issuer still controls minting, the standard deployment
MUST mint exactly 125,000,000 BLNT directly to the deployed backfill contract.
It MUST verify that balance before marking the deployment complete. The v2.1
backstop constructor drop list MUST be empty, and the standard deployment MUST
NOT call `emitter.drop` or `backstop.drop` for this allocation.

The backfill constructor MUST receive:

- the committed claimant list totaling exactly 74,000,000 BLNT;
- an empty contributor-grant list totaling zero BLNT; and
- immutable conversion capacity of 51,000,000 BLNT.

Thus the single 125,000,000 BLNT premint MUST equal all backfill liabilities:
74,000,000 + 0 + 51,000,000. No independent 125 million allocation exists for
the protocol contracts.

## Backstop asset

The v2.1 backstop token MUST be an initialized Comet v1.1 LP with:

- token order `[BLNT, USDC]`;
- normalized weights `[8,000,000, 2,000,000]`;
- seven token decimals;
- positive total LP supply and positive custody of both reserve assets;
- authorized, non-clawbackable SAC custody entries for both reserve assets;
  and
- a controller account irreversibly locked at thresholds 100/100/100 with
  master weight zero after initialization.

The deployment runner, rather than the backstop contract, MUST enforce these
LP requirements before marking a deployment verified. It MUST reject any
colliding LP, BLNT, or USDC addresses and any deauthorized or clawbackable
BLNT or USDC custody entry held by the LP.

The backstop's legacy-named `blnd_token` constructor field MUST bind BLNT. That
name is retained only for v2 ABI and storage compatibility.

## Ordering and authority

The deployment MUST predict the backstop address before deployment. The pool
factory and emitter MUST bind that predicted address. The unchanged V1
emitter's initialization is permissionless, so the runner MUST deploy it only
after all prerequisites are ready and MUST initialize it in the immediately
following transaction. BLNT administration MUST be transferred to the emitter
only after the backfill premint, Comet seed mint, and successful emitter
initialization are complete.

The BLNT issuer MUST be distinct from the deployment operator and Comet
controller and MUST begin as a clean account with one signer and an empty home
domain. The deployment MAY set a validated, at-most-32-character DNS hostname
as the issuer home domain before locking it. After verifying the emitter as
BLNT SAC administrator and completing every issuer-authorized mint, the
deployment MUST set the issuer's low, medium, and high thresholds to 88 and its
only signer weight to zero, matching mainnet BLND. It MUST verify those settings,
the configured home domain, and the same disabled authorization, revocation,
immutability, and clawback flags as mainnet BLND from Horizon before marking the
deployment complete. The deployment operator MUST remain usable and MAY issue
the isolated localnet BLND and USDC fixtures.

The emitter and backstop `distribute` entry points MUST both remain
permissionless. The backstop retains its inherited behavior of reading the
emitter checkpoint without invoking the emitter. Operational callers MUST
therefore invoke `emitter.distribute` before `backstop.distribute`. Immediately
after backstop deployment, the runner MUST call `backstop.distribute` once to
initialize its inherited emissions checkpoint.

## Evidence and safety

Every transaction and read-only verification MUST be written to the ignored,
network-specific run directory. Deployment MUST refuse to overwrite an
existing state file. The saved state MUST include source checkout commits for
context, authoritative deployed-artifact release tags and hashes, network
identity, the dedicated BLNT issuer and lock threshold, its configured home
domain, contract IDs, allocation totals, and the final verification phase.

The `plan`, `validate`, and `status` commands MUST NOT submit transactions.
The public-testnet lane MUST use separate ignored signing configuration and
MUST require an explicit `deploy` or `run` command before it submits any
transaction.
