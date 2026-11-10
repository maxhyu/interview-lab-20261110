# Part 3 — The datastore on a StatefulSet

The model platform needs a Postgres datastore. It's defined as a `StatefulSet` in
`datastore-statefulset-scaffold.yaml`, but it won't come up — and the manifest has two fields left
blank for you to complete.

No special setup: uses the `postgres:16-alpine` and `busybox:1.36` Docker Hub images and your
cluster's default `StorageClass` (minikube, kind, and hosted clusters all provide one). A
`db-toolbox` pod is provided for DNS/connectivity checks.

```bash
kubectl apply -f datastore-statefulset-scaffold.yaml
kubectl get pods -n data-platform-lab -w
```

## Your task

1. **The pod never starts.** `postgres-0` is stuck. Work out why it isn't being scheduled — look at
   the pod *and* the PersistentVolumeClaim it depends on:

   ```bash
   kubectl describe pod postgres-0 -n data-platform-lab
   kubectl get pvc -n data-platform-lab
   kubectl describe pvc data-postgres-0 -n data-platform-lab
   kubectl get storageclass
   ```

   Fix the storage configuration so the claim binds and the pod schedules.
   **Heads-up:** several fields here are immutable — if `kubectl apply` is rejected, read the error
   and work out what you have to recreate (the StatefulSet's `volumeClaimTemplates`, the already-
   created PVC, and — once you make the Service headless in step 2 — the Service's `clusterIP` are
   all immutable). The simplest path is to edit the manifest, delete the affected objects, and
   re-apply.

2. **Fill in the two blanks** (both marked `# TODO`) and be ready to explain each:
   - make the governing `Service` **headless** (the field is left blank);
   - add the **`startupProbe`** on the container (a commented skeleton is provided), and explain why
     a database that runs `initdb` on first boot wants a startup probe ahead of liveness.

3. **Prove it works** from `db-toolbox`:

   ```bash
   # per-pod DNS name for the StatefulSet pod:
   kubectl exec -n data-platform-lab db-toolbox -- nslookup postgres-0.postgres.data-platform-lab.svc.cluster.local
   # the service name: headless returns the pod IP(s); a ClusterIP returns one VIP:
   kubectl exec -n data-platform-lab db-toolbox -- nslookup postgres.data-platform-lab.svc.cluster.local
   # reach postgres through the Service:
   kubectl exec -n data-platform-lab db-toolbox -- nc -z -w3 postgres 5432
   ```

4. **Be ready to explain:**
   - the difference between a pod that is `Pending` (can't be scheduled) and one that `CrashLoops`,
     and which events told you which this was;
   - what binds a PVC to a PV, and the role of the StorageClass and its provisioner;
   - why you couldn't just `kubectl apply` the storage fix — which StatefulSet fields are immutable
     and why the old PVC also had to go;
   - what a **headless** Service gives a StatefulSet that a normal ClusterIP does not;
   - why this is a `StatefulSet` with `volumeClaimTemplates` and not a `Deployment` with a shared
     volume.

## Acceptance criteria (auto-graded)

`./verify.sh` checks:

- PVC `data-postgres-0` is `Bound`;
- the `postgres` StatefulSet reports `readyReplicas: 1`;
- the `postgres` Service is headless (`clusterIP: None`);
- the container defines a `startupProbe`;
- `postgres-0.postgres.data-platform-lab.svc.cluster.local` resolves from `db-toolbox`;
- `postgres:5432` is reachable through the Service from `db-toolbox`.

## Self-check

```bash
./verify.sh      # exits 0 only when every check passes
```
