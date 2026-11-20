# PoC for Bull.family bug bounty report B-36

## Deals API flaps: wrong answers vs on-chain state (M-03 / K-1219)

**Report B-36.** On 20 Nov 2026 ~21:59–22:00 WIB, `GET /api/v1/deals/{1,2,3}`
was called 6 times each (18 calls, sequential, all HTTP 200). **8 of the 18
answers were wrong** against the on-chain truth. All 18 raw responses are in
`probes/`, the request log in `probe-log.txt`, the on-chain truth in
`chain-truth.txt`.

### On-chain truth (block 119141815, HI escrow `0xd961cA37e339E14e0D3478383a252E218fe7aa4a`)

Read with `cast call deals(uint256)` on
`https://rpc.mainnet.chain.robinhood.com`, 20 Nov 2026:

| Deal | On-chain status |
|---|---|
| #1 | OPEN |
| #2 | OPEN |
| #3 | OPEN |
| #4 | CANCELLED |
| #5 | SETTLED |
| #6 | NONE (empty) |

### Results: 8/18 wrong

| Call | API status | Escrow in answer | Verdict |
|---|---|---|---|
| deals/1 round 1 | settled | 0xd685d39E… (other escrow) | WRONG |
| deals/1 round 2 | settled | 0xd685d39E… | WRONG |
| deals/1 round 3 | none | 0xd961cA37… (HI) | WRONG |
| deals/1 round 4 | none | 0xd961cA37… | WRONG |
| deals/1 round 5 | open | 0xd961cA37… | OK |
| deals/1 round 6 | settled | 0xd685d39E… | WRONG |
| deals/2 round 1 | none | 0xd961cA37… | WRONG |
| deals/2 round 2 | cancelled | 0xd685d39E… | WRONG |
| deals/2 round 3 | open | 0xd961cA37… | OK |
| deals/2 round 4 | open | 0xd961cA37… | OK |
| deals/2 round 5 | open | 0xd961cA37… | OK |
| deals/2 round 6 | open | 0xd961cA37… | OK |
| deals/3 round 1 | open | 0xd961cA37… | OK |
| deals/3 round 2 | open | 0xd961cA37… | OK |
| deals/3 round 3 | none | 0xd961cA37… | WRONG |
| deals/3 round 4 | open | 0xd961cA37… | OK |
| deals/3 round 5 | open | 0xd961cA37… | OK |
| deals/3 round 6 | open | 0xd961cA37… | OK |

Two distinct failure modes appear: (a) answers served from a *different*
escrow (`0xd685d39E7a3deF19E52B9AB09679b7452C23e20b` — where deal #1 is
settled and #2 cancelled, so the API reports another escrow's deal under
this id), and (b) answers from the correct HI escrow that still say `none`
for deals that are OPEN on-chain. The same id flips between answers seconds
apart with no on-chain change — the API is non-deterministic for the same
query.

### How to reproduce (read-only)

```sh
./reproduce.sh
```

This loops `GET /api/v1/deals/{1,2,3}` 6 times each with plain `curl`,
saves responses under `./repro-out/`, and compares each `status` to the
on-chain truth (`open` for #1–#3). No wallet, signature, or transaction.
Note: the API flaps, so a re-run may show a different wrong-count — that
non-determinism IS the bug. The 8/18 figure above is the captured run in
`probes/` + `probe-log.txt`.

### Honest impact

Misreporting / observability, not direct fund loss: the same deal id
returns `settled`, `cancelled`, `none` or `open` depending on the moment,
so anything that trusts this endpoint (dashboards, agents, users checking
whether a deal is open) can act on a false state. All money paths read the
chain, not this API, so no funds move because of a wrong answer here. The
fix is to pin the API to one escrow (HI) per id and to read deal state from
the chain (or a chain-indexed source) instead of whichever escrow replica
answers first.

### Evidence

- `probes/probe-deals{1,2,3}_{1..6}.json` — all 18 raw API responses, verbatim.
- `probe-log.txt` — timestamped request log (HTTP status + sha256 per call).
- `chain-truth.txt` — on-chain `deals()` state at block 119141815.
- `reproduce.sh` — re-runs the 18-call probe and scores it.
