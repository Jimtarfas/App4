// Applies marketing/aso/listing.json to App Store Connect: app info (subtitle, privacy URL,
// categories, age rating), the 1.0 version (description, keywords, URLs, copyright, review
// details), content rights, a free price and worldwide availability.
// Usage: node scripts/apply-metadata.mjs
import fs from "node:fs";
import { asc } from "./asc.mjs";

const APP_ID = "6826951196";
const REVIEW_CONTACT_FROM_APP = "6826843449"; // reuse the contact details already on My Vault
const listing = JSON.parse(fs.readFileSync(new URL("../marketing/aso/listing.json", import.meta.url)));

async function must(method, path, body) {
  const { status, json } = await asc(method, path, body);
  if (status >= 400) throw new Error(`${method} ${path} -> ${status}: ${JSON.stringify(json?.errors ?? json)}`);
  return json;
}

// App info: subtitle, privacy URL, categories, age rating.
const appInfo = (await must("GET", `/v1/apps/${APP_ID}/appInfos`)).data.find((i) => i.attributes.state !== "READY_FOR_DISTRIBUTION");
const infoLoc = (await must("GET", `/v1/appInfos/${appInfo.id}/appInfoLocalizations`)).data.find((l) => l.attributes.locale === "en-US");
await must("PATCH", `/v1/appInfoLocalizations/${infoLoc.id}`, {
  data: { type: "appInfoLocalizations", id: infoLoc.id,
    attributes: { name: listing.name, subtitle: listing.subtitle, privacyPolicyUrl: listing.privacyPolicyUrl } },
});
await must("PATCH", `/v1/appInfos/${appInfo.id}`, {
  data: { type: "appInfos", id: appInfo.id, relationships: {
    primaryCategory: { data: { type: "appCategories", id: listing.primaryCategory } },
    secondaryCategory: { data: { type: "appCategories", id: listing.secondaryCategory } },
  } },
});
console.log("app info updated");

const none = "NONE";
await must("PATCH", `/v1/ageRatingDeclarations/${appInfo.id}`, {
  data: { type: "ageRatingDeclarations", id: appInfo.id, attributes: {
    alcoholTobaccoOrDrugUseOrReferences: none, contests: none, gamblingSimulated: none, gunsOrOtherWeapons: none,
    horrorOrFearThemes: none, matureOrSuggestiveThemes: none, medicalOrTreatmentInformation: none,
    profanityOrCrudeHumor: none, sexualContentGraphicAndNudity: none, sexualContentOrNudity: none,
    violenceCartoonOrFantasy: none, violenceRealistic: none, violenceRealisticProlongedGraphicOrSadistic: none,
    advertising: false, ageAssurance: false, gambling: false, healthOrWellnessTopics: false, lootBox: false,
    messagingAndChat: false, parentalControls: false, unrestrictedWebAccess: false, userGeneratedContent: false,
  } },
});
console.log("age rating set");

// Version 1.0: localization, copyright, review details.
const version = (await must("GET", `/v1/apps/${APP_ID}/appStoreVersions`)).data.find((v) => v.attributes.versionString === "1.0");
await must("PATCH", `/v1/appStoreVersions/${version.id}`, {
  data: { type: "appStoreVersions", id: version.id, attributes: { copyright: listing.copyright } },
});
const versionLoc = (await must("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data.find((l) => l.attributes.locale === "en-US");
await must("PATCH", `/v1/appStoreVersionLocalizations/${versionLoc.id}`, {
  data: { type: "appStoreVersionLocalizations", id: versionLoc.id, attributes: {
    description: listing.description, keywords: listing.keywords, promotionalText: listing.promotionalText,
    supportUrl: listing.supportUrl, marketingUrl: listing.marketingUrl,
  } },
});
console.log("version localization updated");

const otherVersion = (await must("GET", `/v1/apps/${REVIEW_CONTACT_FROM_APP}/appStoreVersions?limit=1`)).data[0];
const contact = (await must("GET", `/v1/appStoreVersions/${otherVersion.id}/appStoreReviewDetail`)).data.attributes;
const reviewAttributes = {
  contactFirstName: contact.contactFirstName.trim(), contactLastName: contact.contactLastName.trim(),
  contactPhone: contact.contactPhone, contactEmail: contact.contactEmail,
  demoAccountRequired: false, notes: listing.reviewNotes,
};
const existingReview = await asc("GET", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
if (existingReview.json?.data) {
  await must("PATCH", `/v1/appStoreReviewDetails/${existingReview.json.data.id}`, {
    data: { type: "appStoreReviewDetails", id: existingReview.json.data.id, attributes: reviewAttributes },
  });
} else {
  await must("POST", "/v1/appStoreReviewDetails", {
    data: { type: "appStoreReviewDetails", attributes: reviewAttributes,
      relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } } },
  });
}
console.log("review details set");

// Content rights, free price, worldwide availability.
await must("PATCH", `/v1/apps/${APP_ID}`, {
  data: { type: "apps", id: APP_ID, attributes: { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" } },
});
const schedule = await asc("GET", `/v1/apps/${APP_ID}/appPriceSchedule`);
if (!schedule.json?.data) {
  const freePoint = (await must("GET", `/v1/apps/${APP_ID}/appPricePoints?filter[territory]=USA&limit=200`))
    .data.find((p) => p.attributes.customerPrice === "0.0" || Number(p.attributes.customerPrice) === 0);
  await must("POST", "/v1/appPriceSchedules", {
    data: { type: "appPriceSchedules", relationships: {
      app: { data: { type: "apps", id: APP_ID } },
      baseTerritory: { data: { type: "territories", id: "USA" } },
      manualPrices: { data: [{ type: "appPrices", id: "${price}" }] },
    } },
    included: [{ type: "appPrices", id: "${price}", attributes: { startDate: null },
      relationships: { appPricePoint: { data: { type: "appPricePoints", id: freePoint.id } } } }],
  });
  console.log("price set to free");
}
const availability = await asc("GET", `/v1/apps/${APP_ID}/appAvailabilityV2`);
if (!availability.json?.data) {
  const territories = [];
  let next = "/v1/territories?limit=200";
  while (next) {
    const page = await must("GET", next);
    territories.push(...page.data.map((t) => t.id));
    next = page.links?.next;
  }
  await must("POST", "/v2/appAvailabilities", {
    data: { type: "appAvailabilities", attributes: { availableInNewTerritories: true },
      relationships: {
        app: { data: { type: "apps", id: APP_ID } },
        territoryAvailabilities: { data: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}` })) },
      } },
    included: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}`, attributes: { available: true },
      relationships: { territory: { data: { type: "territories", id: t } } } })),
  });
  console.log(`available in ${territories.length} territories`);
}
console.log("done");
