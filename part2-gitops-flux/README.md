# Part 2 — GitOps delivery with Flux

The `podinfo` app is delivered to the cluster by **Flux**, from a Helm chart hosted **inside the
cluster** (an in-cluster chart server — no external Git or internet). Flux should install podinfo
automatically, but it isn't. Find out why and get GitOps working.

> Everything is self-contained in the cluster. The only external access needed is pulling the Flux
> controller images and the Docker Hub images used by the chart server.

## Prerequisites

- A Kubernetes cluster you have **cluster-admin** on (minikube, kind, or hosted), and `kubectl`.
- The `flux` CLI. Check with `flux --version`. If it's missing, install it — e.g.
  `curl -s https://fluxcd.io/install.sh | sudo bash`, or `brew install fluxcd/tap/flux` — then
  confirm your cluster is ready for Flux with `flux check --pre`.

## What's in `flux-podinfo.yaml`

- Namespace `gitops-lab`: a `chart-server` (nginx) that serves a small Helm repository containing a
  `podinfo` chart. The chart is a plain, readable Helm chart in the `podinfo-chart` ConfigMap,
  packaged on startup. **This is lab infrastructure — you don't need to change it.**
- Namespace `podinfo`: a Flux `HelmRepository` pointing at that in-cluster chart server, and a Flux
  `HelmRelease` that is supposed to install the `podinfo` chart. **This is what you work on.**

## Your task

1. **Install Flux yourself.** Bootstrap the Flux controllers into the cluster (no Git bootstrap
   needed) and confirm they are running:

   ```bash
   flux check --pre          # cluster meets Flux's requirements?
   flux install              # installs the controllers into the flux-system namespace
   flux check                # all controllers healthy
   kubectl get deploy -n flux-system
   ```

   Be ready to say what `flux install` deployed (which controllers, and what each is for).

2. **Deploy the lab** (this creates the in-cluster chart server and the Flux objects). The Flux CRDs
   must already exist, so do this *after* `flux install`:

   ```bash
   kubectl apply -f flux-podinfo.yaml
   kubectl -n gitops-lab rollout status deploy/chart-server   # wait for the chart server
   flux get helmreleases -n podinfo        # podinfo HelmRelease is NOT Ready
   kubectl get deploy -n podinfo           # podinfo is not deployed
   ```

3. **Diagnose.** Using Flux and kubectl, work out why podinfo is not being installed. Useful starting
   points:

   ```bash
   flux get sources helm   -n podinfo
   flux get helmreleases    -n podinfo
   kubectl describe helmrelease podinfo -n podinfo
   kubectl describe helmchart  -n podinfo        # the object Flux creates from the HelmRelease
   ```

   Follow the chain: **HelmRelease → HelmChart → HelmRepository**. Which link is broken, and what is
   the exact error telling you?

4. **Fix it** in `flux-podinfo.yaml`, re-apply, and force a reconcile. podinfo must install:

   ```bash
   kubectl apply -f flux-podinfo.yaml
   flux reconcile helmrelease podinfo -n podinfo
   kubectl -n podinfo rollout status deploy/podinfo
   ```

5. **Demonstrate GitOps drift correction.** With podinfo running, change the live state out of band
   and show what Flux does:

   ```bash
   kubectl -n podinfo scale deploy/podinfo --replicas=5
   flux reconcile helmrelease podinfo -n podinfo
   kubectl -n podinfo get deploy podinfo        # what happened to your 5 replicas?
   ```

6. **Be ready to explain:**
   - what `flux install` put in the cluster — the source-controller vs the helm-controller, and how
     the `HelmRelease → HelmChart → HelmRepository` objects relate;
   - what drift correction did in step 5 and what setting enables it;
   - why names and `sourceRef` references have to line up (what Flux does when they don't);
   - when you would `flux suspend` a HelmRelease, and what `prune`/garbage-collection means in Flux.

## Acceptance criteria (auto-graded)

`./verify.sh` checks:

- the Flux controllers are installed and ready in `flux-system` (you ran `flux install`);
- the `HelmRepository` `local-charts` in `podinfo` is `Ready=True` (the in-cluster chart server is
  reachable and its index was read);
- the `HelmRelease` `podinfo` in `podinfo` is `Ready=True`;
- the `podinfo` Deployment in namespace `podinfo` has at least one available replica.

The drift-correction demo and the explanations are assessed by the interviewer.

## Self-check

```bash
./verify.sh      # exits 0 only when every check passes
```
