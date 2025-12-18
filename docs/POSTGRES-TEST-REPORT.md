 PostgreSQL Deployment Test Report

**Date:** December 12, 2025
**Cluster:** app-demo (Kind)
**Namespace:** app-demo

## Test Results Summary

### ✅ All Tests Passed

| Test | Status | Details |
|------|--------|---------|
| Pod Deployment | ✅ PASS | postgres-0 running (1/1 Ready) |
| Service Creation | ✅ PASS | ClusterIP service on port 5432 |
| Persistent Volume | ✅ PASS | 2Gi PVC bound successfully |
| Database Connection | ✅ PASS | Accepting connections on port 5432 |
| Database Initialization | ✅ PASS | cicd_demo database created |
| Permissions Fix | ✅ PASS | Init container resolved fsGroup issue |

## Deployment Details

### 1. Issue Identified and Fixed

**Problem:** Initial deployment failed with `CrashLoopBackOff`
```
chmod: /var/lib/postgresql/data: Operation not permitted
initdb: error: could not change permissions of directory "/var/lib/postgresql/data": Operation not permitted
```

**Root Cause:** Kind's local-path-provisioner creates PVC directories with root ownership, but PostgreSQL container runs as UID 999 (non-root).

**Solution:** Added init container to fix permissions before PostgreSQL starts:
```yaml
initContainers:
- name: fix-permissions
  image: postgres:16-alpine
  command: ['sh', '-c', 'chown -R 999:999 /var/lib/postgresql/data || true']
  volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data
    subPath: postgres
  securityContext:
    runAsUser: 0  # Init container runs as root temporarily
```

### 2. Current Deployment State

**Pod Status:**
```
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   1/1     Running   0          2m51s
```

**Service:**
```
NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
postgres   ClusterIP   10.96.204.25   <none>        5432/TCP   5m59s
```

**Persistent Volume Claim:**
```
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
postgres-pvc   Bound    pvc-ceb82c83-d5e5-404b-bb75-2d6e275c0dda   2Gi        RWO            standard
```

**Database Connection Test:**
```
/var/run/postgresql:5432 - accepting connections
```

**Databases Created:**
- `postgres` (default)
- `cicd_demo` (application database)
- `template0` (template)
- `template1` (template)

### 3. Security Compliance

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Non-root User | ✅ | PostgreSQL runs as UID 999 |
| Resource Limits | ✅ | 256Mi-512Mi memory, 250m-500m CPU |
| FSGroup | ✅ | fsGroup: 999 for volume ownership |
| Health Probes | ✅ | Liveness + Readiness with pg_isready |
| Kyverno Labels | ✅ | app.kubernetes.io/name and instance |

### 4. Database Configuration

**Environment Variables (from ConfigMap):**
- `POSTGRES_DB`: cicd_demo
- `POSTGRES_USER`: app_user

**Environment Variables (from Secret):**
- `POSTGRES_PASSWORD`: (base64 encoded - cicd_demo_pass)

**Connection Details for Backend:**
- Host: `postgres` (ClusterIP service name)
- Port: `5432`
- Database: `cicd_demo`
- User: `app_user`
- Password: From secret postgres-secret

### 5. Database Schema Status

**Current State:** Empty (no tables yet)
```
Did not find any relations.
```

**Expected Behavior:** ✅ Correct
- Flyway will create schema when backend application starts
- Migration file ready: `src/main/resources/db/migration/V1__initial_schema.sql`
- Will create `tasks` table with sample data

## Next Steps

### Immediate: Deploy Backend Application

1. **Trigger Jenkins Pipeline:**
   ```bash
   # Via Jenkins UI: http://localhost:8080
   # Click "Build Now" on CICD-Demo pipeline
   ```

2. **Pipeline will:**
   - Build Spring Boot application with Maven
   - Run unit tests
   - Perform SonarQube analysis
   - Build Docker image
   - Push to Harbor registry
   - Load image into Kind cluster
   - Update Helm chart values
   - Deploy via ArgoCD

3. **Backend will connect to PostgreSQL:**
   - Environment variables from Helm values.yaml:
     - `DB_HOST=postgres`
     - `DB_NAME=cicd_demo`
     - `DB_USER=app_user`
     - `DB_PASSWORD` from secret
   - Flyway will run `V1__initial_schema.sql` migration
   - Creates `tasks` table with 5 sample tasks

### Verification Commands

**Monitor Backend Deployment:**
```bash
kubectl get pods -n app-demo -l app.kubernetes.io/component=backend -w
```

**Check Backend Logs (after deployment):**
```bash
kubectl logs -n app-demo -l app.kubernetes.io/component=backend --tail=100 -f
```

**Verify Flyway Migration:**
```bash
docker exec app-demo-control-plane kubectl exec -n app-demo postgres-0 -- \
  psql -U app_user -d cicd_demo -c "\dt"
# Should show: tasks, flyway_schema_history
```

**Test Backend API (after deployment):**
```bash
kubectl port-forward -n app-demo svc/cicd-demo-backend 8001:8001 &
curl http://localhost:8001/api/tasks
curl http://localhost:8001/api/tasks/stats
```

### Deploy Frontend Application

After backend is running:

1. **Frontend Build (automatic in Jenkins pipeline)**
   - Build React + TypeScript application
   - Create production bundle with Vite
   - Build Nginx-based Docker image
   - Push to Harbor
   - Deploy via ArgoCD

2. **Access Frontend:**
   ```
   http://localhost:30080
   ```

3. **Frontend Features:**
   - Task list with filtering
   - Statistics dashboard (5 cards)
   - Create/delete tasks
   - Status badges with colors

## Troubleshooting Reference

### PostgreSQL Pod Won't Start

**Check logs:**
```bash
kubectl logs -n app-demo postgres-0
```

**Common issues:**
- Permission errors → Init container should fix this
- PVC not bound → Check `kubectl get pvc -n app-demo`
- Resource limits → Reduce memory/CPU if needed

### Backend Can't Connect to Database

**Test from backend pod:**
```bash
kubectl exec -n app-demo deployment/cicd-demo-backend -- \
  nc -zv postgres 5432
```

**Check environment variables:**
```bash
kubectl exec -n app-demo deployment/cicd-demo-backend -- env | grep DB_
```

**Expected output:**
```
DB_HOST=postgres
DB_NAME=cicd_demo
DB_USER=app_user
DB_PASSWORD=cicd_demo_pass
```

### Database Connection from Outside Cluster

**Port forward PostgreSQL:**
```bash
kubectl port-forward -n app-demo svc/postgres 5432:5432 &
```

**Connect with psql:**
```bash
psql -h localhost -p 5432 -U app_user -d cicd_demo
# Password: cicd_demo_pass
```

## Conclusion

✅ **PostgreSQL deployment is fully operational and ready for backend integration.**

The database layer is properly configured with:
- Persistent storage (2Gi PVC)
- Non-root security context (Kyverno compliant)
- Health probes for Kubernetes monitoring
- Proper resource limits
- Init container workaround for Kind volume permissions

The application is now ready for the next phase: deploying the Spring Boot backend via Jenkins CI/CD pipeline.
