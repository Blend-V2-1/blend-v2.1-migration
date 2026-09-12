# Blend v2.1 migration

This repository collects the repositories used for the Blend v2.1 migration as Git submodules.

## Included repositories

- [`Blend-V2-1/blend-contracts-v2.1`](https://github.com/Blend-V2-1/blend-contracts-v2.1)
- [`Blend-V2-1/blnt-backfill-contract`](https://github.com/Blend-V2-1/blnt-backfill-contract)
- [`Blend-V2-1/comet-contracts-v1.1`](https://github.com/Blend-V2-1/comet-contracts-v1.1)
- [`Blend-V2-1/blend-ui`](https://github.com/Blend-V2-1/blend-ui)
- [`Blend-V2-1/blend-sdk-js`](https://github.com/Blend-V2-1/blend-sdk-js)
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
