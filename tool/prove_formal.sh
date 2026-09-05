#!/usr/bin/env bash
# Machine-checks the Tamarin models in formal/ lemma by lemma, each under its
# own time limit. Used locally and by .github/workflows/formal.yml so that both
# run exactly the same command lines.
#
#   tool/prove_formal.sh [options] [MODEL.spthy ...]
#     --out DIR          where logs and the summary go (default build/formal)
#     --jobs N           lemmas proved in parallel (default 1)
#     --skip-long        skip lemmas tagged "long" in formal/lemmas.conf (CI)
#     --only REGEX       only lemmas whose name matches REGEX
#     --timeout-scale F  multiply every per-lemma timeout by F
#     --no-wf            skip the well-formedness pass
#
# Per-lemma timeouts, tags and extra tamarin flags come from formal/lemmas.conf.
# Exit status is 1 if the well-formedness check fails, if a lemma times out or
# errors, or if a lemma is falsified and formal/RESULTS.md does not list it in
# its "prove_formal:accepted-falsified" block. Tamarin's own exit code says
# nothing about falsified lemmas, hence the summary parsing below.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMAL="$ROOT/formal"
CONF="$FORMAL/lemmas.conf"
RESULTS_MD="$FORMAL/RESULTS.md"
OUT="$ROOT/build/formal"
JOBS=1; SKIP_LONG=0; ONLY=""; SCALE=1; DO_WF=1
WF_TIMEOUT="${WF_TIMEOUT:-1800}"
DERIV_TIMEOUT="${DERIV_TIMEOUT:-60}"
MODELS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;            --out=*) OUT="${1#*=}"; shift ;;
    --jobs) JOBS="$2"; shift 2 ;;          --jobs=*) JOBS="${1#*=}"; shift ;;
    --only) ONLY="$2"; shift 2 ;;          --only=*) ONLY="${1#*=}"; shift ;;
    --timeout-scale) SCALE="$2"; shift 2 ;; --timeout-scale=*) SCALE="${1#*=}"; shift ;;
    --skip-long) SKIP_LONG=1; shift ;;
    --no-wf) DO_WF=0; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) MODELS+=("$(basename "$1")"); shift ;;
  esac
done
if [ ${#MODELS[@]} -eq 0 ]; then
  MODELS=(nyxchat_v4_handshake.spthy nyxchat_v4_async.spthy)
fi
for tool in tamarin-prover maude timeout; do
  command -v "$tool" >/dev/null 2>&1 || { echo "prove_formal: $tool not on PATH" >&2; exit 2; }
done
mkdir -p "$OUT"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
{
  echo "date:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host:    $(uname -srm), $(nproc) cpus"
  echo "tamarin: $(tamarin-prover --version 2>/dev/null | grep -o 'tamarin-prover [0-9.]*' | head -1)"
  echo "maude:   $(maude --version 2>/dev/null | head -1)"
} | tee "$OUT/versions.txt"

status=0
RESULTS="$OUT/results.tsv"
: > "$RESULTS"

# --- well-formedness -------------------------------------------------------
if [ "$DO_WF" -eq 1 ]; then
  for m in "${MODELS[@]}"; do
    base="${m%.spthy}"; log="$OUT/$base.wf.txt"
    echo "== well-formedness: $m (timeout ${WF_TIMEOUT}s)"
    t0=$(date +%s)
    ( cd "$FORMAL" && timeout "$WF_TIMEOUT" tamarin-prover --derivcheck-timeout="$DERIV_TIMEOUT" "$m" ) > "$log" 2>&1
    rc=$?
    secs=$(( $(date +%s) - t0 ))
    if grep -q 'All wellformedness checks were successful' "$log"; then
      echo "   ok (${secs}s)"
      printf '%s\t%s\t%s\t%s\t%s\n' "$base" "(well-formedness)" "ok" "$secs" "" >> "$RESULTS"
    else
      echo "   FAILED (rc=$rc, ${secs}s); see $log"
      grep -A12 'wellformedness checks failed' "$log" | head -30
      grep 'Open Chains' "$log"
      printf '%s\t%s\t%s\t%s\t%s\n' "$base" "(well-formedness)" "failed" "$secs" "rc=$rc" >> "$RESULTS"
      status=1
    fi
  done
fi

# --- proofs ----------------------------------------------------------------
prove_one() {  # base lemma timeout [flags...]
  local base="$1" lemma="$2" t="$3"; shift 3
  local log="$OUT/$base.$lemma.txt" t0 rc secs line outcome
  t0=$(date +%s)
  ( cd "$FORMAL" && timeout --kill-after=30 "$t" tamarin-prover --prove="$lemma" "$@" "$base.spthy" ) > "$log" 2>&1
  rc=$?
  secs=$(( $(date +%s) - t0 ))
  line=$(grep -E "^  $lemma \(" "$log" | tail -1 | sed 's/^ *//')
  case "$line" in
    *": verified"*)  outcome=verified ;;
    *": falsified"*) outcome=falsified ;;
    *) if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then outcome=timeout; else outcome=error; fi ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$base" "$lemma" "$outcome" "$secs" "$line" >> "$RESULTS"
  echo "   $base/$lemma: $outcome (${secs}s) $line"
}
export -f prove_one
export OUT FORMAL RESULTS

JOBFILE="$OUT/jobs.txt"; : > "$JOBFILE"
# lemmas.conf: file lemma timeout tag [extra tamarin flags]
while read -r file lemma tmo tag flags || [ -n "${file:-}" ]; do
  case "$file" in ''|'#'*) continue ;; esac
  flags="${flags%%#*}"; flags="${flags%"${flags##*[! ]}"}"   # drop trailing comment and blanks
  base="${file%.spthy}"
  keep=0; for m in "${MODELS[@]}"; do [ "$m" = "$file" ] && keep=1; done
  [ "$keep" -eq 1 ] || continue
  if [ -n "$ONLY" ] && ! printf '%s' "$lemma" | grep -Eq -- "$ONLY"; then continue; fi
  if [ "$tag" = "long" ] && [ "$SKIP_LONG" -eq 1 ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$base" "$lemma" "skipped" "0" "long lemma, not run in CI" >> "$RESULTS"
    echo "   $base/$lemma: skipped (long)"
    continue
  fi
  tmo=$(awk -v a="$tmo" -v s="$SCALE" 'BEGIN{printf "%d", a*s}')
  # no trailing blank: xargs -L would treat it as a line continuation
  printf '%s %s %s%s\n' "$base" "$lemma" "$tmo" "${flags:+ $flags}" >> "$JOBFILE"
done < "$CONF"
echo "== proving $(wc -l < "$JOBFILE") lemmas, $JOBS at a time"
xargs -P "$JOBS" -L 1 bash -c 'prove_one "$@"' _ < "$JOBFILE"

# --- evaluation ------------------------------------------------------------
accepted=$(sed -n '/<!-- prove_formal:accepted-falsified/,/-->/p' "$RESULTS_MD" 2>/dev/null \
           | grep -v -e '<!--' -e '-->' | sed 's/#.*//' | tr -d ' \t\r' | grep -v '^$')
SUMMARY="$OUT/summary.md"
{
  echo "| Model | Lemma | Outcome | Time (s) | Tamarin summary line |"
  echo "|---|---|---|---|---|"
} > "$SUMMARY"
while IFS=$'\t' read -r base lemma outcome secs line; do
  note="$line"
  case "$outcome" in
    ok|verified|skipped) ;;
    falsified)
      if printf '%s\n' "$accepted" | grep -qx "$base.spthy:$lemma"; then
        outcome="falsified (accepted)"; note="$line; documented in RESULTS.md"
      else
        status=1; note="$line; NOT listed as accepted in RESULTS.md"
      fi ;;
    *) status=1 ;;
  esac
  echo "| $base | $lemma | $outcome | $secs | $note |" >> "$SUMMARY"
done < "$RESULTS"
echo; cat "$SUMMARY"
echo; echo "prove_formal: exit $status (logs in $OUT)"
exit "$status"