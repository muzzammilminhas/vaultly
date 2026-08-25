# Screenshot guide

Grab 4–6 screenshots and drop them straight into this `linkedin-post/`
folder (any filenames are fine — nothing reads them programmatically).

## Setup

1. Install the signed release build: `builds/vaultly.apk` (transfer to your
   phone, or `adb install builds/vaultly.apk` if it's connected via USB with
   debugging on).
2. First launch asks you to create a PIN — pick anything, it's just for the
   screenshots.
3. Use `assets/samples/` to populate the vault with a few realistic-looking
   documents (an electric bill, a grocery receipt, a vet note) instead of
   scanning something you actually care about:
   - Save those three PNGs to your phone's gallery (AirDrop/USB transfer/
     email them to yourself — whatever's easiest).
   - In Vaultly, tap **Scan document → gallery icon**, and import each one.
     Each will run through on-device OCR automatically.
   - Add a tag or two to at least one document (e.g. "Bills") so the tag
     filter row shows up on the home screen.

## Shots to get

1. **Lock screen** — the PIN pad (`Enter your PIN` state, not the first-run
   setup screen).
2. **Vault / search view** — home screen with the 3 sample documents
   visible in the grid, ideally with the search bar showing a query typed
   in (try "receipt" or "bill") so the ranked results are visible.
3. **Capture flow** — the crop/adjust screen mid-capture (camera or gallery
   import), showing the crop handles over a document.
4. **OCR review** — the "Extracted text" screen right after a scan, showing
   the image next to the text ML Kit actually pulled out. This is the best
   single shot for proving the OCR claim — pick the receipt or electric
   bill import so there's real readable text in the panel.
5. **Document detail view** — tap into one of the saved documents: full-size
   image, tags, date, and the export/share and delete icons in the app bar.
6. *(Optional)* Tag filter row on the home screen with a tag selected,
   showing the grid filtered down.

## Tips

- Use a real device if you have one — screenshots look sharper and more
  credible than an emulator for a portfolio post.
- Turn on dark or light mode consistently across all shots (don't mix).
- If you're on an emulator, `adb shell screencap -p /sdcard/shot.png` then
  `adb pull /sdcard/shot.png` works fine — no need for anything fancier.
- Crop out the status bar clock/battery if you want a cleaner look, but it's
  not necessary.
