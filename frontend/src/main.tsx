import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

type Ticket = {
  id: number;
  title: string;
  description: string;
  priority: 'low' | 'medium' | 'high';
  status: 'open' | 'in_progress' | 'resolved';
  created_at: string;
  evidence?: Evidence[];
};

type Evidence = {
  id: number;
  file_name: string;
  content_type: string | null;
};

const API = import.meta.env.VITE_API_URL ?? '/api';

function App() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selected, setSelected] = useState<Ticket | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<Ticket['priority']>('medium');

  async function loadTickets() {
    const response = await fetch(`${API}/tickets`);
    setTickets(await response.json());
  }

  async function loadTicket(id: number) {
    const response = await fetch(`${API}/tickets/${id}`);
    setSelected(await response.json());
  }

  useEffect(() => {
    let cancelled = false;

    async function fetchInitialTickets() {
      const response = await fetch(`${API}/tickets`);
      const data = await response.json() as Ticket[];
      if (!cancelled) {
        setTickets(data);
      }
    }

    void fetchInitialTickets();

    return () => {
      cancelled = true;
    };
  }, []);

  async function createTicket(event: React.FormEvent) {
    event.preventDefault();
    await fetch(`${API}/tickets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, description, priority })
    });
    setTitle(''); setDescription(''); setPriority('medium');
    await loadTickets();
  }

  async function changeStatus(status: Ticket['status']) {
    if (!selected) return;
    await fetch(`${API}/tickets/${selected.id}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status })
    });
    await loadTicket(selected.id);
    await loadTickets();
  }

  async function uploadEvidence(file?: File) {
    if (!selected || !file) return;
    const form = new FormData();
    form.append('file', file);
    await fetch(`${API}/tickets/${selected.id}/evidence`, { method: 'POST', body: form });
    await loadTicket(selected.id);
  }

  return (
    <main className="page">
      <header>
        <p className="eyebrow">DevOps · Lab 4</p>
        <h1>Ticket Platform</h1>
        <p>Registro de incidentes y evidencias técnicas.</p>
      </header>

      <section className="grid">
        <div className="panel">
          <h2>Nuevo ticket</h2>
          <form onSubmit={createTicket} className="form">
            <label>Título<input value={title} onChange={e => setTitle(e.target.value)} required /></label>
            <label>Descripción<textarea value={description} onChange={e => setDescription(e.target.value)} required /></label>
            <label>Prioridad<select value={priority} onChange={e => setPriority(e.target.value as Ticket['priority'])}><option value="low">Baja</option><option value="medium">Media</option><option value="high">Alta</option></select></label>
            <button>Crear ticket</button>
          </form>
        </div>

        <div className="panel">
          <h2>Tickets</h2>
          <div className="ticket-list">
            {tickets.map(ticket => (
              <button className="ticket" key={ticket.id} onClick={() => void loadTicket(ticket.id)}>
                <strong>#{ticket.id} {ticket.title}</strong>
                <span>{ticket.priority} · {ticket.status}</span>
              </button>
            ))}
            {tickets.length === 0 && <p>No hay tickets registrados.</p>}
          </div>
        </div>
      </section>

      {selected && <section className="panel detail">
        <h2>Ticket #{selected.id}</h2>
        <h3>{selected.title}</h3>
        <p>{selected.description}</p>
        <div className="actions">
          <select value={selected.status} onChange={e => void changeStatus(e.target.value as Ticket['status'])}>
            <option value="open">Abierto</option>
            <option value="in_progress">En progreso</option>
            <option value="resolved">Resuelto</option>
          </select>
          <label className="file-button">Adjuntar evidencia<input type="file" onChange={e => void uploadEvidence(e.target.files?.[0])} /></label>
        </div>
        <h3>Evidencias</h3>
        <ul>
          {(selected.evidence ?? []).map(item => <li key={item.id}><a href={`${API}/tickets/${selected.id}/evidence/${item.id}`}>{item.file_name}</a></li>)}
        </ul>
      </section>}
    </main>
  );
}

createRoot(document.getElementById('root')!).render(<React.StrictMode><App /></React.StrictMode>);
