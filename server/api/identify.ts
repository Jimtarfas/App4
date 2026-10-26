import Anthropic from "@anthropic-ai/sdk";
import type { VercelRequest, VercelResponse } from "@vercel/node";
import crypto from "node:crypto";
import { identifyCoin, RefusedError } from "../lib/identify.js";
import { checkSubscription } from "../lib/subscription.js";

// The app uploads 768 px JPEGs. Capping the pixel size bounds the input tokens,
// which together with the output cap keeps every scan under 2 cents.
const MAX_IMAGE_BASE64_LENGTH = 1_500_000;
const MAX_IMAGE_DIMENSION = 800;
const HOURLY_LIMIT = 40;
const recentScans = new Map<string, number[]>();

function withinRateLimit(subscriberId: string): boolean {
  const now = Date.now();
  const hourAgo = now - 60 * 60 * 1000;
  const scans = (recentScans.get(subscriberId) ?? []).filter((t) => t > hourAgo);
  if (scans.length >= HOURLY_LIMIT) return false;
  scans.push(now);
  recentScans.set(subscriberId, scans);
  return true;
}

function isDevRequest(req: VercelRequest): boolean {
  const expected = process.env.DEV_BYPASS_TOKEN;
  const given = req.headers["x-dev-token"];
  if (!expected || typeof given !== "string" || given.length !== expected.length) return false;
  return crypto.timingSafeEqual(Buffer.from(given), Buffer.from(expected));
}

/** Reads width and height from a JPEG's start-of-frame segment. */
function jpegSize(data: Buffer): { width: number; height: number } | null {
  if (data[0] !== 0xff || data[1] !== 0xd8) return null;
  let offset = 2;
  while (offset + 9 < data.length) {
    if (data[offset] !== 0xff) return null;
    const marker = data[offset + 1];
    const length = data.readUInt16BE(offset + 2);
    const isStartOfFrame = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (isStartOfFrame) return { height: data.readUInt16BE(offset + 5), width: data.readUInt16BE(offset + 7) };
    offset += 2 + length;
  }
  return null;
}

function validImage(value: unknown): value is string {
  if (typeof value !== "string" || value.length < 100 || value.length > MAX_IMAGE_BASE64_LENGTH) return false;
  const size = jpegSize(Buffer.from(value, "base64"));
  return size !== null && size.width <= MAX_IMAGE_DIMENSION && size.height <= MAX_IMAGE_DIMENSION;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "method_not_allowed" });

  const { front, back, transaction } = (req.body ?? {}) as Record<string, unknown>;
  if (!validImage(front) || (back != null && !validImage(back))) {
    return res.status(400).json({ error: "invalid_image" });
  }

  let subscriberId = "dev";
  if (!isDevRequest(req)) {
    const check = await checkSubscription(transaction);
    if (!check.ok) return res.status(402).json({ error: "subscription_required", reason: check.reason });
    subscriberId = check.subscriberId;
  }
  if (!withinRateLimit(subscriberId)) return res.status(429).json({ error: "rate_limited" });

  try {
    const { coin, usage } = await identifyCoin(front, (back as string | null) ?? null);
    console.log(JSON.stringify({ event: "scan", subscriber: subscriberId, is_coin: coin.is_coin, ...usage }));
    return res.status(200).json(coin);
  } catch (error) {
    if (error instanceof RefusedError) {
      console.warn(JSON.stringify({ event: "refusal", category: error.message }));
      return res.status(422).json({ error: "not_identifiable" });
    }
    if (error instanceof Anthropic.RateLimitError) {
      console.error("anthropic rate limited", error.message);
      return res.status(503).json({ error: "busy" });
    }
    if (error instanceof Anthropic.APIError) {
      console.error(`anthropic api error ${error.status}`, error.message);
      return res.status(502).json({ error: "upstream_error" });
    }
    console.error("identify failed", error);
    return res.status(500).json({ error: "server_error" });
  }
}
