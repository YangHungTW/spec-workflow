import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from "react";
import enMessages from "./en.json";
import zhTWMessages from "./zh-TW.json";

export type Locale = "en" | "zh-TW";

type Messages = Record<string, string>;

const MESSAGES: Record<Locale, Messages> = {
  en: enMessages as Messages,
  "zh-TW": zhTWMessages as Messages,
};

interface I18nContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (key: string) => string;
}

const I18nContext = createContext<I18nContextValue | null>(null);

interface I18nProviderProps {
  children: ReactNode;
  /** Default locale — English. Auto-detect from browser is deliberately disabled (AC11.e). */
  defaultLocale?: Locale;
}

export function I18nProvider({
  children,
  defaultLocale = "en",
}: I18nProviderProps): ReactNode {
  const [locale, setLocale] = useState<Locale>(defaultLocale);

  const t = useCallback(
    (key: string): string => {
      const messages = MESSAGES[locale];
      if (Object.prototype.hasOwnProperty.call(messages, key)) {
        return messages[key];
      }
      if (typeof process !== "undefined" && process.env["NODE_ENV"] !== "production") {
        console.warn(`[i18n] Missing translation key: "${key}" (locale: ${locale})`);
      }
      return key;
    },
    [locale],
  );

  return createElement(I18nContext.Provider, { value: { locale, setLocale, t } }, children);
}

/** Hook that exposes `t(key)`, `locale`, and `setLocale`. */
export function useTranslation(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (ctx === null) {
    throw new Error("useTranslation must be used inside <I18nProvider>.");
  }
  return ctx;
}
