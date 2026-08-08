#!/usr/bin/env bash
# benchmark_go.sh — run 棋戦.zy under every Zymbol engine and compare.
#
#   bash benchmark_go.sh                 # 1 game each on 9, 13 and 19
#   bash benchmark_go.sh --boards 9,13   # pick the boards
#   bash benchmark_go.sh --games 3       # more games per board
#   bash benchmark_go.sh --engines zyvm,zyml
#   bash benchmark_go.sh --timeout 1800  # per run, seconds
#
# Why this workload and not the arithmetic benchmarks: a Go position is
# allocation-bound — a board copy per legality test, a visited array per flood
# fill, hundreds of thousands of them per game.  BENCHMARK.md measures the
# tree-walker at 8-14x slower than the VM here, against the ~4.4x the project's
# own docs claim from arithmetic-heavy work.  This is the shape of program that
# separates the engines.
#
# What is compared is *wall time and completion*, not output: 棋戦 seeds itself
# from the clock, so two runs of the same engine play different games.  Timings
# are therefore statistical, not paired — read them as "this size of workload
# costs this much", not as "this exact game".

set -uo pipefail
cd "$(dirname "$0")"

# A decimal comma turns every timing into an integer in awk, which silently
# corrupts the ratios rather than failing.
export LC_ALL=C

GAMES=1
BOARDS="9,13,19"
ENGINES="zytw,zyvm,zyjs,zyml"
TIMEOUT=1800
OUT="benchmark_results"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --games)   GAMES="$2"; shift 2 ;;
    --boards)  BOARDS="$2"; shift 2 ;;
    --engines) ENGINES="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

ZYML=${ZYML:-../zyml/zyml}
ZYJS=${ZYJS:-../zyquality/harness/js.mjs}

engine_cmd() {                       # engine_cmd <id> <file> <args...>
  local id=$1; shift
  case "$id" in
    zytw) echo "zymbol run $*" ;;
    zyvm) echo "zymbol run --vm $*" ;;
    zyml) echo "$ZYML run $*" ;;
    zyjs) echo "node $ZYJS $*" ;;
    *) return 1 ;;
  esac
}

engine_available() {
  case "$1" in
    zytw|zyvm) command -v zymbol >/dev/null ;;
    zyml) [[ -x $ZYML ]] ;;
    zyjs) command -v node >/dev/null && [[ -f $ZYJS ]] ;;
    *) return 1 ;;
  esac
}

mkdir -p "$OUT"
STAMP=$(date +%Y%m%d_%H%M%S)
RESULTS="$OUT/$STAMP.tsv"
printf 'engine\tboard\tgames\tstatus\tseconds\tmoves\tresult\n' > "$RESULTS"

IFS=',' read -ra ENGINE_LIST <<< "$ENGINES"
IFS=',' read -ra BOARD_LIST  <<< "$BOARDS"

echo "棋戦 benchmark — $GAMES game(s) per board, ${TIMEOUT}s cap per run"
echo "engines: ${ENGINE_LIST[*]}   boards: ${BOARD_LIST[*]}"
echo

for eng in "${ENGINE_LIST[@]}"; do
  if ! engine_available "$eng"; then
    echo "  $eng: not available, skipping"
    for b in "${BOARD_LIST[@]}"; do
      printf '%s\t%s\t%s\tunavailable\t\t\t\n' "$eng" "$b" "$GAMES" >> "$RESULTS"
    done
    continue
  fi

  for board in "${BOARD_LIST[@]}"; do
    log="$OUT/$STAMP.$eng.$board.log"
    printf '  %-5s %2sx%-2s  ' "$eng" "$board" "$board"

    # 静 = batch mode: draws nothing, one line per game.  A benchmark that
    # needs a terminal is not a benchmark.
    cmd=$(engine_cmd "$eng" "棋戦.zy" "$GAMES" "$board" "静")
    start=$(date +%s.%N)
    timeout "$TIMEOUT" bash -c "$cmd" > "$log" 2>&1
    rc=$?
    end=$(date +%s.%N)
    secs=$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.1f", b-a}')

    case $rc in
      0)   status=ok ;;
      124) status=timeout ;;
      *)   status="failed(rc=$rc)" ;;
    esac

    # The per-game line ends with "<result>  <n> <moves-word>  <ms> ms", and
    # the word depends on the report language (手数 / moves / jugadas).  Match
    # on the result token instead, which is the same in every language.
    moves=$(grep -oE '(B|W)\+[0-9.]+ +[0-9]+|jigo +[0-9]+' "$log" \
            | tail -1 | grep -oE '[0-9]+$')
    result=$(grep -oE '\b[BW]\+[0-9.]+|\bjigo\b' "$log" | tail -1)

    # Exit 0 is not the same as "played a game".  The JavaScript engine reports
    # a rejected program on stdout and exits 0, which would otherwise be scored
    # as a win in a tenth of a second — the failure mode a benchmark must not
    # have.  A run that recorded no result did not run.
    if [[ $status == ok && -z $result ]]; then
      status=no-games
      reason=$(grep -m1 -oE '(error|Error|Runtime error)[^\n]{0,60}' "$log" | head -1)
      [[ -n $reason ]] && status="rejected"
    fi

    printf '%-14s %8ss  %s %s\n' "$status" "$secs" "${moves:-–} moves" "${result:-}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$eng" "$board" "$GAMES" "$status" "$secs" "${moves:-}" "${result:-}" >> "$RESULTS"
  done
done

echo
bash "$(dirname "$0")/benchmark_summary.sh" "$RESULTS"
