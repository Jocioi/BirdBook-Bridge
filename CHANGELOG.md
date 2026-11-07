# Changelog

## 1.3.2 — 2026-11-06

- Expand optional capture/source fields from 22 to 51, including validated camera firmware, APS-C mode, original-file facts, white-balance adjustments, colour settings and lens corrections.
- Prefer native EXIF, Lightroom raw filename and XMP rating; supplement supported missing fields only. Preserve the privacy boundary for dates, GPS and serial numbers.
- Clear six retired custom fields during re-export without removing native Lightroom metadata.
- Preserve JPEG/TIFF/PNG support, source-JPEG geometry safeguards and batch reporting.
- Refresh installation, metadata and companion-app display documentation. Packaging does not replace the installed Lightroom plugin.

## 1.3.1 — 2026-11-06

- Preserve capture battery percentage and camera-recorded ambient temperature when available and valid.
- Avoid duplicating Auto/Manual white balance already represented in standard EXIF; retain more specific camera presets.
- Existing Lightroom-exported serial numbers and other native EXIF remain untouched. The companion BirdBook reader now reads these fields directly, including fractional capture time and estimated distance in TIFF/PNG.

## 1.3.0 — 2026-11-06

- Accept camera JPG/JPEG sources as well as ARW for Sony α1 II; never overwrite the source file.
- Add TIFF and PNG outputs alongside JPEG, including preservation checks for 16-bit TIFF and transparent PNG.
- Report completed, partial, skipped and failed results once per batch. Give actionable reasons for unsupported formats/cameras, offline sources and metadata settings.
- Continue processing remaining photos after an individual failure, clean up temporary reports, and reject unrecognized helper results.
- Simplify export instructions around a saved Lightroom preset, with no per-field configuration or extra original-file pairing step.
- Preserve available camera-JPEG metadata without emitting a focus box from unvalidated JPEG geometry.
- Add generated-image integration tests and Lua export-flow tests. Lightroom UI acceptance remains pending; the live installation is unchanged.

## 1.2.1 — 2026-11-06

- Publish the plugin source as **BirdBook Bridge (BBB)**, derived from 「LR小鸟书信息补全」 1.2.
- Preserve toolkit identity and metadata namespaces for existing BirdBook files.
- Add install instructions, metadata contract, supported-camera limits and explicit reference-frame semantics.
- Include unmodified ExifTool 13.55 library sources, attribution and the Artistic license.
- Add a universal macOS helper build, distributable ZIP packaging and synthetic verification.

The metadata algorithm is unchanged from 1.2. No existing Lightroom installation or BirdBook app checkout is modified by the build.
