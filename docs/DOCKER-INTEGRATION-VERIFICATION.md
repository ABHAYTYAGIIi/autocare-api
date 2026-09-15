# AutoCare API — Docker Integration & Maintenance Analysis Verification

## 1. Purpose

This document records the Docker build, runtime verification, automated tests, and end-to-end maintenance-analysis test conducted for `autocare-api`.

The verification covered:

- Docker image creation.
- Container startup.
- API health.
- Local in-memory persistence.
- API-to-maintenance-service communication.
- Customer and vehicle creation through the running container.
- End-to-end maintenance analysis.
- The automated Node.js test suite.

---

## 2. Architecture Verified

The local integration path was:

```text
PowerShell / HTTP client
        |
        | HTTP :3000
        v
+--------------------------+
| autocare-api-local       |
| Node.js 22 + Express     |
| /api                     |
+------------+-------------+
             |
             | POST /maintenance-analysis
             | MAINTENANCE_SERVICE_URL
             v
+--------------------------+
| maintenance service      |
| FastAPI + Uvicorn        |
| :8001                    |
+--------------------------+
```

The AutoCare API endpoint tested was:

```text
POST /api/vehicles/:id/maintenance-analysis
```

The API internally forwards the analysis request to:

```text
POST /maintenance-analysis
```

on the configured maintenance service.

---

## 3. Dockerfile Used

```dockerfile
FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --chown=node:node src ./src

ENV NODE_ENV=production
EXPOSE 3000

USER node
CMD ["npm", "start"]
```

Important characteristics:

- Base image: `node:22-bookworm-slim`.
- Working directory: `/app`.
- Dependency installation: `npm ci --omit=dev`.
- Application source copied: `src/`.
- Port: `3000`.
- Runtime user: non-root `node`.
- Startup command: `npm start`, which runs `node src/server.js`.

---

## 4. Initial Container Failure and Resolution

The first container run failed with:

```text
Error: Production requires DATABASE_PROVIDER=azure-sql; in-memory persistence is not permitted.
```

The reason was the combination of:

```dockerfile
ENV NODE_ENV=production
```

and the application's default database provider:

```text
DATABASE_PROVIDER=memory
```

The application intentionally rejects in-memory persistence when `NODE_ENV=production`.

For local integration testing, the container was therefore started with explicit development configuration:

```text
NODE_ENV=development
DATABASE_PROVIDER=memory
FRONTEND_ORIGIN=http://localhost:5173
MAINTENANCE_SERVICE_URL=http://host.docker.internal:8001
MAINTENANCE_SERVICE_TIMEOUT_MS=5000
```

No application source code was changed to bypass this production safeguard.

---

## 5. Docker Image Build Test

Command:

```powershell
docker build -t autocare-api:local .
```

Observed result:

```text
[+] Building 14.6s (10/10) FINISHED
```

The build successfully:

1. Pulled `node:22-bookworm-slim`.
2. Created `/app` as the working directory.
3. Copied `package.json` and `package-lock.json`.
4. Ran `npm ci --omit=dev`.
5. Copied `src/` into the image with ownership assigned to `node`.
6. Exported the image and tagged it `autocare-api:local`.

### Result

**PASS — Docker image builds successfully.**

---

## 6. Container Startup Test

After supplying local development environment variables, the container started and logged:

```text
AutoCare API listening on port 3000
```

The running container exposed:

```text
0.0.0.0:3000->3000/tcp
```

The maintenance-service container was already running on port `8001`.

### Result

**PASS — AutoCare API runs successfully inside Docker.**

---

## 7. Runtime Environment Verification

The actual environment stored in the container was inspected with:

```powershell
docker inspect autocare-api-local --format '{{range .Config.Env}}{{println .}}{{end}}'
```

Relevant values observed:

```text
DATABASE_PROVIDER=memory
FRONTEND_ORIGIN=http://localhost:5173
MAINTENANCE_SERVICE_URL=http://host.docker.internal:8001
NODE_ENV=development
```

`host.docker.internal` was used because `localhost` from inside the API container would refer to the API container itself rather than the Windows host.

---

## 8. Health Endpoint Test

Command:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
```

Observed result:

```text
service      status databaseConfigured
-------      ------ ------------------
autocare-api ok                  False
```

Interpretation:

- `service=autocare-api`: the correct service responded.
- `status=ok`: the API health check succeeded.
- `databaseConfigured=False`: expected because this local run intentionally uses `DATABASE_PROVIDER=memory`.

### Result

**PASS — API health endpoint responds successfully.**

---

## 9. Customer Creation Test

A customer was created through the running containerized API:

```powershell
$customer = Invoke-RestMethod `
  -Uri http://localhost:3000/api/customers `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"name":"Docker Integration Test","email":"docker@test.example","phone":"+91-9000000000"}'
```

The API returned a generated customer ID and customer data.

Observed customer ID:

```text
9f490617-6a9d-41d3-8fe8-631edbd3d05a
```

### Result

**PASS — Customer creation works through the Dockerized API.**

---

## 10. Vehicle Creation Test

A vehicle was created using the customer ID returned by the API:

```powershell
$vehicle = Invoke-RestMethod `
  -Uri http://localhost:3000/api/vehicles `
  -Method Post `
  -ContentType "application/json" `
  -Body "{`"customerId`":`"$($customer.data.id)`",`"make`":`"Tata`",`"model`":`"Nexon`",`"year`":2021,`"licensePlate`":`"DOCKER-01`",`"mileage`":56000}"
```

Observed vehicle ID:

```text
e286af72-adf8-43c2-b952-376aaa55f645
```

### Result

**PASS — Vehicle creation and the customer/vehicle relationship work through Docker.**

---

## 11. End-to-End Maintenance Analysis Test

The real running API was called with:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:3000/api/vehicles/$($vehicle.data.id)/maintenance-analysis" `
  -Method Post `
  -ContentType "application/json" `
  -Body "{}"
```

The API returned:

```text
riskLevel = medium
recommendation = Schedule a routine maintenance check.
```

This proves the real runtime path:

```text
HTTP client
  -> AutoCare API container
  -> vehicle lookup
  -> maintenance-analysis service logic
  -> maintenance HTTP client
  -> maintenance-service container
  -> FastAPI/Uvicorn
  -> analysis response
  -> response validation
  -> AutoCare API response
  -> HTTP client
```

### Result

**PASS — Real container-to-container/application integration is working.**

---

## 12. Automated Tests

The repository contains:

```text
test/maintenance-http.integration.test.js
test/persistence.smoke.test.js
```

The automated suite verifies application behavior independently of the manually created Docker test data.

### PowerShell npm issue

The initial `npm test` command was blocked by the Windows PowerShell execution policy because `npm.ps1` could not be loaded.

The Windows command shim was used instead:

```powershell
npm.cmd ci
npm.cmd test
```

This avoided changing the machine-wide PowerShell execution policy.

### Final automated result

```text
tests 9
pass 9
fail 0
cancelled 0
skipped 0
todo 0
```

### Result

**PASS — 9/9 automated tests passed.**

---

## 13. What the Automated Tests Verify

### `maintenance-http.integration.test.js`

Verifies that Express forwards maintenance-analysis data to a FastAPI-compatible HTTP service and correctly consumes the returned risk level and recommendation.

The expected forwarded payload includes:

```json
{
  "mileage": 56000,
  "vehicle_age_years": 5,
  "service_history": ["Integration Service"]
}
```

### `persistence.smoke.test.js`

Verifies:

- Customer creation.
- Vehicle/customer relationship.
- Service type creation.
- Booking creation with valid references.
- Rejection of invalid booking references.
- Maintenance-analysis input construction from vehicle and completed service history.
- Maintenance client request construction.
- Maintenance client timeout translation to HTTP 504.

---

## 14. Maintenance Client Error Handling

The maintenance client maps failures as follows:

| Condition | API result |
|---|---|
| Maintenance service timeout | HTTP 504 |
| Maintenance service unavailable | HTTP 502 |
| Maintenance service returns unsuccessful response | HTTP 502 |
| Invalid JSON response | HTTP 502 |
| Unexpected analysis payload | HTTP 502 |

The automated suite specifically verifies timeout-to-504 behavior.

---

## 15. Verification Summary

| Check | Result |
|---|---|
| Docker image build | PASS |
| Container startup | PASS |
| API health endpoint | PASS |
| Customer creation | PASS |
| Vehicle creation | PASS |
| Maintenance-analysis endpoint | PASS |
| API → maintenance service communication | PASS |
| Automated test suite | PASS |
| Automated tests | 9/9 passed |
| Azure SQL | Not tested yet; local run uses memory |

---

## 16. Local vs Production Boundary

The successful local Docker test uses:

```text
NODE_ENV=development
DATABASE_PROVIDER=memory
```

This verifies application and service integration but does **not** prove Azure SQL connectivity.

The application requires:

```text
DATABASE_PROVIDER=azure-sql
```

when running with:

```text
NODE_ENV=production
```

The Azure SQL host, database name, username, password, encryption, and certificate-trust settings have therefore not been validated by this test record.

---

## 17. Conclusion

`autocare-api` has been verified at three levels:

1. **Application level** — automated tests pass and maintenance-analysis logic is verified.
2. **Container level** — the Node.js application builds and runs successfully in Docker.
3. **Integration level** — the running API successfully communicates with the maintenance-analysis service and returns its recommendation.

**Current status: AutoCare API local Docker integration verified successfully.**

The next deployment-specific work is Azure SQL configuration and then Kubernetes/AKS deployment validation.
