import http from 'node:http';
import { createDecipheriv, createHash } from 'node:crypto';

const port = Number(process.env.PORT || 8080);
const keyVaultUri = (process.env.KEY_VAULT_URI || '').replace(/\/$/, '');
const encryptionKeyName = process.env.PAYLOAD_ENCRYPTION_KEY_NAME || 'payload-encryption';
const attestationKeyName = process.env.ATTESTATION_KEY_NAME || 'decision-attestation';
const managedIdentityClientId = process.env.AZURE_CLIENT_ID || '';

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

async function getVaultToken() {
  const endpoint = process.env.IDENTITY_ENDPOINT;
  const header = process.env.IDENTITY_HEADER;
  if (!endpoint || !header) throw new Error('managed identity endpoint is unavailable');

  const url = new URL(endpoint);
  url.searchParams.set('api-version', '2019-08-01');
  url.searchParams.set('resource', 'https://vault.azure.net');
  if (managedIdentityClientId) url.searchParams.set('client_id', managedIdentityClientId);

  const response = await fetch(url, {
    headers: { 'X-IDENTITY-HEADER': header },
    signal: AbortSignal.timeout(10_000)
  });
  if (!response.ok) throw new Error(`managed identity token request failed (${response.status})`);
  const token = await response.json();
  return token.access_token;
}

async function vaultRequest(path, options = {}) {
  if (!keyVaultUri) throw new Error('KEY_VAULT_URI is not configured');
  const token = await getVaultToken();
  const response = await fetch(`${keyVaultUri}${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      ...(options.headers || {})
    },
    signal: AbortSignal.timeout(15_000)
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Key Vault operation failed (${response.status}): ${text.slice(0, 180)}`);
  }
  return response.json();
}

function requireBase64Url(value, field) {
  if (typeof value !== 'string' || value.length === 0) throw Object.assign(new Error(`${field} is required`), { statusCode: 400 });
  return Buffer.from(value, 'base64url');
}

const server = http.createServer(async (req, res) => {
  const requestId = req.headers['x-request-id'] || 'unassigned';

  try {
    if (req.method === 'GET' && req.url === '/health') {
      return sendJson(res, 200, { status: 'ok', component: 'inference' });
    }

    if (req.method === 'GET' && req.url === '/ready') {
      const configured = Boolean(keyVaultUri && encryptionKeyName && attestationKeyName && managedIdentityClientId);
      return sendJson(res, configured ? 200 : 503, { status: configured ? 'ready' : 'not-ready', component: 'inference' });
    }

    if (req.method === 'GET' && req.url === '/public-key') {
      const key = await vaultRequest(`/keys/${encodeURIComponent(encryptionKeyName)}?api-version=7.4`);
      return sendJson(res, 200, {
        kty: key.key.kty,
        n: key.key.n,
        e: key.key.e,
        alg: 'RSA-OAEP-256',
        source: 'azure-key-vault-hsm'
      });
    }

    if (req.method === 'POST' && req.url === '/verify') {
      const body = await readJson(req);
      const wrappedKey = requireBase64Url(body.wrappedKey, 'wrappedKey');
      const iv = requireBase64Url(body.iv, 'iv');
      const ciphertext = requireBase64Url(body.ciphertext, 'ciphertext');
      const tag = requireBase64Url(body.tag, 'tag');
      if (iv.length !== 12 || tag.length !== 16) throw Object.assign(new Error('invalid AES-GCM envelope'), { statusCode: 400 });

      const unwrapped = await vaultRequest(`/keys/${encodeURIComponent(encryptionKeyName)}/unwrapkey?api-version=7.4`, {
        method: 'POST',
        body: JSON.stringify({ alg: 'RSA-OAEP-256', value: wrappedKey.toString('base64url') })
      });
      const dataKey = Buffer.from(unwrapped.value, 'base64url');
      if (dataKey.length !== 32) throw new Error('unexpected unwrapped data-key length');

      const decipher = createDecipheriv('aes-256-gcm', dataKey, iv);
      decipher.setAuthTag(tag);
      const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

      const payloadSha256 = createHash('sha256').update(plaintext).digest('hex');
      const decision = {
        eligible: true,
        validationMode: 'synthetic-no-model',
        payloadSha256,
        plaintextPersisted: false,
        requestId
      };
      const decisionDigest = createHash('sha256').update(JSON.stringify(decision)).digest();
      const signed = await vaultRequest(`/keys/${encodeURIComponent(attestationKeyName)}/sign?api-version=7.4`, {
        method: 'POST',
        body: JSON.stringify({ alg: 'RS256', value: decisionDigest.toString('base64url') })
      });

      plaintext.fill(0);
      dataKey.fill(0);

      return sendJson(res, 200, {
        ...decision,
        decisionSignature: signed.value,
        signatureAlgorithm: 'RS256',
        keyCustody: 'azure-key-vault-hsm'
      });
    }

    return sendJson(res, 404, { error: 'not found' });
  } catch (error) {
    const status = Number(error?.statusCode) || 500;
    console.error(JSON.stringify({ requestId, status, error: error?.message || 'request failed' }));
    return sendJson(res, status, { error: status === 500 ? 'verification failed' : error.message, requestId });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({ event: 'inference-started', port, validationMode: 'synthetic-no-model', privacyLogRequestBody: false, privacyPersistImage: false }));
});
