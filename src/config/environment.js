import "dotenv/config";

const databaseProvider = process.env.DATABASE_PROVIDER || "memory";
const maintenanceServiceTimeoutMs = Number(process.env.MAINTENANCE_SERVICE_TIMEOUT_MS || 5000);

if (!["memory", "postgres"].includes(databaseProvider)) {
  throw new Error("DATABASE_PROVIDER must be either 'memory' or 'postgres'.");
}

if ((process.env.NODE_ENV || "development") === "production" && databaseProvider !== "postgres") {
  throw new Error("Production requires DATABASE_PROVIDER=postgres; in-memory persistence is not permitted.");
}

if (!Number.isInteger(maintenanceServiceTimeoutMs) || maintenanceServiceTimeoutMs < 1) {
  throw new Error("MAINTENANCE_SERVICE_TIMEOUT_MS must be a positive integer.");
}

export const environment = {
  port: Number(process.env.PORT || 3000),
  nodeEnv: process.env.NODE_ENV || "development",
  frontendOrigin: process.env.FRONTEND_ORIGIN || "http://localhost:5173",
  maintenanceServiceUrl: process.env.MAINTENANCE_SERVICE_URL || "http://localhost:8001",
  maintenanceServiceTimeoutMs,
  database: {
    provider: databaseProvider,
    host: process.env.DATABASE_HOST,
    port: Number(process.env.DATABASE_PORT || 5432),
    name: process.env.DATABASE_NAME,
    user: process.env.DATABASE_USER,
    password: process.env.DATABASE_PASSWORD,
    ssl: process.env.DATABASE_SSL !== "false"
  }
};
