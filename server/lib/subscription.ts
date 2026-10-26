import fs from "node:fs";
import path from "node:path";
import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
} from "@apple/app-store-server-library";

const BUNDLE_ID = "com.coinvalues.identifier";
const APP_APPLE_ID = 6826951196;
const PRODUCT_IDS = new Set([
  "com.coinvalues.identifier.weekly",
  "com.coinvalues.identifier.yearly",
]);
// A renewal can land a few minutes after the old period ends.
const EXPIRY_GRACE_MS = 10 * 60 * 1000;

const rootCert = fs.readFileSync(path.join(process.cwd(), "certs", "AppleRootCA-G3.cer"));
const verifiers = new Map<Environment, SignedDataVerifier>();

function verifierFor(environment: Environment): SignedDataVerifier | null {
  // Xcode and local-testing transactions are not signed by Apple, and the library
  // skips verification for them, so they are never accepted here.
  if (environment !== Environment.SANDBOX && environment !== Environment.PRODUCTION) return null;
  let verifier = verifiers.get(environment);
  if (!verifier) {
    verifier = new SignedDataVerifier([rootCert], false, environment, BUNDLE_ID, APP_APPLE_ID);
    verifiers.set(environment, verifier);
  }
  return verifier;
}

function unverifiedEnvironment(jws: string): Environment | null {
  try {
    const payload = JSON.parse(Buffer.from(jws.split(".")[1] ?? "", "base64url").toString("utf8"));
    return typeof payload.environment === "string" ? (payload.environment as Environment) : null;
  } catch {
    return null;
  }
}

export type SubscriptionCheck =
  | { ok: true; subscriberId: string; environment: string }
  | { ok: false; reason: string };

/** Verifies a StoreKit 2 signed transaction and checks it grants an active subscription. */
export async function checkSubscription(jws: unknown): Promise<SubscriptionCheck> {
  if (typeof jws !== "string" || jws.split(".").length !== 3) return { ok: false, reason: "missing_transaction" };
  const environment = unverifiedEnvironment(jws);
  const verifier = environment ? verifierFor(environment) : null;
  if (!verifier) return { ok: false, reason: "unsupported_environment" };

  let payload: JWSTransactionDecodedPayload;
  try {
    payload = await verifier.verifyAndDecodeTransaction(jws);
  } catch {
    return { ok: false, reason: "invalid_signature" };
  }
  if (!payload.productId || !PRODUCT_IDS.has(payload.productId)) return { ok: false, reason: "unknown_product" };
  if (payload.revocationDate) return { ok: false, reason: "revoked" };
  if (!payload.expiresDate || payload.expiresDate + EXPIRY_GRACE_MS < Date.now()) return { ok: false, reason: "expired" };
  return {
    ok: true,
    subscriberId: payload.originalTransactionId ?? payload.transactionId ?? "unknown",
    environment: String(payload.environment),
  };
}
