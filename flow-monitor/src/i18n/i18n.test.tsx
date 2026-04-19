import { act, renderHook } from "@testing-library/react";
import { createElement, type ReactNode } from "react";
import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { I18nProvider, useTranslation, type Locale } from "./index";
import enMessages from "./en.json";
import zhTWMessages from "./zh-TW.json";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function wrapper({ children }: { children: ReactNode }) {
  return createElement(I18nProvider, { defaultLocale: "en" }, children);
}

function wrapperZh({ children }: { children: ReactNode }) {
  return createElement(I18nProvider, { defaultLocale: "zh-TW" as Locale }, children);
}

// ---------------------------------------------------------------------------
// 1. Basic t(key) lookup — English (default)
// ---------------------------------------------------------------------------

describe("useTranslation — English defaults", () => {
  it("returns the English string for sidebar.allProjects", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    expect(result.current.t("sidebar.allProjects")).toBe("All Projects");
  });

  it("returns the English string for notification.stalled-title", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    expect(result.current.t("notification.stalled-title")).toBe(
      "Session stalled: {slug}",
    );
  });

  it("returns the English string for notification.stalled-body", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    expect(result.current.t("notification.stalled-body")).toBe(
      "{stage} · idle for {duration} · {repo}",
    );
  });
});

// ---------------------------------------------------------------------------
// 2. Missing key — returns key + console.warn in dev
// ---------------------------------------------------------------------------

describe("useTranslation — missing key behaviour", () => {
  let warnSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warnSpy = vi.spyOn(console, "warn").mockImplementation(() => undefined);
  });

  afterEach(() => {
    warnSpy.mockRestore();
  });

  it("returns the key itself when the key is not in the dictionary", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    const returnVal = result.current.t("nonexistent.key");
    expect(returnVal).toBe("nonexistent.key");
  });

  it("calls console.warn with the missing key in non-production env", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    result.current.t("nonexistent.key");
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining("nonexistent.key"),
    );
  });
});

// ---------------------------------------------------------------------------
// 3. setLocale — re-renders all consumers within one frame (AC11.b)
// ---------------------------------------------------------------------------

describe("useTranslation — locale switching within one frame", () => {
  it("renders sidebar.allProjects in EN initially", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    expect(result.current.t("sidebar.allProjects")).toBe("All Projects");
  });

  it("switches to zh-TW and re-renders within the same act() call", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    act(() => {
      result.current.setLocale("zh-TW");
    });
    // After act() the state update is flushed — verified in one frame
    expect(result.current.t("sidebar.allProjects")).toBe("全部專案");
  });

  it("switches back from zh-TW to EN", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper: wrapperZh });
    expect(result.current.t("sidebar.allProjects")).toBe("全部專案");
    act(() => {
      result.current.setLocale("en");
    });
    expect(result.current.t("sidebar.allProjects")).toBe("All Projects");
  });
});

// ---------------------------------------------------------------------------
// 4. Stage pills — all 11 stages present in both locales
// ---------------------------------------------------------------------------

const STAGE_KEYS = [
  "stage.request",
  "stage.brainstorm",
  "stage.design",
  "stage.prd",
  "stage.tech",
  "stage.plan",
  "stage.tasks",
  "stage.implement",
  "stage.gap-check",
  "stage.verify",
  "stage.done",
] as const;

describe("stage pill keys", () => {
  it("all 11 stage keys resolve in EN", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    for (const key of STAGE_KEYS) {
      expect(result.current.t(key)).not.toBe(key);
    }
  });

  it("all 11 stage keys resolve in zh-TW", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper: wrapperZh });
    for (const key of STAGE_KEYS) {
      expect(result.current.t(key)).not.toBe(key);
    }
  });
});

// ---------------------------------------------------------------------------
// 5. Idle badges — 3 states in both locales
// ---------------------------------------------------------------------------

const IDLE_KEYS = ["idle.stale", "idle.stalled", "idle.active"] as const;

describe("idle badge keys", () => {
  it("all 3 idle keys resolve in EN", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper });
    for (const key of IDLE_KEYS) {
      expect(result.current.t(key)).not.toBe(key);
    }
  });

  it("all 3 idle keys resolve in zh-TW", () => {
    const { result } = renderHook(() => useTranslation(), { wrapper: wrapperZh });
    for (const key of IDLE_KEYS) {
      expect(result.current.t(key)).not.toBe(key);
    }
  });
});

// ---------------------------------------------------------------------------
// 6. Parity check — every EN key exists in zh-TW and vice versa (AC11.c)
// ---------------------------------------------------------------------------

describe("parity check — en.json vs zh-TW.json", () => {
  const enKeys = Object.keys(enMessages as Record<string, string>).sort();
  const zhKeys = Object.keys(zhTWMessages as Record<string, string>).sort();

  it("en.json and zh-TW.json have the same number of keys", () => {
    expect(enKeys.length).toBe(zhKeys.length);
  });

  it("every key in en.json exists in zh-TW.json", () => {
    const zhSet = new Set(zhKeys);
    const missing = enKeys.filter((k) => !zhSet.has(k));
    expect(missing).toEqual([]);
  });

  it("every key in zh-TW.json exists in en.json", () => {
    const enSet = new Set(enKeys);
    const missing = zhKeys.filter((k) => !enSet.has(k));
    expect(missing).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// 7. Default locale is always 'en' — no browser auto-detect (AC11.e)
// ---------------------------------------------------------------------------

describe("AC11.e — default locale is en, no browser auto-detect", () => {
  it("default locale is 'en' regardless of browser environment", () => {
    // Structural guarantee (no auto-detect call) is verified by the
    // acceptance-criteria grep check outside this file.
    // Here we verify the runtime default via the provider default.
    const { result } = renderHook(() => useTranslation(), { wrapper });
    expect(result.current.locale).toBe("en");
  });
});

// ---------------------------------------------------------------------------
// 8. useTranslation throws when used outside I18nProvider
// ---------------------------------------------------------------------------

describe("useTranslation — provider guard", () => {
  it("throws a descriptive error when called outside I18nProvider", () => {
    expect(() => {
      renderHook(() => useTranslation());
    }).toThrow("useTranslation must be used inside <I18nProvider>.");
  });
});
