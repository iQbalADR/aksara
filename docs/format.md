# Translation bundle format (shared spec)

This is the language-agnostic contract both the Swift and Kotlin runtimes read.
It is **i18next-compatible** so existing web tooling and translators can be reused.

## File layout

- **One file per language**, named by its language code: `en.json`, `id.json`,
  `ja.json`, `ar.json`, …
- Each file is a single JSON **object**. A top-level array or any non-object is
  rejected by the schema validator.

## Structure

- **Top-level keys are namespaces.** Nested objects are allowed and addressed by
  **dot path**: `t("auth.biometric_prompt")`.
- **Interpolation:** `{{var}}` placeholders. Surrounding whitespace is tolerated:
  `{{ name }}` == `{{name}}`. A variable with no supplied value is left **intact**
  (`{{name}}`) rather than silently dropped.
- **Pluralization:** CLDR plural categories as **sub-keys**
  (`zero`, `one`, `two`, `few`, `many`, `other`). The resolver maps
  `(language, count) → category`; **`other` is always required** as the fallback.
- **Arrays** are supported and addressed by index: `steps.0`, `steps.1`.
- **Optional metadata:** a top-level `_version` string (or number) is a reserved key.
  The default parser strips it from the key space (it's never returned by `t(...)`);
  use it for your own change detection if you like.

```json
{
  "_version": "1.0.0",
  "common": {
    "welcome": "Welcome, {{name}}!",
    "items": {
      "one": "{{count}} item",
      "other": "{{count}} items"
    }
  },
  "auth": {
    "login": "Log in",
    "biometric_prompt": "Authenticate with Face ID"
  }
}
```

## Lookup semantics

For every `t(key)` the runtime tries, in order:

1. the **active language** table,
2. the configured **`fallbackLanguage`** table,
3. the **raw key string** itself.

It never crashes and never returns blank.

For plural lookups (`t(key, count:)`):

1. resolve the category for `(activeLanguage, count)`,
2. try `key.<category>`, then `key.other`, in the active language,
3. then the same two in the fallback language,
4. then the raw key.

`{{count}}` is injected into the interpolation args automatically.

## Performance model

On load, the nested JSON is **flattened** into a single `[String: String]` /
`Map<String, String>` keyed by dot-path, so every `t(...)` is one O(1) hash lookup
— no per-call tree walking. Parsing happens off the main thread; the finished,
immutable table is published to the main thread and swapped in as a single
reference.

## Update & security rules

Aksara is **network-agnostic** — you download bundles yourself and feed them in with
`applyBundle`.

- A bundle you apply is **parsed + validated before** it may replace the live table
  (with the default parser: non-object roots and `null` leaves are rejected). On any
  parse failure the current table is kept (**last-good**).
- **Change detection / conditional requests** (ETag, `_version`, etc.) are the
  consumer's responsibility, since Aksara doesn't fetch. The default parser reserves
  and ignores a top-level `_version` key if you include one.
- The last applied bundle is **persisted to disk** and re-parsed on next launch
  (warm start) before you re-download anything.
- **Transport security** (TLS/certificate pinning, auth) lives in your network layer.
  Downloading *strings* (data, not code) is App Store / Play Store compliant — the
  same mechanism Firebase Remote Config uses.
- Need a different on-the-wire shape? Inject a custom `TranslationParser` — this format
  spec describes only the built-in `I18nextParser`.
