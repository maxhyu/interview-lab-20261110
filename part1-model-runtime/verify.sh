#!/usr/bin/env bash
# Auto-grader for Part 1 — The model-runtime Service.
# Grades each act independently. Re-run as often as you like; exits 0 only when every check passes.
#
#   ./verify.sh
#
# Needs: kubectl (pointing at the lab cluster). No other tools.
set -uo pipefail
# Tip: on a slow cluster, raise the retry counts (the two numbers after each `retry` call).

NS=model-runtime-lab
pass=0; fail=0

check() { # check "<description>" "<actual>" "<expected>"
  if [[ "$2" == "$3" ]]; then
    printf '  PASS  %s\n' "$1"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n        expected: %q\n        actual:   %q\n' "$1" "$3" "$2"; fail=$((fail+1))
  fi
}

# retry "<cmd>" "<expected>" [tries] [sleep] -> echoes the last actual value
retry() {
  local cmd="$1" want="$2" tries="${3:-20}" nap="${4:-3}" out=""
  for _ in $(seq "$tries"); do
    out="$(eval "$cmd" 2>/dev/null)"
    [[ "$out" == "$want" ]] && { echo "$out"; return 0; }
    sleep "$nap"
  done
  echo "$out"
}

echo "== Act 0 — model-loader stays up =="
ready=$(retry "kubectl get pod model-loader -n $NS -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'" "True" 5 2)
check "model-loader is Ready (not crash-looping / OOMKilled)" "$ready" "True"

echo "== Act 1 — Service returns 100% success =="
eps=$(retry "kubectl get endpoints model-runtime -n $NS -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w | tr -d ' '" "2" 6 2)
check "model-runtime has exactly 2 ready endpoints (canary excluded, not repaired in)" "$eps" "2"

canary=$(kubectl get deploy model-canary -n $NS -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [[ "${canary:-0}" =~ ^[0-9]+$ ]] && (( canary >= 1 )); then
  printf '  PASS  %s\n' "model-canary is still running (not deleted / scaled to zero)"; pass=$((pass+1))
else
  printf '  FAIL  %s\n        available replicas: %q\n' "model-canary is still running (not deleted / scaled to zero)" "${canary:-<none>}"; fail=$((fail+1))
fi

codes=$(retry "kubectl exec -n $NS toolbox -- sh -c 'for i in \$(seq 20); do curl -s -o /dev/null -m 2 -w \"%{http_code}\n\" http://model-runtime/; done | sort -u | paste -sd, -'" "200" 5 2)
check "20/20 requests from toolbox return 200" "$codes" "200"

echo "== Act 2 — startup probe added =="
sp=$(kubectl get deploy model-runtime -n $NS -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.path}' 2>/dev/null)
check "model-runtime container has a startupProbe on /readyz" "$sp" "/readyz"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
