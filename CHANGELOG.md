# Changelog

All notable changes to PSVellumPDF are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Add-VellumPdfLineSeparator` for horizontal rules.
- `-Leading` on `New-VellumPdfTextRun` and `Add-VellumPdfParagraph`.
- `-MarginTop`/`-MarginBottom` spacing on the content cmdlets.
- `Register-VellumPdfFont -FontBytes` to embed a font from memory.
- `New-VellumPdfDocument -UseObjectStreams` for compressed object streams.
- Warning when text contains characters the base-14 fonts cannot encode
  (silent data loss otherwise); use `Register-VellumPdfFont`/`-FontHandle`.
- CI conformance validation: qpdf structural checks and veraPDF PDF/A-2b
  validation of generated samples.
- Stress test generating a 200+ page mixed-content document.

## [0.1.0] - 2026-06-10

First public release, built on VellumPdf 1.1.0 (.NET 10).

### Added
- Fluent pipeline API: `New-VellumPdfDocument | Add-VellumPdf* | Save-VellumPdfDocument`.
- Documents: page size, margins, PDF/A-2b/2u/2a conformance, tagged PDF,
  `/Lang` language entry, document metadata (`Set-VellumPdfDocumentInfo`).
- Content: headings with outline bookmarks, paragraphs with mixed-style runs,
  colour and hyperlinks (`New-VellumPdfTextRun`), tables, ordered/unordered
  lists, images (JPEG/PNG/BMP/GIF/TIFF).
- Embedded TrueType fonts (`Register-VellumPdfFont` + `-FontHandle`) enabling
  Unicode text and PDF/A font embedding.
- Running headers/footers with `{page}`/`{pages}` tokens.
- Encryption with permissions (`Protect-VellumPdfDocument`, SecureString).
- Quality gates: PSScriptAnalyzer, Pester (94% coverage), 3-OS CI, locked
  NuGet restore, SHA-pinned actions, PSGallery release pipeline.

[Unreleased]: https://github.com/Tim81/PSVellumPDF/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Tim81/PSVellumPDF/releases/tag/v0.1.0
