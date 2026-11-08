# Project tools (`tool/`)

Small scripts that help build, test and maintain Volt Core. Run them from the project root. Use `python -I` (isolated mode) so a stray file in the current folder can't shadow a Python module.

| Tool | Use it to | Needs |
|---|---|---|
| [`inspect_xlsx.py`](../tool/inspect_xlsx.py) | Look inside an Excel file before importing it | Python only |
| [`utf8_scan.py`](../tool/utf8_scan.py) | Find (and repair) source files that are not valid UTF-8 | Python only |
| [`tablet.py`](../tool/tablet.py) | Build, install, screenshot and tap on the test tablet | adb, Flutter |
| [`dev_login.py`](../tool/dev_login.py) | Sign in on the tablet with a dev account | adb, `dev_credentials.local.json` |
| [`make_pdf_footer.py`](../tool/make_pdf_footer.py) | Rebuild the branded PDF footer artwork | PyMuPDF |
| [`make_app_icons.py`](../tool/make_app_icons.py) | Regenerate launcher icons, splash and store art from the logo | Pillow |
| [`bump_version.py`](../tool/bump_version.py) | Show or change the app version and keep CHANGELOG.md in step | Python only |

---

## `inspect_xlsx.py`: read a spreadsheet

Prints each sheet's name, whether it is hidden and its row count, then the first rows as `CELL=value` pairs. It reads the file with the Python standard library only, so no extra packages are needed.

```
python -I tool/inspect_xlsx.py "assets/Shop Steward Procurement Tracker.xlsx"
python -I tool/inspect_xlsx.py "assets/Shop Steward Procurement Tracker.xlsx" 40
```

The optional number is how many rows to show per sheet (default 15). Empty cells are skipped and values are cut at 60 characters.

Use it to see a sheet's layout (which row holds headings, which columns hold part numbers) before writing or changing an import. The in-app parts import is in `lib/modules/inventory/domain/import/`.

## `utf8_scan.py`: catch bad file encodings

```
python -I tool/utf8_scan.py          # report only
python -I tool/utf8_scan.py --fix    # repair what it finds
```

Scans `lib/`, `test/`, `tool/`, `docs/` and `supabase/` for `.dart`, `.md`, `.py`, `.sql`, `.yaml` and `.json` files. With `--fix` it replaces each invalid byte with `-` and rewrites the file as UTF-8. Without `--fix` it exits with status 1 if it finds any, so it can sit in a check script.

**When to run it:** after any scripted edit of source files. A script that reads or writes with the Windows default encoding turns characters like the em dash into a single legacy byte. The Dart compiler and tests accept that, but `flutter analyze` then reports the file as missing ("Target of URI doesn't exist") and every file importing it fails. In your own scripts, always open files with `encoding='utf-8'`.

## `tablet.py`: drive the test tablet

Wraps the adb and Flutter commands used to check changes on the Samsung tablet.

```
python -I tool/tablet.py build              # debug APK, with dev credentials if the file exists
python -I tool/tablet.py install            # install it, keeping the app's data
python -I tool/tablet.py relaunch           # force-stop and start the app
python -I tool/tablet.py shot out.png       # screenshot to out.png (default tablet.png)
python -I tool/tablet.py tap 72 700         # tap at pixel x y
python -I tool/tablet.py swipe 700 1800 700 500
python -I tool/tablet.py push file.xlsx     # copy to the tablet's Download folder
python -I tool/tablet.py push file.xlsx name.xlsx
```

Typical check after a change: `build`, `install`, `relaunch`, then `shot` and look at the picture.

- The tablet is `R52Y80JVX9M`. For another device, set the `VOLTCORE_DEVICE` environment variable to its serial.
- Coordinates are in pixels for the tablet's 1320 x 2112 screen.
- `relaunch` also restarts the offline sync queue. The queue now drains fully by itself, but a relaunch is a quick way to force a pass.
- Plain `adb push` from Git Bash rewrites `/sdcard/...` paths. `push` here avoids that.

## `dev_login.py`: sign in on the tablet

Types a dev account's email and password into the app's sign-in screen, picks the matching "Preferred view" and presses Sign in.

```
python -I tool/dev_login.py            # admin
python -I tool/dev_login.py tech       # also: supervisor, dispatcher
```

It reads `VOLTCORE_DEV_EMAIL_<ROLE>` and `VOLTCORE_DEV_PASSWORD_<ROLE>` from `dev_credentials.local.json`. That file is git-ignored; never commit it and never paste its values into chats or logs. The script prints only "submitted". If those entries are empty it stops and says so.

The taps assume the sign-in screen is showing on the 1320 x 2112 tablet with no keyboard open. Adjust the coordinates at the top of the script for another device.

Signing in replaces whoever is signed in. Sign out first from Settings, then run it. Anything not yet uploaded stays queued on the tablet for that account.

## `make_pdf_footer.py`: rebuild the PDF footer

Regenerates `assets/images/pdf_footer.svg` from the vector artwork in `assets/pdf/Modified Comp Checklist With Load Test.pdf`, so the app's PDF footer matches the paper form.

```
python tool/make_pdf_footer.py
```

Needs PyMuPDF (`pip install pymupdf`). Run it only if the checklist PDF's footer changes. `MAP_FILL` and `BAND_FILL` at the top control the colours.

The footer also carries the app logo at the left edge, before the company name: `assets/brand/logo-core-ring-footer.svg` (a pale-disc variant that stands apart from the navy band), drawn by `PdfTemplate.brandFooter`. It is separate from the band artwork, so this script does not touch it; if the logo asset is missing or invalid the footer renders without it.

---

## `bump_version.py`: change the app version

```
python -I tool/bump_version.py show
python -I tool/bump_version.py patch          # 0.9.0+3 -> 0.9.1+4
python -I tool/bump_version.py minor --tag    # new feature release; also tag v0.10.0
python -I tool/bump_version.py build          # same version, next build number
python -I tool/bump_version.py set 0.9.0+1    # exact; --dry-run shows without changing
```

Edits `pubspec.yaml` and moves the `Unreleased` lines in `CHANGELOG.md` under the new version. The build number only goes up. The policy (what counts as patch, minor or major, the pilot and production stages, release steps) is in `release_versioning.md`.

## Before you commit

```
python -I tool/utf8_scan.py
flutter analyze
flutter test
```

## `make_app_icons.py`: launcher icon, splash and store art

Draws the "B. Core Ring" logo from its geometry (Pillow, supersampled; no SVG renderer) and writes every icon the app ships with.

```
python -I tool/make_app_icons.py           # regenerate everything, then validate
python -I tool/make_app_icons.py --check   # validate only
```

Generates:
- Android: `mipmap-*/ic_launcher.png` (legacy, 22% rounded navy tile), `ic_launcher_foreground.png` and `ic_launcher_monochrome.png` (108 dp layers, logo in the 66 dp safe zone; the monochrome one is ring and bolt in solid white for Android 13 themed icons), `mipmap-anydpi-v26/ic_launcher.xml`, `values/ic_launcher_background.xml` (#0A1F4D), `drawable-*/splash_icon.png` (288 dp canvas, logo in the central 192 dp), `values-v31` and `values-night-v31` `styles.xml` (Android 12+ splash), and the pre-12 `launch_background.xml`.
- iOS: every size in `AppIcon.appiconset/Contents.json` (opaque), the LaunchImage files, and the LaunchScreen background colour.
- Web: favicon, `icons/Icon-*.png` and maskable variants (manifest and index.html colours are set by hand: #0A1F4D / #103078).
- Store: `docs/branding/store/icon-512.png`, `feature-graphic-1024x500.png` and `icon-preview.png`.

**When to re-run:** after changing the logo geometry or colours in the script. Commit the regenerated files.

**Preview:** open `docs/branding/store/icon-preview.png` (legacy icon, adaptive icon under circle / squircle / rounded masks, monochrome icon). On the dark variant: the pale disc is used everywhere because the navy tile would swallow the navy disc.

There is no `flutter_launcher_icons` config in `pubspec.yaml`, so nothing overwrites these files.
