import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { pool } from './db.js';
import { downloadEvidence, uploadEvidence } from './storage.js';

export const app = express();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.get('/tickets', async (_req, res, next) => {
  try {
    const result = await pool.query('SELECT * FROM tickets ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (e) { next(e); }
});

app.get('/tickets/:id', async (req, res, next) => {
  try {
    const ticket = await pool.query('SELECT * FROM tickets WHERE id = $1', [req.params.id]);
    if (!ticket.rowCount) return res.status(404).json({ error: 'Ticket not found' });
    const evidence = await pool.query('SELECT * FROM evidence WHERE ticket_id = $1 ORDER BY created_at DESC', [req.params.id]);
    res.json({ ...ticket.rows[0], evidence: evidence.rows });
  } catch (e) { next(e); }
});

app.post('/tickets', async (req, res, next) => {
  try {
    const { title, description, priority } = req.body;
    if (!title || !description || !['low','medium','high'].includes(priority)) {
      return res.status(400).json({ error: 'Invalid ticket data' });
    }
    const result = await pool.query(
      'INSERT INTO tickets(title, description, priority) VALUES ($1,$2,$3) RETURNING *',
      [title, description, priority]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) { next(e); }
});

app.patch('/tickets/:id/status', async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['open','in_progress','resolved'].includes(status)) return res.status(400).json({ error: 'Invalid status' });
    const result = await pool.query('UPDATE tickets SET status=$1 WHERE id=$2 RETURNING *', [status, req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'Ticket not found' });
    res.json(result.rows[0]);
  } catch (e) { next(e); }
});

app.post('/tickets/:id/evidence', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'File is required' });
    const exists = await pool.query('SELECT id FROM tickets WHERE id=$1', [req.params.id]);
    if (!exists.rowCount) return res.status(404).json({ error: 'Ticket not found' });
    const stored = await uploadEvidence(req.file);
    const result = await pool.query(
      `INSERT INTO evidence(ticket_id,file_name,blob_name,content_type)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [req.params.id, req.file.originalname, stored.blobName, req.file.mimetype]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) { next(e); }
});

app.get('/tickets/:ticketId/evidence/:evidenceId', async (req, res, next) => {
  try {
    const result = await pool.query(
      'SELECT * FROM evidence WHERE id=$1 AND ticket_id=$2',
      [req.params.evidenceId, req.params.ticketId]
    );
    if (!result.rowCount) return res.status(404).json({ error: 'Evidence not found' });
    const item = result.rows[0];
    const download = await downloadEvidence(item.blob_name);
    res.setHeader('Content-Type', item.content_type || 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="${item.file_name}"`);
    download.readableStreamBody?.pipe(res);
  } catch (e) { next(e); }
});

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});
