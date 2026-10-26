// Uploads marketing/review/paywall.png as the App Review screenshot of both subscriptions.
// Usage: node scripts/upload-review-screenshot.mjs
import { fileURLToPath } from "node:url";
import { asc } from "./asc.mjs";
import { uploadAsset } from "./upload-screenshots.mjs";

const SUBSCRIPTIONS = { "com.coinvalues.identifier.yearly": "6826951571", "com.coinvalues.identifier.weekly": "6826951891" };
const file = fileURLToPath(new URL("../marketing/review/paywall.png", import.meta.url));

for (const [productId, id] of Object.entries(SUBSCRIPTIONS)) {
  const existing = await asc("GET", `/v1/subscriptions/${id}/appStoreReviewScreenshot`);
  if (existing.json?.data) await asc("DELETE", `/v1/subscriptionAppStoreReviewScreenshots/${existing.json.data.id}`);
  await uploadAsset("subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions", id, file);
  console.log(`review screenshot uploaded for ${productId}`);
}
