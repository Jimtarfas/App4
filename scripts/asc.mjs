// Minimal App Store Connect API client.
// Usage: node scripts/asc.mjs METHOD /v1/path [json-body | @file.json]
// Reads ASC_ISSUER_ID from ASC_ENV_FILE (default: VINCheck Pro/.env.local) and the key from ASC_KEY_PATH.
import crypto from "node:crypto";
import fs from "node:fs";
import { pathToFileURL } from "node:url";

const envFile = process.env.ASC_ENV_FILE ?? "/Users/nouhe/Desktop/AI Projects/VINCheck Pro/.env.local";
const keyPath = process.env.ASC_KEY_PATH ?? "/Users/nouhe/Desktop/AuthKey_ZA2ABQ7BR9.p8";
const keyId = process.env.ASC_KEY_ID_OVERRIDE ?? "ZA2ABQ7BR9";
const issuer = fs.readFileSync(envFile, "utf8").match(/^ASC_ISSUER_ID=["']?([^"'\n]+)/m)[1].trim();

export function token() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: "ES256", kid: keyId, typ: "JWT" });
  const body = b64({ iss: issuer, iat: now, exp: now + 1100, aud: "appstoreconnect-v1" });
  const sig = crypto.sign("sha256", Buffer.from(`${head}.${body}`), {
    key: fs.readFileSync(keyPath), dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${head}.${body}.${sig}`;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export async function asc(method, path, body) {
  const url = path.startsWith("http") ? path : `https://api.appstoreconnect.apple.com${path}`;
  let res;
  // The key is shared with other tools, so back off and retry when rate limited.
  for (let attempt = 0; ; attempt++) {
    res = await fetch(url, {
      method,
      headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if ((res.status !== 429 && res.status < 500) || attempt >= 8) break;
    await sleep(Math.min(60_000, 2_000 * 2 ** attempt));
  }
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, json };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [method, path, arg] = process.argv.slice(2);
  const body = arg === undefined ? undefined : JSON.parse(arg.startsWith("@") ? fs.readFileSync(arg.slice(1), "utf8") : arg);
  const { status, json } = await asc(method, path, body);
  console.log(JSON.stringify({ status, ...json }, null, 2));
  if (status >= 400) process.exit(1);
}
