#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
[ "$#" -le 1 ] || fail 'Usage: sh scripts/rollback.sh [rolling|bluegreen]'
check_cluster
case "${1:-rolling}" in
    rolling)
        k rollout undo deployment/aceest-rolling
        k rollout status deployment/aceest-rolling --timeout="$ROLLOUT_TIMEOUT"
        smoke_deployment aceest-rolling
        ;;
    bluegreen)
        active=$(k get service aceest-bluegreen -o jsonpath='{.spec.selector.slot}')
        previous=$(k get service aceest-bluegreen -o jsonpath='{.metadata.annotations.aceest\.lab/previous-slot}')
        case "$previous" in blue|green) ;; *) fail 'No recorded promotion exists to roll back.' ;; esac
        [ "$active" != "$previous" ] || fail 'Previous slot is already active.'
        k rollout status "deployment/aceest-bg-$previous" --timeout="$ROLLOUT_TIMEOUT"
        smoke_deployment "aceest-bg-$previous"
        switch_slot "$previous"
        k annotate service aceest-bluegreen "aceest.lab/previous-slot=$active" --overwrite
        smoke_service "aceest-bg-$previous"
        printf 'Blue/green rollback: %s -> %s\n' "$active" "$previous"
        ;;
    *) fail 'Strategy must be rolling or bluegreen.' ;;
esac
k get deployments,pods -o wide
k get service aceest-bluegreen -o wide
