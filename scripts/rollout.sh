#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/common.sh"
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || fail 'Usage: sh scripts/rollout.sh IMAGE [rolling|bluegreen]'
image=$1
strategy=${2:-rolling}
check_image "$image"
check_cluster
case "$strategy" in
    rolling)
        previous=$(k get deployment aceest-rolling -o jsonpath='{.spec.template.spec.containers[0].image}')
        printf 'Rolling: %s -> %s\n' "$previous" "$image"
        [ "$previous" != "$image" ] || fail 'Image is already deployed; use a new immutable image for a rollout.'
        k set image deployment/aceest-rolling "app=$image"
        if k rollout status deployment/aceest-rolling --timeout="$ROLLOUT_TIMEOUT" && smoke_deployment aceest-rolling; then
            k rollout history deployment/aceest-rolling
            printf 'Rolling deployment and smoke check passed.\n'
        else
            printf 'Rollout/smoke failed; restoring previous ReplicaSet.\n' >&2
            k rollout undo deployment/aceest-rolling
            k rollout status deployment/aceest-rolling --timeout="$ROLLOUT_TIMEOUT"
            smoke_deployment aceest-rolling
            fail 'Release failed and was rolled back; inspect kubectl describe/events and pod logs.'
        fi
        ;;
    bluegreen)
        active=$(k get service aceest-bluegreen -o jsonpath='{.spec.selector.slot}')
        case "$active" in blue) next=green ;; green) next=blue ;; *) fail 'Service has no valid active slot.' ;; esac
        printf 'Blue/green: active=%s, preparing=%s, image=%s\n' "$active" "$next" "$image"
        k set image "deployment/aceest-bg-$next" "app=$image"
        # Leave the active selector untouched if candidate startup/smoke fails.
        k rollout status "deployment/aceest-bg-$next" --timeout="$ROLLOUT_TIMEOUT"
        smoke_deployment "aceest-bg-$next"
        k annotate service aceest-bluegreen "aceest.lab/previous-slot=$active" --overwrite
        switch_slot "$next"
        if smoke_service "aceest-bg-$next"; then
            printf 'Blue/green service promoted from %s to %s. Old slot retained for rollback.\n' "$active" "$next"
        else
            switch_slot "$active"
            smoke_service "aceest-bg-$active"
            fail 'Service smoke failed; restored original selector.'
        fi
        ;;
    *) fail 'Strategy must be rolling or bluegreen.' ;;
esac
k get deployments,pods -o wide
