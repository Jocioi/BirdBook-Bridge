# Metadata contract

Additions are embedded in the exported JPEG, TIFF or PNG. BBB does not require a sidecar for these output formats. Supported sources are Sony ILCE-1M2 ARW and camera JPEG files; missing source information is not inferred.

## Standard EXIF

Only missing values are copied from the corresponding source image:

`Make`, `Model`, `LensModel`, `LensMake`, `LensInfo`, `FileSource`, `ExposureTime`, `FNumber`, `ISO`, `FocalLength`, `FocalLengthIn35mmFormat`, `ExposureCompensation`, `ExposureMode`, `ExposureProgram`, `MeteringMode`, `Flash`, `WhiteBalance`.

Dates, GPS, serial numbers, dimensions, orientation, colour profiles and editing metadata are deliberately excluded from this supplementation list. Existing exported values take precedence.

## Estimated distance

`XMP-aux:ApproximateFocusDistance` is written only when absent, using Sony `FocusPosition2` and ExifTool's `Composite:FocusDistance2`. A code of 255 maps to the field's infinity sentinel, 4294967295. Unknown and invalid distances are omitted. This is an estimate, not a measured subject distance.

## Capture settings: `bbinfo`

Namespace URI: `https://bird.uioiu.com/ns/capture/1.0/`. This is an identifier, not a network endpoint contacted by the plugin.

Version 1.3.2 supports the following 51 optional capture/source fields. Source groups are Sony unless explicitly listed below. Missing source data is omitted; 51 is not a per-photo guarantee.

| Field | Meaning |
| --- | --- |
| FocusMode | Capture focus mode |
| AFAreaModeSetting | Selected AF area |
| AFAreaMode | Actual AF area |
| AFTracking | AF tracking setting |
| ImageStabilization | Stabilization |
| ReleaseMode | Drive/release mode |
| ElectronicFrontCurtainShutter | Electronic front curtain; not a complete shutter-type description |
| WhiteBalance | Capture white balance |
| WhiteBalanceFineTune | Capture white-balance adjustment |
| ColorTemperature | Capture colour temperature setting |
| HighISONoiseReduction | High-ISO noise reduction |
| LongExposureNoiseReduction | Long-exposure noise reduction |
| MultiFrameNoiseReduction | Multi-frame noise reduction |
| DynamicRangeOptimizer | Camera DRO setting |
| CreativeStyle | Camera creative style |
| PictureEffect | Camera picture effect |
| SequenceNumber | Burst sequence number |
| LensFirmwareVersion | Lens firmware |
| LensMount | Mount |
| LensFormat | Lens format |
| BatteryLevel | Capture battery percentage, validated within 0–100 |
| AmbientTemperature | Camera-recorded ambient temperature in Celsius, validated within -100–150 |
| SourceCameraSoftware | IFD0:Software; only validated ILCE-1M2 firmware strings, not Lightroom editing software |
| CameraEMountVersion | Sony:CameraE-mountVersion |
| LensEMountVersion | Sony:LensE-mountVersion |
| APSCSizeCapture | Sony:APS-CSizeCapture; explicit crop-mode flag |
| ISOSetting | Camera ISO selection |
| ExposureStandardAdjustment | Camera exposure standard adjustment |
| FlashExposureComp | Flash exposure compensation |
| RAWFileType | Original RAW compression/type setting |
| Quality | Original shooting quality |
| FileFormat | Camera original file-format setting |
| OriginalImageSize | Sony:FullImageSize; original effective dimensions |
| WBShiftAB_GM_Precise | Capture white-balance axis shift |
| PrioritySetInAWB | Auto-white-balance priority |
| Saturation | In-camera saturation |
| Sharpness | In-camera sharpness |
| SharpnessRange | In-camera sharpness range |
| Highlights | In-camera highlights |
| Shadows | In-camera shadows |
| Fade | In-camera fade |
| PictureProfile | Camera picture/gamma profile |
| HDR | Camera HDR setting |
| SoftSkinEffect | Camera soft-skin setting |
| VignettingCorrection | Camera vignetting correction |
| LateralChromaticAberration | Camera chromatic-aberration correction |
| DistortionCorrectionSetting | Camera distortion correction |
| CameraOrientation | Camera-recorded shooting orientation |
| OriginalFileName | System:FileName; only when exported crs:RawFileName is absent |
| OriginalFileSizeBytes | Exact source-file byte count, not the exported image size |
| OriginalFileType | File:FileType of the source, not destination |

Also included when available: `Version` (currently `1`), `SourceModel`, `OriginalFocusLocation`, `OriginalFocusFrameSize`, `OriginalOrientation`, `FocusPosition2`.

Existing standard EXIF is not duplicated. Auto/Manual white balance is omitted from custom XMP when the equivalent EXIF mode is already present; more specific Sony presets are retained. Serial numbers already exported by Lightroom are left in place and read by the viewer, not added to the supplementation list.

These are capture settings, not descriptions of Lightroom's final rendering. Unknown, empty, oversized or control-character-containing values are omitted. BBB replaces its own capture fields on each run to avoid stale data.

Native `XMP-xmp:Rating` takes precedence, including zero. Only an absent rating is filled from Sony:Rating (0–5). Native capture dates, subseconds and timezone offsets are read directly by BirdBook; they are not duplicated. LightValue is computed by the app from native exposure values.

Retired custom fields `OriginalBitDepth`, `Brightness`, `Clarity`, `Contrast`, `ISOAutoMin`, `ISOAutoMax` are cleared during re-export. Their native Lightroom counterparts are not removed. Battery level is not battery health; no memory-card identity, battery identity or missing serial-number recovery is promised.

BirdBook's Sony APS-C summary uses physical EXIF FocalLength × 1.5 only when the explicit crop flag is On. It labels the result equivalent focal length and never rewrites physical focal length or multiplies an already-equivalent field.

## Focus frames: `bbfocus`

Namespace URI: `https://bird.uioiu.com/ns/focus/1.0/`.

- `Frame`: directly transformed camera frame.
- `ReferenceFrame`: image-registration estimate, intended to be visibly labelled **reference** by readers.
- `Status`: `available`, `registered-reference`, `missing`, `outside-crop`, or `unsupported-edits`.

Both frame strings contain seven space-separated numbers:

```text
version width height x y boxWidth boxHeight
```

Version is `1`. Dimensions refer to the exported image. Rectangle values are fractions of final image dimensions, with origin at the **top left**, and must remain within `[0,1]`. The frame and reference-frame fields are cleared before writing the result of a new run.

From 1.3.4, Lightroom rectangular crop bounds are applied in unrotated RAW axes before the EXIF orientation transform. Preview registration uses the same order and explicitly applies the RAW orientation once; extracted preview JPEG metadata cannot cause a second rotation. From 1.3.5, CropAngle from -45 to +45 degrees is mapped using the two opposite crop corners in source pixel axes, including reversed diagonals. The rotated AF rectangle is represented by its axis-aligned bounds. Rotation always requires successful preview registration, even with lens-profile correction disabled. Perspective adjustments and unvalidated source-JPEG geometry remain guarded. A partially clipped frame is retained only while its recorded centre is visible. Profile-corrected output is still a reference estimate, never labelled as an exact frame.

Camera JPEG sources may already contain geometric corrections not described by the recorded AF coordinates. This version preserves their available capture metadata but does not emit a frame or attempt preview registration for them. The helper reports partial completion when no frame can be emitted.

The command-line helper emits one result token after a successful run: `completed`, `partial-focus`, or `unsupported-camera`. Errors exit nonzero. The Lightroom filter captures the token in a temporary report, deletes that report, and presents one batch result. Unknown or missing tokens are treated as failure rather than silent success.

Readers must distinguish `ReferenceFrame` from `Frame`, validate all dimensions and bounds, and honour the status. Removing XMP during a later export or messaging transfer removes these fields.

## Why not put the focus box in SubjectArea?

EXIF `SubjectArea` and `SubjectLocation` describe the main subject, not a rich camera AF event or the confidence/provenance of an estimated rectangle after lens correction. EXIF `SubjectDistance` also exists, but does not preserve this plugin's explicit approximate-distance semantics. BBB uses named XMP fields to retain these distinctions.

References: [Adobe's EXIF namespace](https://github.com/adobe/xmp-docs/blob/master/XMPNamespaces/exif.md), [ExifTool XMP tag table](https://exiftool.org/TagNames/XMP.html), [ExifTool Sony tag table](https://exiftool.org/TagNames/Sony.html).
