#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
[ "$#" -eq 1 ] || fail 'Usage: sh scripts/verify-strategies.sh http://HOST:PORT'
base=${1%/}
case "$base" in http://*|https://*) ;; *) fail 'Base URL must start with http:// or https://' ;; esac
need curl
check_cluster
work_dir=$(mktemp -d)
trap 'rm -f "$work_dir/headers" "$work_dir/body" "$work_dir/counts" "$work_dir/stable.log" "$work_dir/candidate.log"; rmdir "$work_dir"' EXIT HUP INT TERM

identity() {
    # Output is based on real response headers, never a label assumed by the script.
    version=$(awk 'tolower($1)=="x-aceest-version:" {print $2}' "$work_dir/headers" | tr -d '\r')
    commit=$(awk 'tolower($1)=="x-aceest-commit:" {print $2}' "$work_dir/headers" | tr -d '\r')
    [ -n "$version" ] && [ -n "$commit" ] || fail 'Missing version/commit headers. Build the supplied wsgi.py image.'
    printf '%s@%s\n' "$version" "$commit"
}
fetch() {
    path=$1
    shift
    curl -fsS --max-time 10 -D "$work_dir/headers" -o "$work_dir/body" "$@" "$base/$path/version"
}
printf 'Actual responses from %s\n' "$base"
for path in rolling bluegreen canary ab shadow; do
    fetch "$path"
    printf '%s: %s\n' "$path" "$(identity)"
    cat "$work_dir/body"
    printf '\n'
done

fetch ab -H 'X-ACEest-Cohort: stable'
stable=$(identity)
fetch ab -H 'X-ACEest-Cohort: candidate'
candidate=$(identity)
[ "$stable" != "$candidate" ] || fail 'Stable and candidate report the same version+commit. Build two visible versions first.'
printf '\nA/B cohorts: stable=%s candidate=%s\n' "$stable" "$candidate"
i=0
while [ "$i" -lt 10 ]; do
    fetch ab -H 'X-ACEest-Cohort: stable'
    [ "$(identity)" = "$stable" ] || fail 'Stable cohort changed backend.'
    fetch ab -H 'X-ACEest-Cohort: candidate'
    [ "$(identity)" = "$candidate" ] || fail 'Candidate cohort changed backend.'
    i=$((i + 1))
done
printf 'A/B: 10/10 stable-cohort and 10/10 candidate-cohort requests matched.\n'

: > "$work_dir/counts"
i=0
while [ "$i" -lt 100 ]; do
    fetch canary
    identity >> "$work_dir/counts"
    i=$((i + 1))
done
printf '\nCanary actual counts (configured stable:candidate = 90:10):\n'
sort "$work_dir/counts" | uniq -c
stable_count=$(grep -Fxc "$stable" "$work_dir/counts" || true)
candidate_count=$(grep -Fxc "$candidate" "$work_dir/counts" || true)
[ "$((stable_count + candidate_count))" -eq 100 ] || fail 'Unexpected canary backend identity.'
# Weighted round robin should be close to 10%; allow shared-traffic variation.
[ "$candidate_count" -ge 5 ] && [ "$candidate_count" -le 20 ] || fail 'Canary candidate count outside 5-20 of 100; inspect actual routing.'

probe_id="shadow-proof-$(date +%s)-$$"
fetch shadow -H "X-Request-ID: $probe_id"
[ "$(identity)" = "$stable" ] || fail 'Shadow response must come from stable.'
printf '\nShadow caller response (must be stable), request_id=%s:\n' "$probe_id"
cat "$work_dir/body"
printf '\n'
attempt=0
while :; do
    k logs -l app=aceest,track=stable --since=2m --all-containers=true --prefix=true > "$work_dir/stable.log"
    k logs -l app=aceest,track=candidate --since=2m --all-containers=true --prefix=true > "$work_dir/candidate.log"
    if grep -F "$probe_id" "$work_dir/stable.log" && grep -F "$probe_id" "$work_dir/candidate.log"; then
        break
    fi
    attempt=$((attempt + 1))
    [ "$attempt" -lt 10 ] || fail 'Mirrored request ID missing from backend logs. Inspect router and wrapper logging.'
    sleep 1
done
printf 'Shadow: the same unique request ID reached stable and candidate; only stable answered the caller.\n'
printf '\nCurrent rolling and blue/green state (capture before/after a release):\n'
k get deployments -o wide
k get service aceest-bluegreen -o jsonpath='{.spec.selector}'
printf '\n'
printf 'All response/routing checks passed. This does not replace release and rollback evidence.\n'
