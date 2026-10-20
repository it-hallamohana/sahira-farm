import { createHandler, validateScan } from './handler.ts';

function assert(value: unknown, message = 'Assertion failed'): asserts value {
  if (!value) throw new Error(message);
}
const now = Date.parse('2026-10-18T07:00:00Z');
const input = { device_id: '11111111-1111-4111-8111-111111111111', event_id: '22222222-2222-4222-8222-222222222222', uid: '04:ab:00:19', observed_at: '2026-10-18T06:59:00Z' };
const token = `rfid_${'a'.repeat(64)}`;
function request(body: unknown, authorization = `Bearer ${token}`) {
  return new Request('https://example.test/rfid-ingest', { method: 'POST', headers: { 'content-type': 'application/json', authorization }, body: JSON.stringify(body) });
}

Deno.test('UID canonicalization retains leading zeroes and explicit timezone', () => {
  const result = validateScan(input, now);
  assert(result.uid === '04AB0019');
  assert(result.observed_at === '2026-10-18T06:59:00.000Z');
});
Deno.test('forged ownership, invalid UID, local timestamp and unsafe measurements are rejected', () => {
  for (const patch of [{ owner_id: 'x' }, { uid: 'GHIJK' }, { observed_at: '2026-10-18T06:59:00' }, { observed_at: '2026-10-18T07:06:00Z' }, { observed_at: '2026-09-01T00:00:00Z' }, { weight_kg: -1 }, { weight_kg: '40' }, { weight_kg: Infinity }, { device_id: '../owner' }]) {
    let rejected = false;
    try { validateScan({ ...input, ...patch }, now); } catch { rejected = true; }
    assert(rejected, JSON.stringify(patch));
  }
});
Deno.test('missing device credentials cannot reach the database', async () => {
  let called = false;
  const handle = createHandler({ url: 'https://db.test', serviceKey: 'secret', now: () => now, fetcher: (() => { called = true; throw new Error(); }) as typeof fetch });
  assert((await handle(request(input, ''))).status === 401);
  assert(!called);
});
Deno.test('only token hash and whitelisted fields reach the backend', async () => {
  const handle = createHandler({ url: 'https://db.test', serviceKey: 'server-only-key', now: () => now, fetcher: (async (_url, options) => {
    const body = JSON.parse(options?.body as string);
    assert(body.p_token_hash.length === 64 && !JSON.stringify(body).includes(token));
    assert(body.p_uid === '04AB0019');
    assert(body.p_payload.weight_kg === 42.5);
    assert(!('owner_id' in body));
    return Response.json({ id: 'scan', status: 'pending', sheep_id: null, duplicate: false });
  }) as typeof fetch });
  const result = await handle(request({ ...input, weight_kg: 42.5 }));
  assert(result.status === 201);
  assert((await result.json()).accepted === true);
});
Deno.test('database statuses preserve retry, conflict and revocation semantics', async () => {
  for (const [code, message, expected] of [['28000', '', 401], ['23505', '', 409], ['22023', '', 400], ['P0001', 'DEVICE_RATE_LIMIT', 429], ['XX000', 'private database details', 503]] as const) {
    const handle = createHandler({ url: 'https://db.test', serviceKey: 'secret', now: () => now, fetcher: (async () => Response.json({ code, message }, { status: 400 })) as typeof fetch });
    const result = await handle(request(input));
    assert(result.status === expected);
    assert(!(await result.text()).includes('private database details'));
  }
});
Deno.test('duplicate acknowledgement is 200 and oversized bodies are rejected', async () => {
  const handle = createHandler({ url: 'https://db.test', serviceKey: 'secret', now: () => now, fetcher: (async () => Response.json({ duplicate: true })) as typeof fetch });
  assert((await handle(request(input))).status === 200);
  assert((await handle(request({ ...input, uid: 'a'.repeat(9000) }))).status === 413);
});
