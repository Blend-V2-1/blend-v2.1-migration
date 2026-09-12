# Blend v2.1 migration

This repository collects the repositories used for the Blend v2.1 migration as Git submodules.

It also contains the reproducible localnet and public-testnet deployment runner
for the v2.1 launch topology: a new instance of the unchanged V1 emitter
configured for BLNT, the zero-grant 125 million BLNT backfill allocation, an
80:20 BLNT:USDC Comet v1.1 LP, a dedicated BLNT issuer locked to match mainnet
BLND after SAC administration moves to the emitter, and the Blend v2.1 protocol
contracts.

## Included repositories

- [`Blend-V2-1/blnt-backfill-contract`](https://github.com/Blend-V2-1/blnt-backfill-contract)
- [`CometDEX/comet-contracts-v1`](https://github.com/CometDEX/comet-contracts-v1) (upstream `main`, Comet v1.1)
- [`Blend-V2-1/blend-ui`](https://github.com/Blend-V2-1/blend-ui)
- [`Blend-V2-1/blend-sdk-js`](https://github.com/Blend-V2-1/blend-sdk-js)
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

To update every submodule to the latest commit on its configured `main` branch:

```sh
git submodule update --remote --recursive
```

## Build and deployment

Backfill and Comet retain their pinned build toolchains. The three unchanged V2
contracts are fetched from their official V2.0.0 GitHub releases and accepted
only after fixed SHA-256 verification. The V1 emitter is deployed from the
immutable WASM committed in `blend-contracts`. Locally built backfill and Comet
WASMs must also match their designated hashes before deployment:

```sh
make build
make localnet-plan
make testnet-plan
```

Optionally set the dedicated BLNT issuer's metadata domain before its key is
permanently locked:

```sh
BLEND_BLNT_HOME_DOMAIN=blent.trade make testnet-deploy
```

See [the system specification](docs/SYSTEM_SPEC.md) and
[deployment runbook](docs/DEPLOYMENT.md) before running a mutating deployment
command.
