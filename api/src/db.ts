import pg from 'pg';
import { config } from './config.js';

const { Pool } = pg;

export const pool = new Pool({
  host: config.database.host,
  port: config.database.port,
  database: config.database.name,
  user: config.database.user,
  password: config.database.password,
  ssl: config.database.ssl ? { rejectUnauthorized: false } : false
});

export async function initializeDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tickets (
      id BIGSERIAL PRIMARY KEY,
      title VARCHAR(160) NOT NULL,
      description TEXT NOT NULL,
      priority VARCHAR(20) NOT NULL CHECK (priority IN ('low','medium','high')),
      status VARCHAR(30) NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS evidence (
      id BIGSERIAL PRIMARY KEY,
      ticket_id BIGINT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
      file_name VARCHAR(255) NOT NULL,
      blob_name VARCHAR(255) NOT NULL UNIQUE,
      content_type VARCHAR(120),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}
