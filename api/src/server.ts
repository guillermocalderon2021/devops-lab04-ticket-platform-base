import { app } from './app.js';
import { initializeDatabase } from './db.js';
import { ensureContainer } from './storage.js';
import { config } from './config.js';

await initializeDatabase();
await ensureContainer();

app.listen(config.port, () => console.log(`Ticket API listening on port ${config.port}`));
