import http from 'node:http';
import { randomUUID } from 'node:crypto';

const port = Number(process.env.PORT || 8080);
const inferenceBaseUrl = process.env.INFERENCE_BASE_URL;
const replayWindowMs = 5 * 60 * 1000;
const seenNonces = new Map();

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store'
  });
  res.end(body);
}

async function readJson(req, maxBytes = 1_500_000) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxBytes) throw Object.assign(new Error('request too large'), { statusCode: 413 });
    chunks.push(chunk);
  }
  if (total === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function pruneReplayCache() {
  const cutoff = Date.now() - replayWindowMs;
  for (const [nonce, seenAt] of seenNonces.entries()) {
    if (seenAt < cutoff) seenNonces.delete(nonce);
  }
}

async function proxyJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(15_000)
  });
  const text = await response.text();
  let payload;
  try { payload = text ? JSON.parse(text) : {}; }
  catch { payload = { message: 'upstream returned non-JSON response' }; }
  return { response, payload };
}

const server = http.createServer(async (req, res) => {
  const requestId = req.headers['x-request-id'] || randomUUID();
  res.setHeader('x-request-id', requestId);

  try {
    if (req.method === 'GET' && req.url === '/health') {
      return sendJson(res, 200, { status: 'ok', component: 'gateway' });
    }

    if (req.method === 'GET' && req.url === '/ready') {
      if (!inferenceBaseUrl) return sendJson(res, 503, { status: 'not-ready', reason: 'missing inference endpoint' });
      const { response } = await proxyJson(`${inferenceBaseUrl}/ready`);
      return sendJson(res, response.ok ? 200 : 503, { status: response.ok ? 'ready' : 'not-ready', component: 'gateway' });
    }

    if (req.method === 'GET' && req.url === '/v1/public-key') {
      if (!inferenceBaseUrl) return sendJson(res, 503, { error: 'inference endpoint unavailable' });
      const { response, payload } = await proxyJson(`${inferenceBaseUrl}/public-key`);
      return sendJson(res, response.status, payload);
    }

    if (req.method === 'POST' && req.url === '/v1/verify') {
      if (!inferenceBaseUrl) return sendJson(res, 503, { error: 'inference endpoint unavailable' });
      const body = await readJson(req);
      const nonce = typeof body.nonce === 'string' ? body.nonce : '';
      if (!nonce || nonce.length < 8 || nonce.length > 128) {
        return sendJson(res, 400, { error: 'a valid nonce is required' });
      }

      pruneReplayCache();
      if (seenNonces.has(nonce)) {
        return sendJson(res, 409, { error: 'replay rejected', nonceAccepted: false });
      }
      seenNonces.set(nonce, Date.now());

      const { response, payload } = await proxyJson(`${inferenceBaseUrl}/verify`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-request-id': String(requestId)
        },
        body: JSON.stringify(body)
      });
      return sendJson(res, response.status, payload);
    }

    return sendJson(res, 404, { error: 'not found' });
  } catch (error) {
    const status = Number(error?.statusCode) || 500;
    console.error(JSON.stringify({ requestId, status, error: error?.message || 'request failed' }));
    return sendJson(res, status, { error: status === 500 ? 'request failed' : error.message, requestId });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({ event: 'gateway-started', port, privacyLogRequestBody: false, privacyPersistImage: false }));
});
