# Kubernetes Interview Lab

Hands-on Kubernetes troubleshooting. Three **independent** parts, each self-contained — do any one
on its own; there is no required order. Each part ships an **auto-grader** (`verify.sh`) with
concrete pass/fail criteria.

The running example throughout is a small "model platform": a [podinfo](https://github.com/stefanprodan/podinfo)
backend, delivered and operated on Kubernetes.

| Part | Theme | What it exercises | Extra setup |
|------|-------|-------------------|-------------|
| [Part 1](part1-model-runtime/) | The model-runtime Service | Pod crash loops, Service/selector & endpoints, probe/readiness semantics | none |
| [Part 2](part2-gitops-flux/) | GitOps delivery with Flux | Flux sources & releases, reconciliation, drift correction | `flux install` |
| [Part 3](part3-datastore-statefulset/) | The datastore on a StatefulSet | PVC/StorageClass binding, headless Services, StatefulSet immutability, startup probes | none |

Each part is framed as a real symptom to investigate. We care far more about **how you reason**
than about whether you memorised YAML — narrate your thinking, and be ready to explain *why* your
fix is correct, not just *that* it works.

## Prerequisites

- **Any Kubernetes cluster** you have `kubectl` access to — minikube, kind, or a hosted/online
  cluster all work. The lab assumes a working default `StorageClass` (all of the above provide one)
  and makes no assumptions about which distribution you run.
- For Part 2 only: the `flux` CLI and `flux install` (see that part's README).

All workloads use public images (`stefanprodan/podinfo`, `postgres`, `busybox`, `polinux/stress`,
`curlimages/curl`, `nginx`, `alpine/helm`) pulled from Docker Hub — no image loading required
(`kind` pulls them automatically), and no special CNI.

## Running a part

Each part directory has its own `README.md` (the task), one or more manifests, and a `verify.sh`
auto-grader you can run as often as you like:

```bash
cd part1-model-runtime
kubectl apply -f .
./verify.sh      # prints PASS/FAIL per check; exits 0 only when all pass
```

Everything should report `PASS` when the part is solved.
