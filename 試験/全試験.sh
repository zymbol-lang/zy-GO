#!/usr/bin/env bash
# ============================================================
# 試験/全試験.sh — run every 囲碁 test suite
#   bash 試験/全試験.sh
# ============================================================
#
# ── NOTE ─────────────────────────────────────────────────────────────────
# This script is not the authority any more. It decides correctness by
# grepping the suite's output for FAIL, so a suite that crashes half way
# through prints no FAIL and passes — that is not hypothetical, it was
# measured. It also runs the tree-walker only.
#
# The gate is in ZyQuality, which compares each suite against a golden (a
# truncated run does not match one) and runs every engine that can:
#
#     cd ../zyquality && ./zyq suite --only project
#     cd ../zyquality && bash project/run.sh --only go
#
# What is still worth running here is the `zymbol check` sweep below, which
# is about this application's own sources.
# ─────────────────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.."

fallo=0
for suite in 試験/文字試験.zy 試験/言語検証.zy 試験/api試験.zy 試験/盤試験.zy 試験/計算試験.zy 試験/思考試験.zy 試験/描画試験.zy; do
    echo "─── $suite"
    salida=$(zymbol run "$suite" 2>&1)
    echo "$salida" | tail -1
    if echo "$salida" | grep -q "FAIL"; then
        echo "$salida"
        fallo=1
    fi
    echo
done

if [ "$fallo" -eq 0 ]; then
    echo "全試験 PASS"
else
    echo "全試験 FAIL"
    exit 1
fi
