# Blend v2.1 migration

This repository collects the repositories used for the Blend v2.1 migration as Git submodules.

It also contains the reproducible localnet and public-testnet deployment runner
for the v2.1 launch topology: a new instance of the unchanged V1 emitter
configured for BLNT, the zero-grant 125 million BLNT backfill allocation, an
80:20 BLNT:USDC Comet v1.1 LP, a dedicated BLNT issuer locked to match mainnet
BLND after SAC administration moves to the emitter, and the unchanged upstream
V2 protocol contracts.

The testnet lane also deploys a controlled mock SEP-40 oracle and a Fixed Pool
modeled on Fixed Pool V2, funds its backstop with all 166,766 Comet LP shares,
and includes an hourly emissions keeper. The configured test wallet receives
1,000,000 each of the newly issued BLNT, USDC, and EURC assets plus 100,000
native XLM.

## Included repositories

- [`Blend-V2-1/blnt-backfill-contract`](https://github.com/Blend-V2-1/blnt-backfill-contract)
- [`CometDEX/comet-contracts-v1`](https://github.com/CometDEX/comet-contracts-v1) (upstream `main`, Comet v1.1)
- [`Blend-V2-1/blend-ui`](https://github.com/Blend-V2-1/blend-ui)
- [`blend-capital/blend-sdk-js`](https://github.com/blend-capital/blend-sdk-js) (upstream `main`)
- [`blend-capital/blend-contracts`](https://github.com/blend-capital/blend-contracts) (upstream `main`, V1 emitter)
- [`blend-capital/blend-contracts-v2`](https://github.com/blend-capital/blend-contracts-v2) (upstream `main`)

## Clone

```sh
git clone --recurse-submodules git@github.com:Blend-V2-1/blend-v2.1-migration.git
```

For an existing checkout:

```sh
git submodule update --init --recursive
```

Submodule commits are intentionally pinned for reproducibility. Do not use
`git submodule update --remote` in a deployment checkout. Advancing a gitlink
is a maintainer operation that requires reviewing the new source and any
affected designated WASM hashes.

## Build and deployment

Backfill and Comet retain their pinned build toolchains. The three unchanged V2
contracts are fetched from their official V2.0.0 GitHub releases and accepted
only after fixed SHA-256 verification. The V1 emitter is deployed from the
immutable WASM committed in `blend-contracts`. Locally built backfill, Comet,
and test-oracle WASMs must also match their designated hashes before deployment:

```sh
make build
make localnet-plan
make testnet-plan
```

After a verified testnet deployment, run one keeper pass or the scheduled
loop with:

```sh
make testnet-keeper-once
make testnet-keeper
```

Optionally set the dedicated BLNT issuer's metadata domain before its key is
permanently locked:

```sh
BLEND_BLNT_HOME_DOMAIN=blnd.trade make testnet-deploy
```

See [the system specification](docs/SYSTEM_SPEC.md) and
[deployment runbook](docs/DEPLOYMENT.md) before running a mutating deployment
command.
