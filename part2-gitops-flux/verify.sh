#!/usr/bin/env bash
# Auto-grader for Part 2 — GitOps delivery with Flux.
# Re-run as often as you like; exits 0 only when every check passes.
#
#   ./verify.sh
#
# Needs: kubectl (pointing at the lab cluster, with Flux installed). No flux CLI required.
set -uo pipefail
# Tip: on a slow cluster, raise the retry counts (the two numbers after each `retry` call).

NS=podinfo
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

ready_jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

echo "== Flux installed =="
sc=$(retry "kubectl get deploy source-controller -n flux-system -o jsonpath='{.status.availableReplicas}'" "1" 8 2)
check "source-controller is installed and ready in flux-system" "$sc" "1"
hc=$(retry "kubectl get deploy helm-controller -n flux-system -o jsonpath='{.status.availableReplicas}'" "1" 8 2)
check "helm-controller is installed and ready in flux-system" "$hc" "1"

echo "== in-cluster chart server / HelmRepository =="
hr=$(retry "kubectl get helmrepository local-charts -n $NS -o jsonpath='$ready_jsonpath'" "True" 10 2)
check "HelmRepository local-charts is Ready" "$hr" "True"

echo "== HelmRelease reconciled =="
rel=$(retry "kubectl get helmrelease podinfo -n $NS -o jsonpath='$ready_jsonpath'" "True" 10 2)
check "HelmRelease podinfo is Ready" "$rel" "True"

echo "== podinfo deployed =="
avail=$(retry "kubectl get deploy podinfo -n $NS -o jsonpath='{.status.availableReplicas}'" "2" 10 2)
# accept any >=1 available replica
if [[ "${avail:-0}" =~ ^[0-9]+$ ]] && (( avail >= 1 )); then
  printf '  PASS  %s\n' "podinfo Deployment has >=1 available replica (got $avail)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n        actual: %q\n' "podinfo Deployment available replicas >=1" "${avail:-<none>}"; fail=$((fail+1))
fi

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
