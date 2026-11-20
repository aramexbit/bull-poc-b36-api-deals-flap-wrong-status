#!/usr/bin/env bash
# Reproduce B-36 (M-03 / K-1219): GET /api/v1/deals/{1,2,3} 6x each and compare
# the returned `status` against the on-chain truth at block 119141815
# (chain-truth.txt): deals #1-#3 are OPEN on the HI escrow
# 0xd961cA37e339E14e0D3478383a252E218fe7aa4a. Read-only: plain GETs, no wallet,
# no signature, no transaction.
set -u
BASE="${BASE:-https://www.bull.family}"
OUTDIR="${OUTDIR:-./repro-out}"
mkdir -p "$OUTDIR"
wrong=0
total=0
for id in 1 2 3; do
  for i in 1 2 3 4 5 6; do
    total=$((total + 1))
    f="$OUTDIR/probe-deals${id}_${i}.json"
    curl -sS "$BASE/api/v1/deals/$id" -o "$f"
    status=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('status'))" "$f")
    escrow=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('escrow'))" "$f")
    if [ "$status" = "open" ]; then mark=OK; else mark=WRONG; wrong=$((wrong + 1)); fi
    printf 'deal %s round %s: status=%s escrow=%s -> %s (on-chain truth: open)\n' "$id" "$i" "$status" "$escrow" "$mark"
  done
done
echo "---"
echo "Wrong answers: $wrong/$total (expected 8/18 on 20 Nov 2026 ~21:59 WIB; the API flaps, so a re-run may differ — that IS the bug)"
