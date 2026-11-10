# Part 1 — The model-runtime Service

A `model-runtime` service serves a model behind a Kubernetes `Service`, backed by
[podinfo](https://github.com/stefanprodan/podinfo). Something is wrong. Work through the acts below
— you can stop after any one of them.

No special setup: everything pulls from Docker Hub, no CNI needed.

```bash
kubectl apply -f model-runtime-lab.yaml
kubectl get pods -n model-runtime-lab -w   # wait until pods settle
```

A `toolbox` pod (with `curl`) is provided to investigate from.

---

## Act 0 — a pod that won't stay up

One pod in the namespace, `model-loader`, is **not staying Running**.

1. Find it and identify *why* it keeps restarting (what does its state/last-state tell you?).
2. Explain what that state means and why it is happening here.
3. Apply a fix so the pod runs stably.

---

## Act 1 — the Service drops roughly a third of requests

A teammate rolled out `model-canary`, a new version. Since then, monitoring shows that **about a
third of requests to `model-runtime` fail** — but the rest succeed, and every pod reports healthy.

Reproduce it from the `toolbox` pod:

```bash
kubectl exec -it -n model-runtime-lab toolbox -- sh -c \
  'for i in $(seq 30); do curl -s -o /dev/null -m 2 -w "%{http_code}\n" http://model-runtime/; done | sort | uniq -c'
```

You should see a mix of `200` and `000` responses.

1. Investigate why only *some* requests fail while all pods appear healthy.
2. Identify the root cause (where does a "healthy pods but partial failure" symptom usually point?).
3. Apply a fix so the `model-runtime` Service returns **100% successful** responses.

   **What "fixed" means here** — the `model-runtime` Service is the *production* endpoint and must
   serve traffic from the real runtime pods **only**. `model-canary` is a separate, legitimate
   workload that is being rolled out; the production Service should simply **not be routing to it**.
   So:
   - **don't** "repair" the canary (e.g. make it serve on the production port) so that it starts
     taking production traffic — the canary must stay out of the `model-runtime` Service;
   - **don't** delete or scale down `model-canary` — it must keep running, just not behind this
     Service.

   In other words: fix *which pods the Service selects*, not the canary.
4. Be ready to explain what went wrong — including *why only some* requests fail, not all.

## Act 2 — healthy, but should it receive traffic?

The runtime pods carry a `livenessProbe` (→ `/healthz`) and a `readinessProbe` (→ `/readyz`). The
`model-canary` pod has **neither**.

1. Explain how the missing readiness probe relates to the Act 1 failure — i.e. how a pod that
   serves nothing on the Service's port ended up receiving traffic, and how a readiness probe would
   have changed that.
2. In `model-runtime-lab.yaml`, the runtime container has a **`startupProbe` left blank** (a
   `# TODO`). Add one (→ `/readyz`) and be ready to explain the difference between the three probes
   — liveness, readiness, startup — and when a startup probe actually matters.
3. Be ready to trace the path from a failing readiness probe to a dropped request:
   readiness → EndpointSlice → Service → kube-proxy. And explain why the kubelet restarts a pod
   that fails *liveness* but not one that only fails *readiness*.

---

## Acceptance criteria (auto-graded)

`./verify.sh` grades each act independently and prints `PASS`/`FAIL` per check:

- **Act 0:** pod `model-loader` is `Running` and `Ready` (no longer crash-looping).
- **Act 1:** the `model-runtime` Service has exactly **2** ready endpoint addresses (the runtime
  pods only — so the canary is excluded, not repaired into the Service), `model-canary` is still
  running (not deleted/scaled to zero), and 20 consecutive requests from `toolbox` to
  `http://model-runtime/` all return `200`.
- **Act 2:** the `model-runtime` container defines a `startupProbe` whose HTTP path is `/readyz`.

The "be ready to explain" items are assessed by the interviewer, not the grader.

## Self-check

```bash
./verify.sh      # exits 0 only when every check passes
```

(If you stopped after an earlier act, the checks for the acts you skipped will report `FAIL` — that
is expected.)
