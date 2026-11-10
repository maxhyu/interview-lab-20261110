#!/usr/bin/env bash
# Auto-grader for Part 3 — The datastore on a StatefulSet.
# Re-run as often as you like; exits 0 only when every check passes.
#
#   ./verify.sh
#
# Needs: kubectl (pointing at the lab cluster). Works on minikube, kind, or hosted clusters.
set -uo pipefail
# Tip: on a slow cluster, raise the retry counts (the two numbers after each `retry` call).

NS=data-platform-lab
pass=0; fail=0

check() {
  if [[ "$2" == "$3" ]]; then
    printf '  PASS  %s\n' "$1"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n        expected: %q\n        actual:   %q\n' "$1" "$3" "$2"; fail=$((fail+1))
  fi
}

retry() { # retry "<cmd>" "<expected>" [tries] [sleep] -> echoes last actual
  local cmd="$1" want="$2" tries="${3:-30}" nap="${4:-4}" out=""
  for _ in $(seq "$tries"); do
    out="$(eval "$cmd" 2>/dev/null)"
    [[ "$out" == "$want" ]] && { echo "$out"; return 0; }
    sleep "$nap"
  done
  echo "$out"
}

echo "== storage =="
pvc=$(retry "kubectl get pvc data-postgres-0 -n $NS -o jsonpath='{.status.phase}'" "Bound" 8 2)
check "PVC data-postgres-0 is Bound" "$pvc" "Bound"

echo "== statefulset ready =="
rr=$(retry "kubectl get statefulset postgres -n $NS -o jsonpath='{.status.readyReplicas}'" "1" 12 2)
check "postgres StatefulSet has readyReplicas=1" "$rr" "1"

echo "== headless service =="
cip=$(kubectl get svc postgres -n $NS -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
check "postgres Service is headless (clusterIP: None)" "$cip" "None"

echo "== startup probe present =="
sp=$(kubectl get statefulset postgres -n $NS -o jsonpath='{.spec.template.spec.containers[0].startupProbe}' 2>/dev/null)
if [[ -n "$sp" ]]; then
  printf '  PASS  %s\n' "postgres container defines a startupProbe"; pass=$((pass+1))
else
  printf '  FAIL  %s\n        actual: %q\n' "postgres container defines a startupProbe" "<none>"; fail=$((fail+1))
fi

dns=$(retry "kubectl exec -n $NS db-toolbox -- nslookup postgres-0.postgres.$NS.svc.cluster.local >/dev/null 2>&1 && echo ok" "ok" 6 2)
echo "== per-pod DNS resolves =="
check "postgres-0 per-pod DNS resolves (headless is graded separately, above)" "$dns" "ok"

conn=$(retry "kubectl exec -n $NS db-toolbox -- nc -z -w3 postgres 5432 >/dev/null 2>&1 && echo ok" "ok" 6 2)
echo "== connectivity through the Service =="
check "postgres:5432 reachable through the Service" "$conn" "ok"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
