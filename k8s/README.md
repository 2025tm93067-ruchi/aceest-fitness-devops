# Five release strategies in one small cluster

This is a read-only deployment lab for the existing Flask project. It exposes
`GET /version` through five prefixes. Upload `k8s/` and `scripts/` alongside the
root Dockerfile, wsgi.py, and Jenkinsfile in the GitHub repository. Scripts use
POSIX `sh`; execute with `sh scripts/name.sh`, so GitHub uploads need no executable
permission changes. Commit with LF line endings (`.gitattributes` is included).

Prerequisites on the Rocky Linux VM: a working Docker engine, `kubectl`,
`minikube`, `curl`, and a configured non-production Kubernetes context. A Jenkins
agent needs the same `kubectl` binary and a **flattened** kubeconfig containing
certificate data as the `aceest-kubeconfig` secret-file credential. The API server
address in it must be reachable from that agent. Do not commit kubeconfig or tokens.

On this 7.4 GiB VM, Jenkins, SonarQube, Docker builds, and Minikube share memory.
Start with `minikube start --driver=docker --cpus=2 --memory=2300` as the normal
Docker-enabled user. Check `free -h` and `kubectl top nodes` if metrics-server is
enabled. Run builds and strategy demonstrations sequentially. If insufficient
memory prevents startup, increase VM RAM or put the cluster on a separate host;
do not assume this command guarantees capacity.

## Bootstrap

Build and publish two images using the supplied Dockerfile. Each must include
the new `wsgi.py` and have a different `APP_VERSION` or `GIT_COMMIT`. The image
names below are examples; substitute the real DockerHub user and immutable tags
or, preferably, `repository@sha256:...` digests. Use a public DockerHub repository
for this lab, or configure an imagePullSecret separately.

```sh
git pull --ff-only
sh scripts/bootstrap-k8s.sh YOUR_USER/aceest-fitness:2.0.0-v1 YOUR_USER/aceest-fitness:2.0.1-v2
kubectl -n aceest-lab get pods -o wide
sh scripts/verify-strategies.sh "http://$(minikube ip):30080" > evidence-baseline.txt 2>&1
cat evidence-baseline.txt
```

Bootstrap creates stable/candidate services, a two-replica rolling deployment,
one blue and one green deployment, and one NGINX entry router. Six small app pods
plus one router run simultaneously. Re-running bootstrap restores image baseline
and the blue service selector; use rollout/rollback for release demonstrations.
SQLite files are per-pod and ephemeral, so this lab deliberately forwards only
read-only version requests. It does not demonstrate shared production data,
database migrations, or lossless writes across replicas.

| URL prefix | Actual routing | Release / rollback |
| --- | --- | --- |
| `/rolling/` | Two replicas, maxUnavailable=0 and maxSurge=1 | `rollout.sh IMAGE rolling`; `rollback.sh rolling` |
| `/bluegreen/` | Service points to blue or green | `rollout.sh IMAGE bluegreen`; `rollback.sh bluegreen` |
| `/canary/` | NGINX weighted upstream, stable:candidate=90:10 | `traffic.sh canary 100`; revert `traffic.sh canary 0`; restore experiment `traffic.sh canary 10` |
| `/ab/` | `X-ACEest-Cohort: candidate` goes to candidate; stable/default goes to stable | `traffic.sh ab stable` disables the experiment; `traffic.sh ab split` restores it |
| `/shadow/` | Caller gets stable response; a read-only mirror reaches candidate | `traffic.sh shadow off`; restore `traffic.sh shadow on` |

Each prefix also accepts `/version`, for example `/canary/version`. Other paths
return 404 and writes are blocked. This A/B demonstration uses a repeatable
explicit cohort header, not user identity assignment. Shadow responses are
discarded by NGINX; the verifier proves both backend arrivals using one unique
request ID. It does not claim that mirrored responses are compared for equality.

## Capture release and rollback evidence

Use a second SSH terminal during rolling deployment to observe old/new pods and
real response identities. The release image must differ from the current one.

```sh
kubectl -n aceest-lab get pods -w
# In the other terminal:
sh scripts/rollout.sh YOUR_USER/aceest-fitness:2.0.1-v2 rolling
curl -i "http://$(minikube ip):30080/rolling/version"
sh scripts/rollback.sh rolling
curl -i "http://$(minikube ip):30080/rolling/version"
sh scripts/rollout.sh YOUR_USER/aceest-fitness:2.0.1-v2 bluegreen
curl -i "http://$(minikube ip):30080/bluegreen/version"
sh scripts/rollback.sh bluegreen
curl -i "http://$(minikube ip):30080/bluegreen/version"
```

Rolling smoke failures trigger `kubectl rollout undo` and the script exits with
failure even if recovery succeeds. Blue/green startup failure leaves the active
selector untouched. The previous slot stays running for immediate rollback.
This is a lab availability pattern, not a guarantee of zero downtime on a
single-node cluster. Pod eviction or node failure can still interrupt service.

For canary promotion/rollback, capture the real counts after each setting:

```sh
sh scripts/traffic.sh canary 100
for i in $(seq 1 20); do curl -fsS -D - -o /dev/null "http://$(minikube ip):30080/canary/version" | grep -i '^X-ACEest-Version:'; done
sh scripts/traffic.sh canary 0
for i in $(seq 1 20); do curl -fsS -D - -o /dev/null "http://$(minikube ip):30080/canary/version" | grep -i '^X-ACEest-Version:'; done
sh scripts/traffic.sh canary 10
sh scripts/traffic.sh ab stable
curl -i -H 'X-ACEest-Cohort: candidate' "http://$(minikube ip):30080/ab/version"
sh scripts/traffic.sh ab split
sh scripts/traffic.sh shadow off
curl -i -H 'X-Request-ID: shadow-disabled-proof' "http://$(minikube ip):30080/shadow/version"
# Inspect candidate logs: the disabled proof ID must be absent.
kubectl -n aceest-lab logs -l app=aceest,track=candidate --since=2m
sh scripts/traffic.sh shadow on
sh scripts/verify-strategies.sh "http://$(minikube ip):30080" > evidence-final.txt 2>&1
```

The full verifier expects the baseline 90:10 canary, split A/B, and enabled
shadow settings. It checks all five routes, repeated cohort identities, 100
canary responses, and correlated stable/candidate shadow logs. It fails on
missing headers, failed requests, unexpected identities, or missing mirror
evidence. It reports actual observations, not screenshots or placeholder results.

## Access from a browser outside the VM

`minikube ip` normally returns an address reachable **inside the VM only** when
the Docker driver is used. A NodePort alone does not make the application public.
For a deliberate temporary VM listener, run on the VM:

```sh
kubectl -n aceest-lab port-forward --address 0.0.0.0 service/aceest-entry 8081:80
```

Then use `http://VM_REACHABLE_IP:8081/rolling/version` from your Mac if routing,
cloud security rules, and the VM firewall permit it. Keep this SSH session open.
Restrict port 8081 to your own IP where possible; close the listener after the
demo. A genuinely public URL needs a reachable public IP/DNS, an allowed inbound
port, and this live forwarding process or a proper production ingress/load
balancer. No public URL has been provisioned by these files.

NGINX uses the ordinary maintained Docker Official Image, not the retired
ingress-nginx controller. The exact stable tag was checked against the
[official supported-tags page](https://hub.docker.com/_/nginx/) on 2026-11-24.

## Diagnose without claiming success

```sh
kubectl -n aceest-lab get events --sort-by=.lastTimestamp
kubectl -n aceest-lab describe pods
kubectl -n aceest-lab logs deployment/aceest-entry --tail=100
kubectl -n aceest-lab logs deployment/aceest-candidate --tail=100
kubectl -n aceest-lab exec deployment/aceest-entry -- nginx -t
kubectl -n aceest-lab rollout history deployment/aceest-rolling
```

`ImagePullBackOff`: check the real public image/tag or pull credentials.
`CrashLoopBackOff`: inspect application logs and ensure wsgi.py is in the image.
`Pending`/OOM: check VM/cluster resource capacity. A stale external response
requires checking the forwarded listener, Service selector, pod image digest,
and version/commit headers before concluding a release was deployed.
