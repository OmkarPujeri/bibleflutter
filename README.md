# Bible Connect

An offline-first Bible reader for Android and iOS, paired with a mood check-in that
points you to a verse for how you're feeling.

No account, no network calls, no ads. The full Bible and every font ship inside the
app bundle.

---

## Features

### Bible reader

- **World English Bible, bundled on-device** — 66 books as per-book JSON, 31,095
  verses, ~4.6 MB. Nothing is downloaded or fetched at runtime.
- **Two reading modes** — verse-per-line or flowing paragraphs, switchable at any time.
- **Selected-verse highlight with auto-scroll**, restored on cold start.
- **Adjustable font scale** (0.85×–1.6×), persisted across sessions.
- **Searchable book and chapter picker** — 66-book grid with an Old/New Testament
  filter and a chapter grid.
- **Prev/next verse navigation** that crosses both chapter and book boundaries.
  Navigation is value-based rather than index-based, so it stays correct across the
  places where verse numbering in this edition skips.
- **Reading position persists** across app restarts. Corrupt or missing saved data
  degrades safely to Genesis 1:1.
- **Bookish typography** — Crimson Pro for scripture, Inter for UI, bundled in
  `assets/fonts/`. Google Fonts resolves them from the bundle, so the app works
  fully offline and release builds render the intended typefaces.

### Mood check-in

- **Three-step wizard** — an intensity slider across five mood levels, a follow-up
  question with three categorised options, then optional free-text thoughts.
- **Curated verse recommendation** from a 150-verse mapping (5 levels × 15 emotion
  categories × 10 verses). Every entry is validated against the real Bible data by
  the test suite, so the mapping can't drift from the bundled text.
- **Whole-level fallback** when no category-specific verse applies.
- **Result card** showing the full verse text, with **Open in reader** jumping
  straight to that verse in the Bible tab.
- **Local history** — today's check-in on reopen, plus a list of the last 20
  check-ins with readable references.

## Tech stack

| | |
|---|---|
| Framework | Flutter (Dart SDK ^3.12.2) |
| State | Riverpod 3 |
| Persistence | `shared_preferences` |
| Typography | `google_fonts`, backed by bundled assets |
| Architecture | Feature-first — `lib/features/<name>/{application,data,domain,presentation}` plus shared `lib/core/` |

## Getting started

```bash
flutter pub get
flutter run          # Android emulator/device or iOS simulator
```

Checks:

```bash
flutter test         # unit + widget tests
flutter analyze
```

## Project structure

```
lib/
├── main.dart
├── core/                     # shared across features
│   ├── router/               # 2-tab shell
│   ├── settings/             # reader settings (mode, font scale)
│   ├── theme/                # light + dark bookish theme
│   └── debug_report.dart     # fail-fast in debug, no-op in release
└── features/
    ├── bible/
    │   ├── application/      # reader controller
    │   ├── data/             # repository, reading-position store, book names
    │   ├── domain/           # BookInfo, Verse, VerseRef (OSIS parsing)
    │   └── presentation/     # tab, reader screen, picker, verse list
    └── mood/
        ├── application/      # wizard state machine
        ├── data/             # repository, history store
        ├── domain/           # mood models
        └── presentation/     # tab and step widgets

assets/
├── bible/
│   ├── index.json            # book metadata and chapter/verse counts
│   └── books/                # 66 per-book JSON files
├── mood/                     # questions and the curated verse mapping
└── fonts/                    # Crimson Pro + Inter

tools/convert_web.py          # rebuilds assets/bible/
```

## Bible text

The bundled text is the **World English Bible**, which is in the public domain.

This is the critical-text edition, which comes to **31,095 verses** — fewer than the
31,102 of traditional editions. Luke 17:36 and Acts 8:37, 15:34 and 24:7 are omitted
upstream, and the Romans 16 doxology is merged into Romans 14:23. Verse navigation is
value-based specifically so these gaps don't break next/previous.

To rebuild the assets from source (needs Python 3 and a network connection):

```bash
python tools/convert_web.py --out assets/bible
```

This downloads the text, writes the per-book JSON and index, asserts the 31,095-verse
total, and prints John 3:16 as a spot check.

## Licence

- **Bible text** — World English Bible, public domain.
- **Crimson Pro** and **Inter** are licensed under the SIL Open Font License 1.1.
