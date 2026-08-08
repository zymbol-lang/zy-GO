#!/usr/bin/env bash
# benchmark_summary.sh — render a run's .tsv as a table with ratios.
#
#   bash benchmark_summary.sh                      # the newest run
#   bash benchmark_summary.sh results/xxx.tsv      # a specific one
#
# Ratios are against the fastest engine that completed the same board, so the
# baseline is stated rather than assumed.  An engine that timed out or was not
# installed is shown as such and never folded into an average — a benchmark
# that averages a missing number is reporting a number nobody measured.

set -uo pipefail
cd "$(dirname "$0")"
export LC_ALL=C

FILE="${1:-}"
if [[ -z $FILE ]]; then
  FILE=$(ls -1t benchmark_results/*.tsv 2>/dev/null | head -1)
  [[ -z $FILE ]] && { echo "no results found under benchmark_results/" >&2; exit 2; }
fi
[[ -f $FILE ]] || { echo "not found: $FILE" >&2; exit 2; }

awk -F'\t' '
NR == 1 { next }
{
  eng=$1; board=$2; games=$3; status=$4; secs=$5; moves=$6; result=$7
  key = board "\t" eng
  st[key]  = status
  sec[key] = secs
  mv[key]  = moves
  res[key] = result
  if (!(board in seen_board)) { boards[++nb] = board; seen_board[board] = 1 }
  if (!(eng in seen_eng))     { engines[++ne] = eng;  seen_eng[eng] = 1 }
  if (status == "ok" && (!(board in best) || secs + 0 < best[board] + 0)) {
    best[board] = secs; bestof[board] = eng
  }
  G = games
}
END {
  printf "═══ 棋戦 — %s game(s) per board ═══\n\n", G

  printf "%-6s", "board"
  for (j = 1; j <= ne; j++) printf " %14s", engines[j]
  printf "\n"
  printf "%-6s", "──────"
  for (j = 1; j <= ne; j++) printf " %14s", "──────────────"
  printf "\n"

  for (i = 1; i <= nb; i++) {
    b = boards[i]
    printf "%-6s", b "×" b
    for (j = 1; j <= ne; j++) {
      k = b "\t" engines[j]
      if (st[k] == "ok")               printf " %13ss", sec[k]
      else if (st[k] == "timeout")     printf " %14s", "timeout"
      else if (st[k] == "unavailable") printf " %14s", "—"
      else if (st[k] == "rejected")    printf " %14s", "rejected"
      else if (st[k] == "no-games")    printf " %14s", "no games"
      else if (st[k] == "")            printf " %14s", ""
      else                             printf " %14s", "failed"
    }
    printf "\n"

    # Ratio line, only where there is a completed baseline to divide by.
    if (b in best) {
      printf "%-6s", ""
      for (j = 1; j <= ne; j++) {
        k = b "\t" engines[j]
        if (st[k] == "ok") {
          r = sec[k] / best[b]
          if (engines[j] == bestof[b]) printf " %14s", "1.0× (base)"
          else                         printf " %13.1f×", r
        } else printf " %14s", ""
      }
      printf "\n"
    }

    # Moves played, so a suspiciously fast run is visible as a short game
    # rather than as a fast engine.
    printf "%-6s", ""
    any = 0
    for (j = 1; j <= ne; j++) {
      k = b "\t" engines[j]
      if (mv[k] != "") { any = 1; printf " %11s mv", mv[k] } else printf " %14s", ""
    }
    printf "\n\n"
  }

  printf "notes\n"
  for (i = 1; i <= nb; i++) {
    b = boards[i]
    if (b in best) printf "  %s×%s baseline: %s at %ss\n", b, b, bestof[b], best[b]
    else           printf "  %s×%s: no engine completed\n", b, b
  }
  print ""
  print "  Games are seeded from the clock, so engines play different games."
  print "  Timings compare workload cost, not identical positions."
  print "  \"rejected\" means the engine refused the program — not a fast result."
}
' "$FILE"
