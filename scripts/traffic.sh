#!/bin/sh
# Adjust traffic independently of image build/deployment.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
[ "$#" -eq 2 ] || fail 'Usage: sh scripts/traffic.sh canary 0|10|100 OR ab split|stable OR shadow on|off'
strategy=$1
setting=$2
case "$strategy:$setting" in
    canary:0|canary:10|canary:100|ab:split|ab:stable|shadow:on|shadow:off) ;;
    *) fail 'Allowed: canary 0|10|100; ab split|stable; shadow on|off.' ;;
esac
check_cluster
work_dir=$(mktemp -d)
trap 'rm -f "$work_dir/previous.conf" "$work_dir/nginx.conf"; rmdir "$work_dir"' EXIT HUP INT TERM
k get configmap aceest-router -o jsonpath='{.data.nginx\.conf}' > "$work_dir/previous.conf"
[ -s "$work_dir/previous.conf" ] || fail 'Router ConfigMap is empty; run bootstrap first.'
awk -v strategy="$strategy" -v setting="$setting" '
    /upstream canary_backend \{/ { in_canary=1 }
    in_canary && /server aceest-stable:5000/ && strategy=="canary" {
        $0="    server aceest-stable:5000 weight=9" (setting=="100" ? " down" : "") ";"
    }
    in_canary && /server aceest-candidate:5000/ && strategy=="canary" {
        $0="    server aceest-candidate:5000 weight=1" (setting=="0" ? " down" : "") ";"
    }
    in_canary && /^[[:space:]]*}/ { in_canary=0 }
    /^[[:space:]]*candidate (candidate_backend|stable_backend);/ && strategy=="ab" {
        $0="    candidate " (setting=="stable" ? "stable_backend" : "candidate_backend") ";"
    }
    /^[[:space:]]*mirror (\/_mirror|off);/ && strategy=="shadow" {
        $0="      mirror " (setting=="on" ? "/_mirror" : "off") ";"
    }
    { print }
' "$work_dir/previous.conf" > "$work_dir/nginx.conf"
apply_config() {
    k create configmap aceest-router --from-file="nginx.conf=$1" --dry-run=client -o yaml | k apply -f - || return 1
    k rollout restart deployment/aceest-entry || return 1
    k rollout status deployment/aceest-entry --timeout="$ROLLOUT_TIMEOUT" || return 1
    k exec deployment/aceest-entry -- nginx -t
}
printf 'Changing %s traffic to %s.\n' "$strategy" "$setting"
if apply_config "$work_dir/nginx.conf"; then
    printf 'Router ready. Collect actual response headers and counts before concluding success.\n'
else
    printf 'Router update failed; restoring previous configuration.\n' >&2
    apply_config "$work_dir/previous.conf"
    fail 'Traffic change failed and previous configuration was restored.'
fi
