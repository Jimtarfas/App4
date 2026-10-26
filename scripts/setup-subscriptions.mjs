// Creates the Coin Values Pro subscription group, the weekly and yearly subscriptions,
// their prices in every territory (equalized from the US price), availability and the
// yearly 3-day free trial. Safe to re-run: existing pieces are reused.
// Usage: node scripts/setup-subscriptions.mjs
import { asc } from "./asc.mjs";

const APP_ID = "6826951196";
const GROUP_NAME = "Coin Values Pro";
const PLANS = [
  { productId: "com.coinvalues.identifier.yearly", name: "Coin Values Pro Yearly", period: "ONE_YEAR", level: 1, usd: "29.99", trial: "THREE_DAYS" },
  { productId: "com.coinvalues.identifier.weekly", name: "Coin Values Pro Weekly", period: "ONE_WEEK", level: 2, usd: "4.99" },
];
const DESCRIPTION = "Unlimited coin scans and value estimates";
const REVIEW_NOTE =
  "Coin Values Pro unlocks coin identification. Open the app, finish onboarding, and the paywall appears; it is also reachable from the Scan tab and Settings. After subscribing, tap Scan a Coin, photograph the front and back of any coin (or choose photos from the library), and the app shows the identification and an estimated value.";

async function must(method, path, body) {
  const { status, json } = await asc(method, path, body);
  if (status >= 400) throw new Error(`${method} ${path} -> ${status}: ${JSON.stringify(json?.errors ?? json)}`);
  return json;
}

async function all(path) {
  const items = [];
  let next = path;
  while (next) {
    const page = await must("GET", next);
    items.push(...(page.data ?? []));
    next = page.links?.next;
  }
  return items;
}

async function ensureGroup() {
  const groups = await all(`/v1/apps/${APP_ID}/subscriptionGroups`);
  let group = groups.find((g) => g.attributes.referenceName === GROUP_NAME);
  if (!group) {
    group = (await must("POST", "/v1/subscriptionGroups", {
      data: { type: "subscriptionGroups", attributes: { referenceName: GROUP_NAME },
        relationships: { app: { data: { type: "apps", id: APP_ID } } } },
    })).data;
    console.log("created group", group.id);
  }
  const locs = await all(`/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations`);
  if (!locs.some((l) => l.attributes.locale === "en-US")) {
    await must("POST", "/v1/subscriptionGroupLocalizations", {
      data: { type: "subscriptionGroupLocalizations", attributes: { name: GROUP_NAME, locale: "en-US" },
        relationships: { subscriptionGroup: { data: { type: "subscriptionGroups", id: group.id } } } },
    });
    console.log("group localization added");
  }
  return group;
}

async function ensureSubscription(group, plan) {
  const subs = await all(`/v1/subscriptionGroups/${group.id}/subscriptions`);
  let sub = subs.find((s) => s.attributes.productId === plan.productId);
  if (!sub) {
    sub = (await must("POST", "/v1/subscriptions", {
      data: { type: "subscriptions",
        attributes: { name: plan.name, productId: plan.productId, subscriptionPeriod: plan.period,
          familySharable: false, groupLevel: plan.level, reviewNote: REVIEW_NOTE },
        relationships: { group: { data: { type: "subscriptionGroups", id: group.id } } } },
    })).data;
    console.log("created subscription", plan.productId, sub.id);
  }
  const locs = await all(`/v1/subscriptions/${sub.id}/subscriptionLocalizations`);
  if (!locs.some((l) => l.attributes.locale === "en-US")) {
    await must("POST", "/v1/subscriptionLocalizations", {
      data: { type: "subscriptionLocalizations", attributes: { name: plan.name, description: DESCRIPTION, locale: "en-US" },
        relationships: { subscription: { data: { type: "subscriptions", id: sub.id } } } },
    });
    console.log("localization added", plan.productId);
  }
  return sub;
}

async function ensureAvailability(sub, territories) {
  const { status } = await asc("GET", `/v1/subscriptions/${sub.id}/subscriptionAvailability`);
  if (status === 200) {
    const existing = await asc("GET", `/v1/subscriptions/${sub.id}/subscriptionAvailability`);
    if (existing.json?.data) return;
  }
  await must("POST", "/v1/subscriptionAvailabilities", {
    data: { type: "subscriptionAvailabilities", attributes: { availableInNewTerritories: true },
      relationships: {
        subscription: { data: { type: "subscriptions", id: sub.id } },
        availableTerritories: { data: territories.map((id) => ({ type: "territories", id })) },
      } },
  });
  console.log("availability set", sub.attributes.productId);
}

async function ensurePrices(sub, plan) {
  const existing = await all(`/v1/subscriptions/${sub.id}/prices?include=territory&limit=200`);
  const priced = new Set(existing.map((p) => p.relationships?.territory?.data?.id).filter(Boolean));
  const usPoints = await all(`/v1/subscriptions/${sub.id}/pricePoints?filter[territory]=USA&limit=200`);
  const usPoint = usPoints.find((p) => p.attributes.customerPrice === plan.usd);
  if (!usPoint) throw new Error(`no USA price point ${plan.usd}`);
  const equalized = await all(`/v1/subscriptionPricePoints/${usPoint.id}/equalizations?include=territory&limit=200`);
  const points = [{ id: usPoint.id, territory: "USA" },
    ...equalized.map((p) => ({ id: p.id, territory: p.relationships.territory.data.id }))];
  let created = 0;
  for (const point of points) {
    if (priced.has(point.territory)) continue;
    await must("POST", "/v1/subscriptionPrices", {
      data: { type: "subscriptionPrices", attributes: { preserveCurrentPrice: false },
        relationships: {
          subscription: { data: { type: "subscriptions", id: sub.id } },
          subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: point.id } },
          territory: { data: { type: "territories", id: point.territory } },
        } },
    });
    created++;
  }
  console.log(`prices ${plan.productId}: ${created} created, ${priced.size} existed, ${points.length} territories`);
  return points.map((p) => p.territory);
}

async function ensureTrial(sub, plan, territories) {
  if (!plan.trial) return;
  const offers = await all(`/v1/subscriptions/${sub.id}/introductoryOffers?include=territory&limit=200`);
  const done = new Set(offers.map((o) => o.relationships?.territory?.data?.id).filter(Boolean));
  let created = 0;
  for (const territory of territories) {
    if (done.has(territory)) continue;
    await must("POST", "/v1/subscriptionIntroductoryOffers", {
      data: { type: "subscriptionIntroductoryOffers",
        attributes: { duration: plan.trial, offerMode: "FREE_TRIAL", numberOfPeriods: 1 },
        relationships: {
          subscription: { data: { type: "subscriptions", id: sub.id } },
          territory: { data: { type: "territories", id: territory } },
        } },
    });
    created++;
  }
  console.log(`free trial ${plan.productId}: ${created} created, ${done.size} existed`);
}

const territories = (await all("/v1/territories?limit=200")).map((t) => t.id);
const group = await ensureGroup();
for (const plan of PLANS) {
  const sub = await ensureSubscription(group, plan);
  await ensureAvailability(sub, territories);
  const priced = await ensurePrices(sub, plan);
  await ensureTrial(sub, plan, priced);
}
console.log("done");
