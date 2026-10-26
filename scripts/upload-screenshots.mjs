// Uploads the framed App Store screenshots for version 1.0 (en-US), replacing what is there.
// Usage: node scripts/upload-screenshots.mjs
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { asc } from "./asc.mjs";

const APP_ID = "6826951196";
const ROOT = fileURLToPath(new URL("..", import.meta.url));
const SETS = [
  { type: "APP_IPHONE_67", dir: "marketing/screenshots/en-US-6.9" }, // 6.9" slot (1320×2868)
  { type: "APP_IPHONE_65", dir: "marketing/screenshots/en-US-6.5" }, // 6.5" slot (1284×2778)
];

async function must(method, p, body) {
  const { status, json } = await asc(method, p, body);
  if (status >= 400) throw new Error(`${method} ${p} -> ${status}: ${JSON.stringify(json?.errors ?? json)}`);
  return json;
}

/** Reserves, uploads and commits one asset using App Store Connect's upload operations. */
export async function uploadAsset(type, relationship, parentType, parentId, file) {
  const data = fs.readFileSync(file);
  const reservation = (await must("POST", `/v1/${type}`, {
    data: { type, attributes: { fileName: path.basename(file), fileSize: data.length },
      relationships: { [relationship]: { data: { type: parentType, id: parentId } } } },
  })).data;
  for (const op of reservation.attributes.uploadOperations) {
    const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]));
    const res = await fetch(op.url, { method: op.method, headers, body: data.subarray(op.offset, op.offset + op.length) });
    if (!res.ok) throw new Error(`upload chunk failed ${res.status}`);
  }
  await must("PATCH", `/v1/${type}/${reservation.id}`, {
    data: { type, id: reservation.id, attributes: { uploaded: true,
      sourceFileChecksum: crypto.createHash("md5").update(data).digest("hex") } },
  });
  return reservation.id;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const version = (await must("GET", `/v1/apps/${APP_ID}/appStoreVersions`)).data.find((v) => v.attributes.versionString === "1.0");
  const localization = (await must("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data
    .find((l) => l.attributes.locale === "en-US");
  const sets = (await must("GET", `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets`)).data;
  for (const { type, dir } of SETS) {
    let set = sets.find((s) => s.attributes.screenshotDisplayType === type);
    if (set) {
      for (const shot of (await must("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data) {
        await must("DELETE", `/v1/appScreenshots/${shot.id}`);
      }
    } else {
      set = (await must("POST", "/v1/appScreenshotSets", {
        data: { type: "appScreenshotSets", attributes: { screenshotDisplayType: type },
          relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization.id } } } },
      })).data;
    }
    const files = fs.readdirSync(path.join(ROOT, dir)).filter((f) => f.endsWith(".png")).sort();
    for (const file of files) {
      await uploadAsset("appScreenshots", "appScreenshotSet", "appScreenshotSets", set.id, path.join(ROOT, dir, file));
      console.log(`${type}: uploaded ${file}`);
    }
  }
  console.log("done");
}
