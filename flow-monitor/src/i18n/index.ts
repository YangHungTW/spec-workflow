/**
 * i18n stub — T14 will replace this with the full implementation.
 * Exposes useTranslation() hook returning t(key) which returns the key itself
 * until T14 merges and wires up the real locale-aware lookup.
 */

import { createContext, useContext } from "react";

interface TranslationContext {
  t: (key: string) => string;
  locale: string;
  setLocale: (locale: string) => void;
}

const I18nContext = createContext<TranslationContext>({
  t: (key: string) => key,
  locale: "en",
  setLocale: () => undefined,
});

export function useTranslation(): TranslationContext {
  return useContext(I18nContext);
}

export { I18nContext };
