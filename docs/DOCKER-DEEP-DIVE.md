# Docker Deep Dive — AutoCare API

## Purpose

This document analyzes the AutoCare API as a **Linux-server deployment**, not as a Windows/WSL setup.

It covers:

- Dockerfile instruction semantics.
- Build context and image layers.
- Which application files are needed at runtime.
- Environment variables and database credentials.
- Container paths and ports.
- Linux process/filesystem/network isolation.
- The difference between image build time and container runtime.

## Important repository state

At the time this document was created, the GitHub `main` branch contains the Node.js application but **does not contain a `Dockerfile`**. Therefore a truthful line-by-line Dockerfile explanation cannot be fabricated from the repository.

The application/build information below is verified from the repository. The Dockerfile section is intentionally marked as pending until the actual Dockerfile is committed to this repository.

---

## 1. Application runtime

`package.json` defines:

```text
start = node src/server.js
dev   = node --watch src/server.js
test  = node --test
```

The production application therefore starts at:

```text
node src/server.js
```

`src/server.js` imports:

```text
./app.js
./config/environment.js
./db/sqlClient.js
```

It initializes the database and then calls `app.listen(environment.port, ...)`.

The Express application is defined in `src/app.js`. It configures CORS, JSON parsing, the `/api` router, and centralized error handling.

---

## 2. Files that participate in startup

The important startup chain is:

```text
src/server.js
   |
   +--> src/app.js
   |      |
   |      +--> src/config/environment.js
   |      +--> src/routes/index.js
   |
   +--> src/config/environment.js
   |
   +--> src/db/sqlClient.js
          |
          +--> src/db/database.js
```

The repository also contains clients, controllers, repositories, services, routes, database code, and tests. A Dockerfile should copy only what is required by the runtime rather than assuming every repository file must be present in the final image.

---

## 3. Dockerfile status

**Current verified state:** no `Dockerfile` exists on GitHub `main`.

Because Dockerfile behavior is completely instruction-dependent, the following details must not be guessed:

- base image;
- Node.js version;
- package-manager commands;
- whether dependencies are installed with `npm ci` or another command;
- whether a multi-stage build is used;
- final working directory;
- Linux runtime user;
- exposed port;
- final `CMD`/`ENTRYPOINT`;
- files copied into the final image;
- build-time arguments.

Once the real Dockerfile is committed, this document should be extended with a line-by-line table using the exact instructions from that file.

---

## 4. Verified dependency/build information

`package.json` declares these runtime dependencies:

- `cors`
- `dotenv`
- `express`
- `mssql`

There is a `package-lock.json`, so a production Docker build should normally use the lockfile-respecting npm installation strategy chosen by the eventual Dockerfile.

The source is JavaScript/ES modules (`"type": "module"`). There is no TypeScript compilation step shown in `package.json`.

Therefore, based strictly on the repository, the application is a Node.js runtime application rather than a compiled native binary.

---

## 5. Environment variables

The repository's `.env.example` defines:

```text
PORT=3000
NODE_ENV=development
FRONTEND_ORIGIN=http://localhost:5173
MAINTENANCE_SERVICE_URL=http://localhost:8001
MAINTENANCE_SERVICE_TIMEOUT_MS=5000
DATABASE_PROVIDER=memory
DATABASE_HOST=your-server.database.windows.net
DATABASE_PORT=1433
DATABASE_NAME=autocare
DATABASE_USER=autocare_app
DATABASE_PASSWORD=replace-me
DATABASE_ENCRYPT=true
DATABASE_TRUST_SERVER_CERTIFICATE=false
```

`src/config/environment.js` reads these values through `dotenv`.

### Database modes

The code explicitly supports:

- `memory`
- `azure-sql`

Production requires `DATABASE_PROVIDER=azure-sql`.

When Azure SQL is selected, the code requires:

- `DATABASE_HOST`
- `DATABASE_NAME`
- `DATABASE_USER`
- `DATABASE_PASSWORD`

The SQL connection is created by `src/db/sqlClient.js` using the `mssql` package.

### Credential handling

The actual password is not hardcoded in the source shown. `.env.example` contains only a placeholder.

Production credentials should be injected by the Linux deployment environment, secret store, Compose/Kubernetes configuration, or another secure mechanism. They should not be baked into an image layer.

---

## 6. Application paths

The repository's source paths are relative to the project root:

```text
src/server.js
src/app.js
src/config/environment.js
src/db/sqlClient.js
src/db/database.js
package.json
package-lock.json
.env.example
```

The **container paths cannot yet be stated as facts** because they depend on the missing Dockerfile's `WORKDIR` and `COPY` instructions.

For example, it would be wrong to claim `/app/src/server.js` until the Dockerfile establishes `/app` as the working directory and copies the source there.

---

## 7. Linux OS-level model

When this service eventually runs in Docker on a Linux server, the important model is:

```text
Linux host kernel
      |
      +-- Docker Engine
             |
             +-- Node.js container
                    |
                    +-- Node process
                           |
                           +-- src/server.js
```

The container is not a virtual machine and does not boot its own kernel.

Docker provides an isolated process/filesystem/network environment while the host Linux kernel executes the container's processes.

Typical Linux mechanisms involved include:

- namespaces for isolation;
- cgroups for resource control;
- container filesystem layers;
- Linux capabilities/security restrictions;
- virtual networking and network namespaces.

The exact security profile depends on the Docker runtime configuration and host.

---

## 8. Build vs runtime

### Build time

The eventual Dockerfile will execute package installation and copy application files into image layers.

The important principle is:

```text
Dockerfile + build context
          |
          v
     image layers
          |
          v
     immutable image
```

### Runtime

At runtime Docker creates a container from that image and starts the Node.js process using the image's configured command.

Environment variables supplied at runtime can change behavior without rebuilding the image.

---

## 9. Maintenance-service dependency

The API environment configuration includes:

```text
MAINTENANCE_SERVICE_URL=http://localhost:8001
MAINTENANCE_SERVICE_TIMEOUT_MS=5000
```

This means the API has an application-level dependency on the maintenance service URL. In a Linux Docker deployment, `localhost` has an important meaning: **inside a container, `localhost` refers to that same container**.

Therefore, if the API and maintenance service run in separate containers, the production value must normally point to the appropriate container/service network name rather than blindly using `localhost`.

This is a runtime networking concern, not a Dockerfile build concern.

---

## 10. Deep-dive checklist for the missing Dockerfile

When the Dockerfile is added, document each instruction in this exact order:

| Question | What to determine |
|---|---|
| Base | Which Linux userspace/base image is inherited? |
| Working directory | Where does the Node process start? |
| ENV | Which variables are baked into the image? |
| ARG | Which values exist only during build? |
| COPY | Which repository files enter the image? |
| RUN | Which packages/users/directories are created? |
| USER | Does Node run as root or non-root? |
| EXPOSE | Which application port is documented? |
| CMD/ENTRYPOINT | What exact process becomes PID 1? |
| Multi-stage | Which build artifacts survive into the final image? |
| Secrets | Are any credentials accidentally included in layers? |
| OS impact | Which filesystem/user/process/network effects occur? |

This prevents us from confusing repository source code with image contents.
