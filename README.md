# Vaultly

A privacy-first personal document vault for Android. Photograph or import a
document, extract its text on-device with OCR, and it's encrypted at rest and
instantly searchable by full text — locked behind a PIN or biometric check.

No cloud. No account. No network calls of any kind — everything happens on
the device.

## Why

Most "document scanner" apps quietly upload your photos to a cloud service
for OCR and search indexing. Vaultly does the same job entirely offline: text
recognition, encryption, and full-text search all run locally, so IDs,
receipts, and notes never leave the phone.

## How it works

- **Capture** — camera or gallery import, with a manual crop/rotate step
  before anything is saved.
- **OCR** — [`google_mlkit_text_recognition`](https://pub.dev/packages/google_mlkit_text_recognition)
  runs on-device, off the main isolate, so the UI never blocks during a scan.
- **Storage** — each document image is AES-encrypted before it touches disk
  via the [`encrypt`](https://pub.dev/packages/encrypt) package; the key
  lives in the Android Keystore via
  [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage).
  Decrypted bytes only ever exist in memory.
- **Search** — extracted text is indexed in a SQLite FTS5 virtual table
  ([`sqflite`](https://pub.dev/packages/sqflite)), giving instant, ranked,
  debounced full-text search as you type — not a substring filter.
- **Lock** — PIN or biometric unlock on launch and on resume from background,
  via [`local_auth`](https://pub.dev/packages/local_auth).

## Tech stack

Flutter (Android) · Riverpod · google_mlkit_text_recognition · sqflite (FTS5)
· flutter_secure_storage · encrypt (AES) · local_auth · camera / image_picker

## Project structure

```
lib/
  main.dart
  models/       # Document data model
  db/           # sqflite setup, FTS5 schema
  services/     # OCR, encryption, auth
  screens/      # Lock, vault/search, capture, detail, settings
  widgets/      # Reusable UI pieces
  providers/    # Riverpod state
```

## Running it

```bash
flutter pub get
flutter run
```

Requires a device or emulator running Android 6.0 (API 23) or newer.

## Status

Built incrementally, phase by phase, with a working commit at the end of
each one — see the commit history for the build order, from capture through
OCR, encrypted storage, full-text search, tagging, and app lock.
