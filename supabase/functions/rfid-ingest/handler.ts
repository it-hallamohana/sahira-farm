export type ScanInput = {
  device_id: string;
  event_id: string;
  uid: string;
  observed_at: string;
  firmware_version?: string;
  weight_kg?: number;
};

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const allowedFields = new Set(['device_id', 'event_id', 'uid', 'observed_at', 'firmware_version', 'weight_kg']);
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };

function response(status: number, body: unknown, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...headers, ...extra } });
}

export function validateScan(value: unknown, now = Date.now()): ScanInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Payload harus objek JSON.');
  const input = value as Record<string, unknown>;
  if (Object.keys(input).some(key => !allowedFields.has(key))) throw new Error('Payload memuat kolom yang tidak didukung.');
  if (typeof input.device_id !== 'string' || !uuid.test(input.device_id) || typeof input.event_id !== 'string' || !uuid.test(input.event_id)) {
    throw new Error('device_id dan event_id harus UUID.');
  }
  if (typeof input.uid !== 'string' || input.uid.length > 128 || !/^[0-9a-f\s:-]+$/i.test(input.uid)) {
    throw new Error('UID tidak valid.');
  }
  const uid = input.uid.replace(/[\s:-]/g, '').toUpperCase();
  if (!/^[0-9A-F]{4,64}$/.test(uid)) throw new Error('UID harus 4–64 karakter heksadesimal/angka.');
  if (typeof input.observed_at !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.test(input.observed_at)) {
    throw new Error('observed_at harus ISO 8601 lengkap dengan zona waktu.');
  }
  const at = Date.parse(input.observed_at);
  if (!Number.isFinite(at) || at > now + 5 * 60_000 || at < now - 30 * 86_400_000) {
    throw new Error('Waktu pemindaian berada di luar jendela penerimaan 30 hari / toleransi jam 5 menit.');
  }
  if (input.weight_kg !== undefined && (typeof input.weight_kg !== 'number' || !Number.isFinite(input.weight_kg) || input.weight_kg <= 0 || input.weight_kg > 250)) {
    throw new Error('weight_kg harus angka lebih dari 0 sampai 250.');
  }
  if (input.firmware_version !== undefined && (typeof input.firmware_version !== 'string' || input.firmware_version.length > 80)) {
    throw new Error('firmware_version maksimal 80 karakter.');
  }
  return { ...input, uid, observed_at: new Date(at).toISOString() } as ScanInput;
}

async function readBoundedJSON(request: Request): Promise<unknown> {
  const maxBytes = 8192;
  const size = Number(request.headers.get('content-length'));
  if (Number.isFinite(size) && size > maxBytes) throw new Error('PAYLOAD_TOO_LARGE');
  if (!request.body) throw new Error('Payload kosong.');
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > maxBytes) { await reader.cancel(); throw new Error('PAYLOAD_TOO_LARGE'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { throw new Error('JSON tidak valid.'); }
}

export function createHandler(config: { url: string; serviceKey: string; fetcher?: typeof fetch; now?: () => number }) {
  const fetcher = config.fetcher ?? fetch;
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return response(405, { error: 'Gunakan POST.' }, { Allow: 'POST' });
    if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) return response(415, { error: 'Gunakan application/json.' });
    const authorization = request.headers.get('authorization') ?? '';
    const match = /^Bearer (rfid_[0-9a-f]{64})$/.exec(authorization);
    if (!match) return response(401, { error: 'Token perangkat diperlukan.' });
    let input: ScanInput;
    try { input = validateScan(await readBoundedJSON(request), config.now?.()); }
    catch (error) {
      const message = error instanceof Error ? error.message : 'Payload tidak valid.';
      return response(message === 'PAYLOAD_TOO_LARGE' ? 413 : 400, { error: message });
    }
    if (!config.url || !config.serviceKey) return response(503, { error: 'Backend belum dikonfigurasi.' });
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(match[1]));
    const tokenHash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
    const payload: Record<string, unknown> = {};
    if (input.weight_kg !== undefined) payload.weight_kg = input.weight_kg;
    if (input.firmware_version !== undefined) payload.firmware_version = input.firmware_version;
    try {
      const backend = await fetcher(`${config.url.replace(/\/$/, '')}/rest/v1/rpc/ingest_rfid_scan`, {
        method: 'POST',
        headers: { apikey: config.serviceKey, Authorization: `Bearer ${config.serviceKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_device_id: input.device_id, p_token_hash: tokenHash, p_event_id: input.event_id,
          p_uid: input.uid, p_observed_at: input.observed_at, p_payload: payload }),
        signal: AbortSignal.timeout(12_000),
      });
      const body = await backend.json();
      if (!backend.ok) {
        const code = body.code;
        if (code === '28000') return response(401, { error: 'Perangkat atau token tidak valid, atau akses telah dicabut.' });
        if (code === '23505') return response(409, { error: 'event_id telah digunakan untuk data yang berbeda.' });
        if (code === '22023') return response(400, { error: 'Data pemindaian ditolak. Periksa UID, waktu, dan bobot.' });
        if (code === 'P0001' && body.message === 'DEVICE_RATE_LIMIT') return response(429, { error: 'Batas perangkat 120 peristiwa per menit.' }, { 'Retry-After': '60' });
        return response(503, { error: 'Penyimpanan belum tersedia. Coba ulang dengan event_id yang sama.' });
      }
      return response(body.duplicate ? 200 : 201, { accepted: true, ...body });
    } catch {
      return response(503, { error: 'Koneksi penyimpanan terputus. Coba ulang dengan event_id yang sama.' });
    }
  };
}
