#!/bin/sh
# Shared by the lab scripts. Run from any directory; no secrets are embedded.
set -eu
NAMESPACE=aceest-lab
ROLLOUT_TIMEOUT=${ROLLOUT_TIMEOUT:-150s}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Install/configure $1 first."; }
k() { kubectl -n "$NAMESPACE" "$@"; }

check_cluster() {
    need kubectl
    printf 'Kubernetes context: '
    kubectl config current-context
    kubectl get namespace "$NAMESPACE" >/dev/null
}

check_image() {
    case "$1" in ''|*[!a-zA-Z0-9._:/@-]*) fail 'Use a registry image tag or sha256 digest, with no shell characters.' ;; esac
    case "$1" in
        *@sha256:*)
            digest=${1##*@sha256:}
            printf '%s\n' "$digest" | grep -Eq '^[a-f0-9]{64}$' || fail 'Invalid sha256 image digest.'
            ;;
        *:*)
            tag=${1##*:}
            case "$tag" in ''|*/*|latest|stable|main|master) fail 'Supply an immutable release tag or sha256 digest.' ;; esac
            ;;
        *) fail 'An explicit release tag or sha256 digest is required.' ;;
    esac
}

smoke_deployment() {
    # The Python runtime is in the app image. No curl installation in pods needed.
    k exec "deployment/$1" -- python -c '
import json, urllib.request
with urllib.request.urlopen("http://127.0.0.1:5000/version", timeout=10) as response:
    assert response.status == 200
    assert response.headers.get("X-ACEest-Version")
    assert response.headers.get("X-ACEest-Commit")
    result = json.load(response)
    print(json.dumps(result, sort_keys=True))
'
}

smoke_service() {
    # Service endpoint updates are asynchronous, so retry briefly after selector changes.
    expected=$(k exec "deployment/$1" -- python -c '
import urllib.request
with urllib.request.urlopen("http://127.0.0.1:5000/version", timeout=5) as response:
    print(response.headers["X-ACEest-Version"] + "@" + response.headers["X-ACEest-Commit"])
') || return 1
    attempt=0
    until k exec deployment/aceest-stable -- python -c '
import json, sys, urllib.request
with urllib.request.urlopen("http://aceest-bluegreen:5000/version", timeout=5) as response:
    assert response.status == 200
    identity = response.headers["X-ACEest-Version"] + "@" + response.headers["X-ACEest-Commit"]
    assert identity == sys.argv[1], ("waiting for endpoint update", identity, sys.argv[1])
    print(json.dumps(json.load(response), sort_keys=True))
' "$expected"; do
        attempt=$((attempt + 1))
        [ "$attempt" -lt 10 ] || return 1
        sleep 2
    done
}

switch_slot() {
    case "$1" in blue|green) ;; *) fail 'Invalid blue/green slot.' ;; esac
    k patch service aceest-bluegreen --type merge \
        -p "{\"spec\":{\"selector\":{\"app\":\"aceest\",\"track\":\"bluegreen\",\"slot\":\"$1\"}}}"
}
