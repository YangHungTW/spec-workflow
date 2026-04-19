/**
 * Seam 6 — i18n parity test (T32)
 *
 * Loads en.json and zh-TW.json, recursively flattens both to dotted-key sets,
 * and asserts the sets are equal in both directions (en ⊂ zh-TW AND zh-TW ⊂ en).
 *
 * Motivation: adding a key to en.json without a zh-TW.json counterpart would
 * silently fall through to key-as-fallback in production, surfacing as untranslated
 * text instead of a build failure. This test catches that class of drift at CI time
 * — the predicted gap-check finding from tpm/reviewer-blind-spot-semantic-drift.
 */

import { describe, expect, it } from "vitest";
import enRaw from "../en.json";
import zhTWRaw from "../zh-TW.json";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Recursively flatten a JSON object to dotted-key strings.
 * Example: { a: { b: "x" } } → ["a.b"]
 * Flat objects (current shape of en.json / zh-TW.json) → top-level keys unchanged.
 */
function flattenKeys(obj: Record<string, unknown>, prefix = ""): string[] {
  const keys: string[] = [];
  for (const key of Object.keys(obj)) {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    const value = obj[key];
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      keys.push(...flattenKeys(value as Record<string, unknown>, fullKey));
    } else {
      keys.push(fullKey);
    }
  }
  return keys;
}

// ---------------------------------------------------------------------------
// Parity assertions
// ---------------------------------------------------------------------------

const enKeys = new Set(flattenKeys(enRaw as Record<string, unknown>));
const zhKeys = new Set(flattenKeys(zhTWRaw as Record<string, unknown>));

describe("Seam 6 — i18n parity: en.json ↔ zh-TW.json", () => {
  it("en.json and zh-TW.json have the same number of keys", () => {
    expect(enKeys.size).toBe(zhKeys.size);
  });

  it("every key in en.json is present in zh-TW.json (en ⊂ zh-TW)", () => {
    const missingInZh: string[] = [];
    for (const key of enKeys) {
      if (!zhKeys.has(key)) {
        missingInZh.push(key);
      }
    }
    expect(
      missingInZh,
      `Keys present in en.json but missing in zh-TW.json:\n  ${missingInZh.join("\n  ")}`,
    ).toEqual([]);
  });

  it("every key in zh-TW.json is present in en.json (zh-TW ⊂ en)", () => {
    const missingInEn: string[] = [];
    for (const key of zhKeys) {
      if (!enKeys.has(key)) {
        missingInEn.push(key);
      }
    }
    expect(
      missingInEn,
      `Keys present in zh-TW.json but missing in en.json:\n  ${missingInEn.join("\n  ")}`,
    ).toEqual([]);
  });
});
