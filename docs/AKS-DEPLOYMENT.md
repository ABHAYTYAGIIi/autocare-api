# AutoCare API — AKS Deployment

## Status

The AutoCare API is deployed and verified in the `dev` namespace of AKS.

The deployed application uses Azure SQL for persistence and communicates with the AutoCare maintenance-analysis service through a Kubernetes ClusterIP Service.

## Complete architecture

```text
                         Internet / Browser
                                |
                                | HTTP
                                v
                    +--------------------------+
                    | Azure Application Gateway |
                    | Public IP: 4.247.238.128 |
                    +------------+-------------+
                                 |
                                 | Kubernetes Ingress
                                 | /autocare/
                                 v
                    +--------------------------+
                    | autocare-frontend Service |
                    | ClusterIP :8080           |
                    +------------+-------------+
                                 |
                                 v
                    +--------------------------+
                    | Frontend nginx            |
                    | React static application   |
                    | /autocare/api/ proxy      |
                    +------------+-------------+
                                 |
                                 | http://autocare-api:3000
                                 v
                    +--------------------------+
                    | autocare-api Service      |
                    | ClusterIP :3000           |
                    +------------+-------------+
                                 |
                                 v
                    +--------------------------+
                    | AutoCare API Pod          |
                    | Node.js + Express :3000   |
                    +------------+-------------+
                         |                 |
                         | SQL             | HTTP
                         v                 v
              +------------------+  +-----------------------------+
              | Azure SQL        |  | autocare-maintenance-service |
              | sql-azure-project |  | ClusterIP :8001             |
              | sqldb-autocare-dev|  | FastAPI / Uvicorn           |
              +------------------+  +-----------------------------+

Secrets/configuration:

  Azure Key Vault
        |
        | Workload Identity + Key Vault CSI
        v
  Kubernetes Secret / mounted secret
        |
        v
  AutoCare API Pod
```

## Kubernetes environment

- Cluster: `aks-azure-project`
- Resource group: `rg-azure-aks`
- Namespace: `dev`
- ACR: `acrazureproject.azurecr.io`
- API Service: `autocare-api:3000`
- Maintenance Service: `autocare-maintenance-service:8001`

## Database

The `dev` API uses:

```text
Provider: azure-sql
Host:     sql-azure-project.database.windows.net
Database: sqldb-autocare-dev
Port:     1433
```

The application validates the Azure SQL configuration at startup and establishes the SQL connection before starting the HTTP server.

The repository contains the database lifecycle scripts:

```text
database/schema.sql
database/seed.sql
```

For the current `dev` environment, the schema and development seed were applied to `sqldb-autocare-dev`. The resulting database contains the application tables for customers, vehicles, service centers, service types, and bookings.

Database schema/seed execution is currently a deployment lifecycle operation; the API startup process validates/connects to the database but does not create the schema automatically.

## Maintenance-service integration

The API exposes:

```text
GET  /api/health
POST /api/vehicles/:id/maintenance-analysis
```

For maintenance analysis, the API obtains vehicle data from SQL and calls:

```text
POST http://autocare-maintenance-service:8001/maintenance-analysis
```

The maintenance service returns a risk level and recommendation, which the API returns to the caller.

## Configuration

The `dev` Kubernetes ConfigMap provides non-secret settings including:

```text
PORT=3000
NODE_ENV=production
FRONTEND_ORIGIN=/autocare
MAINTENANCE_SERVICE_URL=http://autocare-maintenance-service:8001
MAINTENANCE_SERVICE_TIMEOUT_MS=5000
DATABASE_PROVIDER=azure-sql
DATABASE_HOST=sql-azure-project.database.windows.net
DATABASE_PORT=1433
DATABASE_NAME=sqldb-autocare-dev
DATABASE_ENCRYPT=true
DATABASE_TRUST_SERVER_CERTIFICATE=false
```

The database password is not stored in the ConfigMap. It is supplied through the Azure Key Vault integration.

## Azure Key Vault / Workload Identity

The API workload uses the Azure Workload Identity integration configured for AKS.

The flow is:

```text
Kubernetes ServiceAccount
        |
        | federated identity
        v
User Assigned Managed Identity
        |
        | Key Vault authorization
        v
Azure Key Vault
        |
        v
Kubernetes Secret / CSI mounted secret
        |
        v
AutoCare API
```

The current development workload uses the `autocare-api` ServiceAccount in the `dev` namespace.

## Public endpoint

The current development application is externally reachable at:

```text
http://4.247.238.128/autocare/
```

The current endpoint is HTTP using the Application Gateway public IP. Domain-name and HTTPS/TLS configuration are future deployment work.

## Ingress

The current Ingress uses:

```yaml
ingressClassName: azure-application-gateway
```

and routes:

```text
/autocare/ -> autocare-frontend:8080
```

The frontend nginx then proxies API requests under `/autocare/api/` to the internal `autocare-api:3000` Service.

## Verification completed

The following paths were verified from inside the cluster:

```text
Frontend Service
  GET /autocare/
  -> 200 OK

Frontend nginx
  GET /autocare/api/health
  -> AutoCare API 200 OK
```

The public Application Gateway path was also verified:

```text
GET http://4.247.238.128/autocare/
-> 200 OK

GET http://4.247.238.128/autocare/api/health
-> 200 OK
```

The API-to-maintenance-service endpoint was verified with the seeded vehicle and returned a successful maintenance analysis.

## Current deployment approach

The current `dev` deployment is intentionally manual. Container images are built and pushed to ACR, then Kubernetes Deployments are updated with the selected image tag.

Example:

```powershell
az acr login --name acrazureproject

docker build -t acrazureproject.azurecr.io/autocare-api:<tag> .
docker push acrazureproject.azurecr.io/autocare-api:<tag>

kubectl set image deployment/autocare-api `
  api=acrazureproject.azurecr.io/autocare-api:<tag> `
  -n dev
```

## Future deployment model

The long-term deployment model will use:

```text
Git push
   -> CI build/test
   -> Docker image
   -> Azure Container Registry
   -> image tag/digest
   -> Kustomize environment overlay
   -> CD deployment to AKS
```

Kustomize will eventually manage environment-specific configuration and image references instead of manually changing image tags in Deployment manifests.

## Operational notes

- Keep application Services as ClusterIP for internal service-to-service communication.
- Do not expose the API directly through a public LoadBalancer when the frontend proxy and Application Gateway are the intended entry path.
- Keep database passwords and other credentials out of ConfigMaps and source control.
- Keep separate database/configuration/secrets per environment.
- Treat database schema provisioning as a deployment lifecycle responsibility rather than relying on application startup.
