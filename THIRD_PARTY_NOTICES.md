# Third-party notices

## ExifTool 13.55

- Author: Phil Harvey and upstream contributors.
- Upstream: https://github.com/exiftool/exiftool
- Version: 13.55
- Upstream commit: `de11d240cf7e521e939a0575a128ffe01b63be05`
- Files: `BirdBookBridge.lrplugin/lib/` and `BirdBookBridge.lrplugin/ExifTool-README`.
- Copyright: 2003–2026 Phil Harvey; preserve individual file notices for other contributors.
- License: same terms as Perl itself, either the Perl Artistic License or GPL. This distribution uses the Artistic option. Full Artistic license text is in `licenses/Artistic.txt`; the upstream license notice is preserved in `ExifTool-README`.

The bundled library files are unmodified. Their Git blob hashes are recorded in `vendor-manifest.json` for comparison with the upstream commit. The distribution is the library subset, not the full ExifTool command-line package. No ExifTool executable or upstream test photographs are included.

BBB's MIT license applies to its own source and documentation, not to these third-party files.

## Apple system frameworks

The optional reference-frame helper uses Foundation, Core Image, ImageIO, Vision and simd supplied by macOS. Their implementations and SDKs are not redistributed. The helper source is BBB code, built with the locally installed Apple toolchain.

## Lightroom SDK interface

The Lua code calls Lightroom's plugin APIs. No Adobe SDK files, Adobe binaries, camera firmware, lens profiles, or photo samples are included.
