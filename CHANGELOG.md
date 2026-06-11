# Changelog

All notable changes to PSVellumPDF are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-11

First stable release, built on VellumPdf 1.1.0. PDF/A-2b output is now
validated with veraPDF (and structure with qpdf) in CI on every push.

### Added
- `Add-VellumPdfLineSeparator` for horizontal rules.
- `-Leading` (line spacing) on `New-VellumPdfTextRun` and `Add-VellumPdfParagraph`.
- `-MarginTop`/`-MarginBottom` spacing on all content cmdlets.
- `Register-VellumPdfFont -FontBytes` to embed a font from memory.
- `New-VellumPdfDocument -UseObjectStreams` (compressed object streams) and
  `-Language` (PDF `/Lang` entry for accessibility).
- Warning when text contains characters the base-14 fonts cannot encode -
  VellumPdf otherwise renders them silently mangled; use
  `Register-VellumPdfFont`/`-FontHandle` for full Unicode.
- Complete parameter help on every cmdlet (`Get-Help -Full` and docs/).
- Stress test generating a 200+ page mixed-content document.

### Fixed
- Cross-document font handles silently produced PDFs whose text cannot render;
  content cmdlets now reject handles registered on a different document.
- Dangerous `-LinkUri` schemes (`javascript:`, `vbscript:`, `data:`, `file:`)
  were written verbatim into `/URI` actions; now rejected. Whitespace-only
  URIs no longer produce a broken annotation.
- Cmdlets fail fast with a clear error when given a document that
  `Save-VellumPdfDocument` already disposed (VellumPdf silently accepts it).
- Calling `Protect-VellumPdfDocument` twice left an orphaned `/Encrypt`
  object; the second call now throws.
- `-ColumnWidth` accepts only positive widths (negative values produced
  malformed layout) and warns when the count does not match the columns.
- `Add-VellumPdfTable` rejects PSCustomObject rows (e.g. from `Import-Csv`)
  with a conversion hint instead of mangling all columns into one cell.
- Image load failures now include the file path; render failures from `Save`
  carry a remediation hint; emoji in encoding warnings report the real
  codepoint instead of a UTF-16 surrogate half.
- `Add-VellumPdfList -Item` accepts empty strings (blank entries).

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

[Unreleased]: https://github.com/Tim81/PSVellumPDF/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Tim81/PSVellumPDF/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/Tim81/PSVellumPDF/releases/tag/v0.1.0
