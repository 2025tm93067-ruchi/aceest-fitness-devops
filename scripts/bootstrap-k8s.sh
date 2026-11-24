#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
. "$SCRIPT_DIR/common.sh"
[ "$#" -eq 2 ] || fail 'Usage: sh scripts/bootstrap-k8s.sh STABLE_IMAGE CANDIDATE_IMAGE'
stable_image=$1
candidate_image=$2
check_image "$stable_image"
check_image "$candidate_image"
[ "$stable_image" != "$candidate_image" ] || fail 'Use two separately versioned images for visible strategy evidence.'
need kubectl
printf 'Bootstrapping context: '
kubectl config current-context
kubectl apply -f "$ROOT_DIR/k8s/namespace.yaml"
# Re-running bootstrap restores the original baseline and blue service selector.
sed -e "s|STABLE_IMAGE_PLACEHOLDER|$stable_image|g" \
    -e "s|CANDIDATE_IMAGE_PLACEHOLDER|$candidate_image|g" \
    "$ROOT_DIR/k8s/deployments.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT_DIR/k8s/services.yaml"
for name in stable candidate rolling bg-blue bg-green; do
    k rollout status "deployment/aceest-$name" --timeout="$ROLLOUT_TIMEOUT"
done
kubectl apply -f "$ROOT_DIR/k8s/router.yaml"
# A subPath ConfigMap mount updates only when the router pod is recreated.
k rollout restart deployment/aceest-entry
k rollout status deployment/aceest-entry --timeout="$ROLLOUT_TIMEOUT"
k exec deployment/aceest-entry -- nginx -t
smoke_deployment aceest-stable
smoke_deployment aceest-candidate
k get deployments,pods,services -o wide
printf '\nBaseline installed. Next: sh scripts/verify-strategies.sh http://MINIKUBE_IP:30080\n'
