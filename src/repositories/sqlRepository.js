import { getSqlPool } from "../db/sqlClient.js";

function mapRecord(record, columns) {
  if (!record) return null;
  return Object.fromEntries(columns.map(({ property, column }) => [property, record[column]]));
}

// Table and column names come only from static application configuration.
export function createSqlRepository({ table, columns }) {
  const byProperty = new Map(columns.map((column) => [column.property, column]));
  const selectColumns = columns.map(({ column }) => column).join(", ");

  async function execute(query, values = []) {
    const pool = await getSqlPool();
    return pool.query(query, values);
  }

  return {
    async list() {
      const result = await execute(`SELECT ${selectColumns} FROM ${table} ORDER BY created_at ASC;`);
      return result.rows.map((record) => mapRecord(record, columns));
    },
    async findById(id) {
      const result = await execute(`SELECT ${selectColumns} FROM ${table} WHERE id = $1;`, [id]);
      return mapRecord(result.rows[0], columns);
    },
    async create(values) {
      const writable = Object.entries(values).map(([property, value]) => ({ ...byProperty.get(property), value }));
      const fieldNames = writable.map(({ column }) => column).join(", ");
      const valuePlaceholders = writable.map((_, index) => `$${index + 1}`).join(", ");
      const result = await execute(
        `INSERT INTO ${table} (${fieldNames}) VALUES (${valuePlaceholders}) RETURNING ${selectColumns};`,
        writable.map(({ value }) => value)
      );
      return mapRecord(result.rows[0], columns);
    },
    async update(id, values) {
      const writable = Object.entries(values).map(([property, value]) => ({ ...byProperty.get(property), value }));
      const assignments = writable.map(({ column }, index) => `${column} = $${index + 1}`);
      assignments.push("updated_at = now()");
      const result = await execute(
        `UPDATE ${table} SET ${assignments.join(", ")} WHERE id = $${writable.length + 1} RETURNING ${selectColumns};`,
        [...writable.map(({ value }) => value), id]
      );
      return mapRecord(result.rows[0], columns);
    },
    async remove(id) {
      const result = await execute(`DELETE FROM ${table} WHERE id = $1 RETURNING ${selectColumns};`, [id]);
      return mapRecord(result.rows[0], columns);
    }
  };
}
