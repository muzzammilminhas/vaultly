# Vaultly — Build Instructions

You are an autonomous coding agent building **Vaultly** (working title — rename freely if a better one occurs to you), a complete, shippable Flutter mobile app (Android), starting from a completely empty project folder. This is a portfolio project intended to be shown publicly (LinkedIn, GitHub), so code quality, real working functionality, and a polished finished feel all matter more than raw feature count.

<critical_requirements>
These apply across every phase and override any instinct to cut scope. Re-read this block before starting each new phase.

1. **No placeholders.** No placeholder screens, dummy data left in the shipped build, "TODO" stubs, or "coming soon" states anywhere in the final app. Every phase should leave a genuinely working, finished-feeling slice. The end state is a finished, polished product — not a prototype.
2. **Smooth performance.** UI scrolling, search-as-you-type, and screen transitions must hold 60fps. OCR processing runs off the main isolate/thread so the UI never freezes during a scan.
3. **Real on-device OCR and real full-text search** — not a keyword substring match dressed up as search. This is the technical centerpiece of the project.
4. **Documents are actually encrypted at rest**, not just stored in a private app directory and called "encrypted." Verify this is true, don't just assume the framework handles it.
5. **Full autonomy.** Design ambiguities (exact UI copy, exact tag categories, exact color palette) are never a reason to stop — make a reasonable choice, note it in a code comment, and keep moving. Only stop for the two genuine hard blockers named explicitly in this document (missing GitHub auth, a platform permission that genuinely cannot be granted programmatically).
6. **Real deliverables at the end, not just source code**: a pushed GitHub repo with real commit history, a final signed installable Android APK, and a `linkedin-post/` folder with real screenshots and a caption. These are defined in detail in the final phase.
</critical_requirements>

## What you're building

A privacy-first personal document vault. The user photographs or imports documents (IDs, receipts, handwritten notes, printed pages), the app extracts the text on-device via OCR, and everything is stored encrypted, searchable by full text, and locked behind a PIN or biometric check. No cloud, no account, no network calls of any kind — everything happens on the device.

## Tech stack

- Flutter (stable channel), Android target only for v1
- `google_mlkit_text_recognition` for on-device OCR
- `sqflite` with an FTS5 virtual table for full-text search over extracted document text
- `flutter_secure_storage` for the encryption key (backed by Android Keystore)
- The `encrypt` package (AES) for encrypting document image files at rest
- `local_auth` for PIN/biometric app lock
- `camera` and/or `image_picker` for document capture
- `riverpod` for state management
- Git for version control from the first commit
- No backend, no networking, no analytics, no login — fully offline single-user

## Version control and GitHub

Run `git init` in the project root as your first action, before any other work. Commit at the end of every phase with a message describing what was completed, so the history reads as real incremental progress, not one giant final commit.

To get the repo onto GitHub: check whether `gh` (GitHub CLI) is already authenticated on this machine. If it is, run `gh repo create vaultly --public --source=. --push` once your first commit exists, then push after every subsequent phase. **If `gh` is not authenticated, this is a genuine hard blocker** — stop and ask your human collaborator to either run `gh auth login` once, or create an empty repo on github.com and give you the remote URL to add with `git remote add origin <url>`. You cannot create a GitHub account or authenticate on your own.

## Project structure

```
lib/
  main.dart
  models/
    document.dart
  db/
    database_helper.dart      # sqflite setup, FTS5 schema, migrations
  services/
    ocr_service.dart          # ML Kit wrapper, runs off main isolate
    encryption_service.dart   # AES encrypt/decrypt, key management via flutter_secure_storage
    auth_service.dart         # local_auth PIN/biometric gate
  screens/
    lock_screen.dart
    home_vault_screen.dart    # document grid/list + search bar
    capture_screen.dart       # camera/import flow
    document_detail_screen.dart
    settings_screen.dart
  widgets/
    document_tile.dart
    search_bar.dart
    tag_chip.dart
  providers/
    vault_providers.dart      # riverpod providers for documents, search state, auth state
```

## Core systems

**Capture flow** (`capture_screen.dart`) — Capture via camera or pick from gallery. Show the captured image, allow a manual crop/rotate before confirming (keep this simple in v1 — a basic crop rectangle is enough, don't attempt automatic edge detection yet).

**OCR service** (`ocr_service.dart`) — Run ML Kit text recognition on the confirmed image, off the main isolate so the UI stays responsive. Return extracted text plus confidence/bounding data if useful for future features. Handle the case where OCR finds no text gracefully (still save the document, just with empty extracted text).

**Encryption service** (`encryption_service.dart`) — Generate an AES key on first launch, store it in `flutter_secure_storage`. Encrypt the document image file before writing it to disk; decrypt only into memory when displaying, never write a decrypted copy back to disk. This must hold up under actual inspection — write a quick verification step (e.g. a test that confirms the file on disk is not readable as a valid image without going through the decryption service).

**Database** (`database_helper.dart`) — A `documents` table (id, title, tags, created_at, encrypted_file_path) plus an FTS5 virtual table indexing the extracted text, kept in sync on insert/update/delete. Search queries hit the FTS5 table and return ranked results instantly as the user types (debounce input, don't query on every keystroke without a short delay).

**Auth service** (`auth_service.dart`) — Require PIN or biometric unlock every time the app is opened or resumed from background. Store the PIN hash (not plaintext) via `flutter_secure_storage`. First-run flow sets up the PIN.

**Organization** — Free-text tags per document, filterable from the home screen alongside search.

**Document detail / export** — View a document at full size, decrypted only in memory. Allow sharing/exporting a decrypted copy explicitly (with a clear one-time action, not a silently cached decrypted file).

## Build order

Confirm each phase actually runs on a device/emulator before moving to the next. Commit to git at the end of each one.

**Phase 1 — Scaffold and capture flow.** Project setup, folder structure, camera/gallery capture with manual crop confirmation, image displayed after capture. No storage or OCR yet.

**Phase 2 — OCR integration.** Wire up `ocr_service.dart`, run extraction on a captured image, display the extracted text alongside the image so you can visually confirm accuracy before moving on.

**Phase 3 — Encrypted storage.** Database schema, encryption service, save a captured-and-OCR'd document (encrypted image + extracted text + metadata) to disk. Verify the encryption actually holds (see the verification note above).

**Phase 4 — Full-text search.** FTS5 virtual table wired to the documents table, home screen search bar with instant, ranked, debounced results.

**Phase 5 — Organization and detail view.** Tags, filtering, document detail screen with decrypt-to-view and export/share.

**Phase 6 — App lock.** PIN setup flow, PIN/biometric gate on launch and resume-from-background.

**Phase 7 — Polish and performance pass.** Confirm 60fps scrolling and search on a real or representative emulator profile, empty states, error states (failed OCR, camera permission denied), consistent visual design across every screen — no screen should look unfinished next to the others.

**Phase 8 — Release packaging (final deliverables).**
- Build the final signed, release-mode Android APK (not a debug build), placed clearly in the repo (e.g. `builds/vaultly.apk`). If a phone is connected via USB with debugging enabled, install it directly with `adb install`; otherwise your human collaborator will transfer the file and install it manually — either way, the APK itself must be finished and installable, never a debug or placeholder build.
- Push the final repo state to GitHub.
- Create a `linkedin-post/` folder in the repo root containing 4-6 real screenshots (the lock screen, the vault/search view with real sample documents, the capture flow, and the document detail view are good picks) and a `caption.txt` with a short, genuine caption describing the project — mention on-device OCR, local full-text search, and AES encryption at rest specifically, since those are the actual technical differentiators, not generic hype.

**Phase 9 — stretch, only once every phase above is solid and shipped.** Automatic document-type detection from extracted text (simple keyword heuristics — "CNIC", "invoice", "receipt"), automatic edge detection/perspective crop for cleaner scans, an encrypted local backup/restore file.

<final_check>
Before considering the project done, verify against <critical_requirements> one more time: no placeholders anywhere, 60fps confirmed, OCR and search genuinely functional (not faked), documents genuinely encrypted at rest (verified, not assumed), GitHub repo pushed with real history, a final signed APK present and installable, and the `linkedin-post/` folder populated with real screenshots and a caption.
</final_check>
