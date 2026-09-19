# Suggested discussion title

Blend V2.1 Proposal — Restore Blend with Comet V1.1 while retaining BLND

# Suggested discussion description

## Summary

Before Blend moves to V3, the immediate problem created by the Comet V1 incident should be addressed. The impaired BLND:USDC LP has left the current backstop unusable and made the normal emitter-upgrade path difficult to exercise. Blend V2.1 is a minimal recovery deployment that restores a healthy backstop without changing the already audited Blend V2 contracts or V1 emitter.

V2.1 would deploy fresh instances of the exact unchanged Blend V2.0.0 backstop, pool-factory, and pool WASMs. It would continue using the existing BLND token and existing V1 emitter and would introduce a corrected seven-decimal 80:20 BLND:USDC Comet V1.1 LP as the new backstop asset. V2.1 would not create BLNT, deploy a token backfill, provide BLND-holder conversion, or address USDC remediation.

## Why V2.1 first

The immediate goal is to get Blend out of the water with the smallest auditable change in deployment topology. Comet V1.1 fixes the liquidity-operation defect while preserving the intended pool behavior, and its liquidity operations are covered by machine-checked verification. Because the Blend contracts themselves remain byte-for-byte unchanged, review can focus on the corrected Comet implementation and reproducible migration orchestration.

Once V2.1 is operating with a healthy backstop, a V3 candidate can proceed through Blend's normal upgrade mechanism rather than combining incident recovery with a larger protocol redesign. This proposal does not replace or prejudge a future V3 proposal.

## Proposed V2.1 deployment

1. Verify the official Blend V2.0.0 backstop, pool-factory, and pool WASMs against pinned release hashes and verify the designated Comet V1.1 WASM.
2. Reuse the existing BLND Stellar Asset Contract and verify that its administrator is the existing V1 emitter and that the emitter still targets the incumbent Blend backstop.
3. Deploy and initialize a corrected Comet V1.1 pool containing existing BLND and USDC at normalized 80:20 weights, verify authorized and non-clawbackable reserve custody, transfer the LP shares out of the controller, and permanently lock the empty controller account.
4. Upload the unchanged Blend V2 pool WASM, predict the V2.1 backstop address, and deploy the unchanged V2 pool factory configured with that address, BLND, and the verified pool WASM hash.
5. Deploy the unchanged V2 backstop at the predicted address, binding it to the new BLND:USDC LP, existing V1 emitter, existing BLND, USDC, and the new pool factory with an empty constructor drop list.
6. Deploy and activate the initial Blend pool or pools, fund their backstop positions with the new Comet LP shares, add them to the reward zone, configure their BLND emission allocations, and begin the unchanged V2 legacy-emissions backfill so pre-swap participants accrue their intended share.
7. Separately transfer sufficient incumbent backstop LP tokens to the V2.1 backstop, queue it through the unchanged V1 emitter with the new Comet LP as its future backstop token, maintain the required support for 31 days, and execute the normal permissionless swap.
8. After the swap, complete the standard backfill drop and transition the backstop to normal BLND emissions.
9. Publish the contract, token, authority, artifact, and custody evidence needed to reproduce and verify the deployment.

## Emissions and the normal upgrade path

V2.1 would use the normal legacy-emissions backfill already present in the unchanged V2 backstop. Before the emitter swap, backstop emission accounting accrues at one BLND per second, capped at 10,000,000 BLND, and is allocated to the active Fixed Pool so participants during the support period are eligible. The accumulated BLND is minted only after the emitter recognizes V2.1 and the backstop completes its standard drop.

To receive ongoing BLND emissions, the deployed V2.1 backstop would still have to complete the existing V1 emitter's normal permissionless backstop-swap process. The emitter compares candidate support using its incumbent backstop LP token, so deposits of the new Comet V1.1 LP do not satisfy that threshold. The V2.1 address must separately hold more incumbent LP than the current backstop, maintain that condition during the 31-day queue, and then execute the swap. Post-swap orchestration would complete the backfill drop and transition to normal emissions without assuming it is the first caller.

## Scope boundaries

- No changes to the already audited Blend V2 contract source or WASMs.
- No changes to the unchanged V1 emitter source or WASM.
- No new emissions token.
- No incident-remediation token backfill or BLND conversion; only the unchanged V2 legacy-emissions backfill.
- No USDC remediation.
- No automatic or privileged emitter migration.

## References

- Migration source code: https://github.com/Blend-V2-1/blend-v2.1-migration
- Testnet interface: https://blnd.trade/

The testnet interface should be treated as representative only after it is updated to a deployment matching this revised proposal.
