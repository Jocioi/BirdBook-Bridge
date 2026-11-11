# Changelog

## 1.3.5 — 2026-11-11

- 支持 Lightroom 拉直旋转与裁切、横竖拍方向和轻微镜头配置文件校正叠加；旋转后通过图像配准验证，输出参考对焦框。
- 修复较大正负旋转角度导致裁切对角坐标倒序时的误拒绝。
- 对焦框部分越过裁切边缘、但中心仍在画面内时保留可见部分；中心已被裁掉时仍不输出。
- 修复白平衡以文字形式读取时的数字转换警告，保留原有元数据语义。
- 新增正反旋转、全部 EXIF 方向、非正方形照片和边缘/非法角度回归检查；透视、手动畸变、低纹理和不匹配保护保留。

## 1.3.4 — 2026-11-09

- 修复竖拍照片在裁切并开启镜头配置文件校正后，对焦框被误判为不可还原的问题；显示结果仍为参考对焦框。
- 用户已确认此前出现问题的照片能够显示对焦框。
- Map rectangular crops in unrotated RAW axes before applying EXIF orientation, including portrait photos.
- Enable the existing guarded lens-profile registration path for oriented RAWs. Ignore extracted preview JPEG orientation and apply the RAW orientation exactly once.
- Keep the close AF-region correlation check and give independent side checks more context for small AF boxes. Correlation, texture, displacement and round-trip thresholds remain unchanged.
- Add all-orientation asymmetric-crop tests, local-mismatch rejection and invalid-orientation checks. Existing metadata/privacy behavior is unchanged.

## 1.3.3 — 2026-11-07

- 中文名改为「波斑鸨插件」，Lightroom 管理器与导出动作使用该名称；英文名 BirdBook Bridge、简称 BBB 保留。
- 保留插件标识、安装目录及元数据命名空间，元数据处理行为与 1.3.2 相同。
- 添加官网介绍与下载页地址。

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
