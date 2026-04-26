# Export/Import Workflow

Complete reference for exporting and importing translations using XLIFF for external translators.

---

## XLIFF Export for Translators

XLIFF (XML Localisation Interchange File Format) is the standard format for sending translations to external translators. Xcode can export all localizable content as XLIFF files.

---

## Xcode Export Workflow

### Step 1: Export Localizations

1. Open the Xcode workspace
2. Select the project in the Project Navigator
3. Go to **Product > Export Localizations...**
4. Choose the languages to export
5. Select the output directory
6. Xcode generates `.xcloc` bundles (which contain XLIFF files)

### Step 2: Examine the Export

Each `.xcloc` bundle contains:

```
pl.xcloc/
├── Localized Contents/
│   └── pl.xliff          <-- XLIFF file for translators
├── Notes/
└── Source Contents/
```

The XLIFF file contains all translatable strings from `Localizable.xcstrings` with source (English) and target (translated) values.

---

## Sending to Translators

### What to Send

- Send the `.xcloc` bundle or the `.xliff` file inside it
- Include context notes if available (add translator comments in String Catalog editor)
- Provide a glossary of project-specific terms

### Translator Instructions

Provide translators with:

1. The `.xliff` file
2. Key naming context: camelCase `featureContext` helps translators understand where strings appear
3. Screenshots of the UI where possible (Xcode supports adding screenshots to `.xcloc`)
4. Notes about plural forms required for the target language

### Tools for Translators

Translators can edit XLIFF files with:
- **Xcode** (built-in support)
- **XLIFF editors**: Virtaal, Poedit, OmegaT
- **Translation platforms**: Crowdin, Lokalise, Phrase (support XLIFF import/export)

---

## Importing Translations Back

### Step 1: Receive Translated Files

Translators return the edited `.xcloc` bundle or `.xliff` file with translations filled in.

### Step 2: Import in Xcode

1. Open the Xcode workspace
2. Go to **Product > Import Localizations...**
3. Select the translated `.xcloc` bundle
4. Xcode shows a diff of changes
5. Review the changes and click **Import**

### Step 3: Verify Import

Xcode updates `Localizable.xcstrings` with the imported translations. All imported strings will have their state updated.

---

## Verification After Import

### Checklist

1. **Open `Localizable.xcstrings`** and verify translations appear
2. **Check for missing translations**: Filter by state "New" or "Needs Review"
3. **Build the project**: Ensure no compilation errors from format string mismatches
4. **Run the app** in each language:
   - Change simulator language: Settings > General > Language & Region
   - Or use Xcode scheme: Edit Scheme > Run > Options > App Language
5. **Check for truncation**: Verify translated strings fit in the UI
6. **Test pluralization**: Verify plural forms with different values (1, 2, 5, 22)

### Common Post-Import Issues

- **Format string mismatch**: Translator removed or changed `%lld` or `%@` placeholders. Fix in `Localizable.xcstrings`
- **Missing translations**: Some keys were not translated. Send back to translator or mark as "Needs Review"
- **Encoding issues**: Ensure XLIFF files are UTF-8 encoded

---

## Automation Options

For larger projects, consider:

- **CI export**: Script `xcodebuild -exportLocalizations` to automate XLIFF export
- **Translation platforms**: Services like Crowdin or Lokalise can sync with your repository and manage the translation workflow
- **xcstrings-crud**: For programmatic key management before/after export

```bash
# CLI export example
xcodebuild -exportLocalizations \
  -localizationPath ./Localizations \
  -project DeluluDetox.xcodeproj

# CLI import example
xcodebuild -importLocalizations \
  -localizationPath ./Localizations/pl.xcloc \
  -project DeluluDetox.xcodeproj
```

---

## Related

- `string-catalogs-setup.md` - Setting up .xcstrings files
- `pluralization-variations.md` - Plural forms translators need to fill
- `xcstrings-crud-tool.md` - Programmatic key management

---

**Last Updated**: 2026-04-26
