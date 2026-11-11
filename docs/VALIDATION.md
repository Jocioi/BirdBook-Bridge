# Validation and limitations

## Version 1.3.5 — straighten rotation, 2026-11-11

- Passed 116 metadata/geometry assertions, 75 generated-format assertions, 83 Swift registration cases, 4 compiled-helper CLI cases and 21 isolated mocked Lua flow cases (299 total); 245 pinned library hashes match.
- Non-square crops, both signs of rotation through 45 degrees, all 8 EXIF orientations, reversed crop diagonals, partial clipping and invalid angles are covered. Existing texture, local-content, displacement and round-trip guards remain.
- A real ARW/JPEG pair with -1.83 degree straighten, cropping and Adobe lens correction produces a registered reference frame on a copy. Previously fixed portrait/profile samples are regression checked. Source photographs are kept outside the package and remain unchanged.
- No fresh Lightroom UI export or physical Duo visual acceptance of this revision; file-level helper/readback checks do not establish those. Intel compiles but remains untested on hardware.

## Version 1.3.4 — portrait crop fix, 2026-11-09

- Passed 76 metadata/geometry assertions, 75 generated-format assertions, 15 Swift registration cases and 4 compiled-helper CLI cases. All-orientation asymmetric crops and rejection of locally mismatched imagery are covered; vendor hashes match. Lua flow code is unchanged; 21 mocked export-flow cases also pass using Lightroom’s installed Lua runtime in an isolated process.
- A real portrait ARW/export pair with EXIF orientation 8, rectangular cropping and Adobe lens-profile correction was processed on a copy. Before: unsupported-edits. After: registered-reference. The production BirdBook reader accepted its bounded reference rectangle. Original source/export files were not modified.
- Local frame correlation exceeded 0.99 and both contextual side checks exceeded 0.97 in the diagnostic run; this does not establish pixel-exact optical calibration. Real-photo media remains outside the distributable package.
- The user confirmed the previously failing photo now works with the updated installed plugin, which shares this focus-frame implementation. This is user-reported acceptance, not an agent-observed full export/UI acceptance of every supported format. Intel helper compiled but has not run on Intel hardware.

## Version 1.3.3 — Chinese name, 2026-11-07

- Chinese display name changed to 波斑鸨插件 (BBB), keeping the toolkit ID, filter ID, installation directory and XMP namespaces. Metadata-processing source and compiled helper are unchanged from 1.3.2.
- Passed 75 generated-image format checks, 60 metadata checks, 21 mocked Lua export-flow checks, 5 Swift registration checks and 4 compiled-helper CLI checks (165 total). Vendor hashes passed.
- The first sandboxed registration run could not access the system image-registration service; rerunning the registration, metadata and helper checks with normal host service access passed. No production behavior change was made for this environment limitation.
- Lightroom UI export acceptance, real camera-JPEG acceptance and Intel hardware execution remain pending. No real photographs are distributed.

## Version 1.3.2 — publication checks, 2026-11-07

- 60 metadata assertions and 75 generated-image format assertions pass, including all 51 writable capture fields, firmware validation, retired-field cleanup, native filename/rating preservation and source-file facts.
- Five Swift registration cases and four compiled-helper CLI cases pass. All 245 pinned ExifTool library hashes match. Universal arm64/x86_64 helper builds successfully.
- All 21 mocked Lua export-flow cases pass against the current filter using Lightroom’s installed Lua runtime, loaded into an isolated test process. No catalog or live plugin is opened. The normal test script reports a skip if a standalone Lua interpreter is absent; run `lua tests/filter.lua` when available.
- Companion-app targeted tests cover exposure-summary deduplication, Sony APS-C conversion and metadata rendering. They do not establish physical-phone visual acceptance.
- All 12 targeted companion-app tests pass. Light-mode snapshot reviewed; fresh iPhone build installed and launched. Physical interaction remains unverified.
- Extracted 1.3.2 package processed one real ARW/LR-rendered JPEG pair outside the release tree. Firmware, APS-C and original-file facts read back; physical focal length remains 600 mm and native equivalent remains 900 mm. Source SHA-256 unchanged. This is a file-level check, not a Lightroom UI export.
- No fresh Lightroom UI export or real in-camera JPEG acceptance. The live installed plugin and saved export presets are not replaced by this packaging task. This is a development release with the limitations below; publication does not establish Lightroom UI acceptance.

## Earlier validation: 1.3.1

- 53 metadata assertions pass, including two new capture fields, range validation and native white-balance deduplication.
- 57 generated-image format assertions pass. The existing 21 Lua flow cases are unchanged.
- Companion BirdBook code was updated without changing source media or the data model. Five focused iOS Simulator XCTest cases and the App build pass: equipment/file metadata grouping, invalid-value handling, fractional dates, all three output formats, and existing capture settings.
- Two actual Lightroom JPEG samples expose serial numbers through Apple ImageIO; only presence and equality were checked, not published values. Battery/temperature producer-to-reader checks use temporary files.
- Phone installation, phone visual acceptance and a fresh Lightroom UI export of this version remain pending. GitHub publication is paused.

## Earlier validation: 1.3.0, 2026-11-06

This update accepts Sony α1 II ARW and camera JPG/JPEG sources and writes JPEG, TIFF and PNG outputs. It adds explicit batch results rather than treating unsupported cases as completed supplementation.

Completed for this update:

- **57 format-integration assertions** with a generated Sony-model JPEG source and generated JPEG, transparent PNG and 16-bit TIFF exports. Checks cover filling missing EXIF, keeping existing values and dates, not restoring removed GPS, writing embedded XMP, preserving decoded pixels, alpha, bit depth, colour profile and encoded image payload, repeat execution, unsupported-camera reporting and rejecting in-place source writes.
- **45 metadata assertions**, including guarded camera-JPEG focus geometry and preview registration, existing crop/orientation guards and metadata preservation.
- **21 Lua export-flow cases** using Lightroom's installed Lua runtime with mocked SDK services, without opening or changing a catalog. Cases cover all three output formats, ARW/JPG/JPEG routing, metadata settings, offline sources, helper reports, cleanup, one batch notification, filenames containing Unicode/apostrophes and continuing after a single failure.
- Perl syntax check. The Swift registration algorithm is unchanged from 1.2.1; its earlier five functional cases and four CLI cases are historical evidence, not newly executed checks for this update.

Tests generate all fixture images. A source labelled with Sony model information exercises the integration path but is **not a real in-camera JPEG or proof of every MakerNotes variant**. A fresh Lightroom UI export and real-camera JPEG acceptance remain pending. HDR gain maps, 32-bit TIFF and older OS/Intel runtime behaviour have not been accepted.

Normal batch results use a brief bezel. A batch containing skipped or failed photos shows one explanatory message; no per-photo confirmation is required. Source-JPEG focus frames remain withheld until their coordinate geometry can be validated. The current live Lightroom installation and BirdBook app checkout are unchanged.

The format checks can run independently of Vision/GPU services:

```sh
mkdir -p .build/fixtures
swiftc -module-cache-path .build/module-cache tests/formats.swift -o .build/format-fixtures
.build/format-fixtures generate .build/fixtures
perl -I BirdBookBridge.lrplugin/lib tests/formats.t .build/fixtures .build/format-fixtures
perl -I BirdBookBridge.lrplugin/lib tests/metadata.t .build/fixtures/image.jpg
```

Run `lua tests/filter.lua` with a Lua 5.1-compatible interpreter for the mocked export-flow checks. `scripts/test.sh` runs them when `lua` is installed and explicitly reports when it is absent. The plugin itself uses Lightroom's Lua runtime and requires no separate Lua installation.

## Historical snapshot: 1.2.1, 2026-11-06

This snapshot was prepared independently of the live BirdBook app checkout and installed Lightroom plugin. The runtime algorithm is the installed 1.2 implementation; this release changes the public name, version and packaging, and adds reproducible synthetic tests and documentation.

Completed on macOS / Apple Silicon:

- Compiled the reference-frame helper for **arm64** and **x86_64**, deployment target macOS 13; checked both architectures in the resulting universal binary.
- Perl helper syntax check.
- Verified all **245** bundled ExifTool library files and the upstream README against ExifTool **13.55**, upstream commit `de11d240cf7e521e939a0575a128ffe01b63be05`. The library-file hashes are pinned in `vendor-manifest.json`.
- **43 Perl assertions** covering AF/crop/orientation guards, unsupported models and modes, invalid values, preserving existing EXIF, supplementing missing fields, all 20 XMP capture fields, repeat writes, and byte-for-byte preservation of the JPEG compressed scan.
- **5 Swift registration cases**: identity, known small displacement, rejection of unrelated images, rejection of low-texture images, and rejection of invalid frame bounds.
- **4 built-helper CLI cases**: valid identity image pair, low texture, missing JSON fields and malformed JSON.
- Reviewed first-party source and packaged files for private paths, camera samples, credentials and generated build material.

Tests generate their own images. No real photograph, GPS sample, serial number or private shooting record is needed or distributed. Core Image and Vision tests need access to normal macOS image-processing services; a restricted file sandbox can prevent rendering.

## Earlier installed-plugin evidence

Before this independent packaging task, the source plugin was exercised in **Lightroom Classic 15.5.1** on the developer's machine with Sony α1 II RAW → JPEG. The development record reports a successful 20-setting readback and a lens-corrected reference-frame export. That record informed this snapshot; it is not a fresh test of the publicly branded package.

## Not established by these checks

- The newly branded package has **not been installed into or exported from Lightroom** during this packaging task, to avoid disturbing active development.
- The Intel slice was compiled, but **not executed on an Intel Mac**. macOS 13 is the deployment target, not a claim that all supported OS / Lightroom combinations have been tested.
- No general accuracy guarantee for lens-corrected reference frames. Synthetic tests establish basic registration and rejection behaviour; they do not replace camera/lens calibration across real scenes.
- No fresh physical-iPhone UI acceptance. Other viewers may ignore custom XMP, and later metadata-stripping exports or messaging transfers may remove it.
- No support claim for other Sony models, other brands, DNG/TIFF/HEIC, or Windows. Nonmatching exports are passed through.
- Lua runs inside Lightroom; no standalone Lua interpreter or full Lightroom SDK integration harness is included.
- No Apple distribution signature or notarization. No Adobe SDK binary is included.

Reproduce local checks with `sh scripts/build.sh` followed by `sh scripts/test.sh`. Build and tests operate inside this checkout; neither installs the plugin nor edits Lightroom settings.
