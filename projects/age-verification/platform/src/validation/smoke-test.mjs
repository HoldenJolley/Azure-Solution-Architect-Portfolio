import { createCipheriv, createPublicKey, publicEncrypt, randomBytes, randomUUID, constants } from 'node:crypto';
import { writeFile } from 'node:fs/promises';

const frontDoorHost = process.env.FRONT_DOOR_HOST;
const gatewayFqdn = process.env.GATEWAY_FQDN;
const evidenceFile = process.env.EVIDENCE_FILE || '';
if (!frontDoorHost) throw new Error('FRONT_DOOR_HOST is required');

const baseUrl = `https://${frontDoorHost}`;

async function waitForHealthy() {
  let last;
  for (let attempt = 1; attempt <= 36; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(10_000) });
      if (response.ok) return attempt;
      last = `HTTP ${response.status}`;
    } catch (error) {
      last = error.message;
    }
    await new Promise(resolve => setTimeout(resolve, 10_000));
  }
  throw new Error(`Front Door never became healthy: ${last}`);
}

const healthAttempts = await waitForHealthy();

const ready = await fetch(`${baseUrl}/ready`, { signal: AbortSignal.timeout(15_000) });
if (!ready.ok) throw new Error(`Gateway readiness failed: ${ready.status}`);

const publicKeyResponse = await fetch(`${baseUrl}/v1/public-key`, { signal: AbortSignal.timeout(15_000) });
if (!publicKeyResponse.ok) throw new Error(`Public-key retrieval failed: ${publicKeyResponse.status}`);
const jwk = await publicKeyResponse.json();
if (!jwk.n || !jwk.e || jwk.source !== 'azure-key-vault-hsm') throw new Error('Unexpected public-key response');

const publicKey = createPublicKey({ key: { kty: 'RSA', n: jwk.n, e: jwk.e }, format: 'jwk' });
const dataKey = randomBytes(32);
const iv = randomBytes(12);
const nonce = randomUUID();
const syntheticPayload = Buffer.from(`synthetic-age-assurance-validation-payload:${randomUUID()}`, 'utf8');
const cipher = createCipheriv('aes-256-gcm', dataKey, iv);
const ciphertext = Buffer.concat([cipher.update(syntheticPayload), cipher.final()]);
const tag = cipher.getAuthTag();
const wrappedKey = publicEncrypt({
  key: publicKey,
  padding: constants.RSA_PKCS1_OAEP_PADDING,
  oaepHash: 'sha256'
}, dataKey);

dataKey.fill(0);

const envelope = {
  nonce,
  wrappedKey: wrappedKey.toString('base64url'),
  iv: iv.toString('base64url'),
  ciphertext: ciphertext.toString('base64url'),
  tag: tag.toString('base64url')
};

const verificationResponse = await fetch(`${baseUrl}/v1/verify`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(envelope),
  signal: AbortSignal.timeout(30_000)
});
if (!verificationResponse.ok) {
  throw new Error(`Synthetic verification failed (${verificationResponse.status}): ${(await verificationResponse.text()).slice(0, 300)}`);
}
const decision = await verificationResponse.json();
if (decision.validationMode !== 'synthetic-no-model') throw new Error('Validation workload incorrectly represented itself as a real model');
if (decision.plaintextPersisted !== false) throw new Error('Validation workload did not assert non-persistence');
if (!decision.decisionSignature || decision.keyCustody !== 'azure-key-vault-hsm') throw new Error('HSM-backed decision signing was not proven');
if (!decision.payloadSha256) throw new Error('Decrypted payload processing was not proven');

const replayResponse = await fetch(`${baseUrl}/v1/verify`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(envelope),
  signal: AbortSignal.timeout(15_000)
});
if (replayResponse.status !== 409) throw new Error(`Replay rejection expected HTTP 409, got ${replayResponse.status}`);

let directOriginReachable = null;
if (gatewayFqdn) {
  try {
    const direct = await fetch(`https://${gatewayFqdn}/health`, { signal: AbortSignal.timeout(8_000) });
    directOriginReachable = direct.ok;
    if (direct.ok) throw new Error('Internal gateway unexpectedly accepted a direct public request');
  } catch (error) {
    if (error.message.includes('unexpectedly accepted')) throw error;
    directOriginReachable = false;
  }
}

const evidence = {
  capturedUtc: new Date().toISOString(),
  frontDoorHost,
  healthAttempts,
  ready: true,
  publicKeySource: jwk.source,
  envelopeEncryption: 'AES-256-GCM + RSA-OAEP-256',
  keyCustody: decision.keyCustody,
  decisionSigning: decision.signatureAlgorithm,
  validationMode: decision.validationMode,
  plaintextPersisted: decision.plaintextPersisted,
  replayRejected: true,
  directOriginReachable,
  syntheticPayloadOnly: true
};

console.log(JSON.stringify(evidence, null, 2));
if (evidenceFile) await writeFile(evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`, 'utf8');
