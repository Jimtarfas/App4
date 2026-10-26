import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

// Claude Sonnet 5.5 with thinking off keeps a two-photo scan well under 2 cents
// (about 3k input tokens at $2/M plus at most MAX_OUTPUT_TOKENS at $10/M).
export const MODEL = "claude-sonnet-5-5";
const MAX_OUTPUT_TOKENS = 1000;
const PRICE_PER_INPUT_TOKEN = 2 / 1_000_000;
const PRICE_PER_OUTPUT_TOKEN = 10 / 1_000_000;

export const CoinIdentification = z.object({
  is_coin: z.boolean().describe("False when the photos do not show a coin, or it is too unclear to identify."),
  name: z.string().describe("Common catalog name, e.g. '1964-D Kennedy Half Dollar'. Empty if is_coin is false."),
  country: z.string().describe("Issuing country or authority, e.g. 'United States'."),
  denomination: z.string().describe("Face value, e.g. 'Half Dollar (50¢)'."),
  year: z.string().describe("Year shown on the coin, or 'Unknown' if not legible."),
  mint_mark: z.string().describe("Mint mark and mint, e.g. 'D (Denver)', or 'None (Philadelphia)', or 'Not visible'."),
  series: z.string().describe("Series or type, e.g. 'Kennedy Half Dollar (1964–present)'."),
  composition: z.string().describe("Metal composition, e.g. '90% silver, 10% copper'."),
  rarity: z.enum(["common", "uncommon", "scarce", "rare", "very_rare"]),
  condition_estimate: z.string().describe("Estimated grade from the photos, e.g. 'Very Fine (VF-20)'."),
  value_low_usd: z.number().describe("Low end of the estimated retail value in US dollars for the coin as pictured."),
  value_high_usd: z.number().describe("High end of the estimated retail value in US dollars for the coin as pictured."),
  confidence: z.enum(["high", "medium", "low"]).describe("Confidence in the identification."),
  description: z.string().describe("Two or three sentences about the coin and its history."),
  notable_features: z.array(z.string()).describe("Up to 4 short points: varieties, errors or details worth checking."),
  value_notes: z.string().describe("One or two sentences on what drives this coin's value."),
});
export type CoinIdentification = z.infer<typeof CoinIdentification>;

const SYSTEM_PROMPT = `You are an experienced numismatist inside a coin identification app. The user photographs a coin (front, and usually back) and you identify it.

Identify the coin as precisely as the photos allow: country, denomination, year, mint mark, series and composition. Read the date and mint mark from the photos rather than guessing. Mint marks are small and their position depends on the series (for example, the reverse lower left near the rim on 1917–1947 Walking Liberty half dollars, or beside the date on most modern US coins), so look closely at that spot before concluding there is none. If the date or mint mark is not legible, say "Unknown" or "Not visible" and lower your confidence.

Estimate a realistic retail value range in US dollars for this coin in the condition shown, based on typical dealer and auction prices you know of. Common circulated coins are often worth face value or melt value; say so through the range rather than inflating it. For bullion coins, base the range on typical premiums over metal value. Keep the range honest and reasonably tight; widen it only when condition or variety is uncertain.

Rarity reflects how hard the coin is to find for a collector: common, uncommon, scarce, rare or very_rare.

If the images do not show a coin (for example a banknote, token, medal you cannot place, or an unrelated object), set is_coin to false, leave text fields empty, use 0 for values, rarity common and confidence low.

Write for collectors and beginners: plain, accurate language, no hype. Never claim a value is certain; these are estimates.`;

const client = new Anthropic();

export interface IdentifyResult {
  coin: CoinIdentification;
  usage: { input_tokens: number; output_tokens: number; cost_usd: number; model: string };
}

export class RefusedError extends Error {}

export async function identifyCoin(front: string, back: string | null): Promise<IdentifyResult> {
  const content: Anthropic.Beta.BetaContentBlockParam[] = [
    { type: "text", text: "Front of the coin:" },
    { type: "image", source: { type: "base64", media_type: "image/jpeg", data: front } },
  ];
  if (back) {
    content.push(
      { type: "text", text: "Back of the coin:" },
      { type: "image", source: { type: "base64", media_type: "image/jpeg", data: back } },
    );
  }
  content.push({ type: "text", text: "Identify this coin and estimate its value." });

  const response = await client.beta.messages.parse({
    model: MODEL,
    max_tokens: MAX_OUTPUT_TOKENS,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    thinking: { type: "between_tools" },
    output_config: { effort: "low", format: zodOutputFormat(CoinIdentification) },
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content }],
  });

  if (response.stop_reason === "refusal") throw new RefusedError(response.stop_details?.category ?? "refusal");
  if (response.stop_reason === "max_tokens" || !response.parsed_output) {
    throw new Error(`unparseable response (stop_reason=${response.stop_reason})`);
  }

  const inputTokens =
    response.usage.input_tokens +
    (response.usage.cache_creation_input_tokens ?? 0) +
    (response.usage.cache_read_input_tokens ?? 0);
  const outputTokens = response.usage.output_tokens;
  return {
    coin: response.parsed_output,
    usage: {
      input_tokens: inputTokens,
      output_tokens: outputTokens,
      cost_usd: inputTokens * PRICE_PER_INPUT_TOKEN + outputTokens * PRICE_PER_OUTPUT_TOKEN,
      model: response.model,
    },
  };
}
