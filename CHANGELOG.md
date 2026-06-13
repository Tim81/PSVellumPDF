# Changelog

All notable changes to PSVellumPDF are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-06-13

Built on VellumPdf 1.5.2 (was 1.2.0).

### Added
- `Set-VellumPdfSignature` RFC-3161 timestamps: `-TimestampUrl` contacts a
  Time-Stamping Authority while `Save-VellumPdfDocument` signs, upgrading the
  signature from PAdES B-B to B-T so the signing time is attested by the TSA
  rather than the signer's clock. `-TimestampTimeout` (a TimeSpan) and
  `-TimestampRequestCertificate` (default `$true`, embeds the TSA certificate
  for offline verification) tune the request. Saving a timestamped signature
  needs network access to the TSA.
- `Add-VellumPdfImage` accepts JBIG2 (`.jbig2`, `.jb2`) and JPEG 2000 (`.jp2`,
  `.jpx`, `.j2k`, `.jpf`) images, using the VellumPdf 1.4.0 codecs.

### Changed
- VellumPdf 1.3.0-1.5.2 widen image support (interlaced and 16-bit PNG; TIFF
  LZW/JPEG/Group-3/Group-4; JBIG2; JPEG 2000) and harden the image, font, and
  signing code. Existing pipelines pick these up without changes.

### Notes
- AcroForm interactive form fields and outline expand/collapse state
  (`PdfOutlineEntry.IsExpanded`) ship in VellumPdf but stay unwrapped: both need
  kernel `PdfPage` references that the layout `Document` this module drives does
  not expose, the same limit that keeps internal go-to links and standalone
  outline entries out of scope. See CLAUDE.md.

## [1.1.1] - 2026-06-11

### Fixed
- `Save-VellumPdfDocument` now renders (and signs) to a temporary file and moves
  it into place only on success, so a render or signing failure no longer
  truncates an existing good file at `-Path`, and a failed save leaves no
  0-byte artifact behind.
- `Save-VellumPdfDocument -WhatIf` to a nonexistent directory no longer throws
  or disposes the document - a dry run now leaves the document open as
  documented. A real (non-`-WhatIf`) save to a missing directory still fails
  fast and disposes the document.
- Signing and file-write failures from `Save-VellumPdfDocument` now carry
  operation-specific guidance (certificate/signing or path-writability) instead
  of the layout/render hint.
- `-LinkUri` scheme blocklist now normalises out embedded whitespace and control
  characters before matching, closing a bypass where `java<TAB>script:`, a
  mid-keyword no-break space, or a leading control byte could smuggle a blocked
  scheme past the check (lenient PDF readers strip such noise before dispatching
  the scheme).

## [1.1.0] - 2026-06-11

Built on VellumPdf 1.2.0 (was 1.1.0).

### Added
- `Set-VellumPdfSignature`: PAdES digital signing (SubFilter
  `ETSI.CAdES.detached`) via the new `VellumPdf.Signing` package. Stage a
  signature anywhere in the pipeline with an `[X509Certificate2]` (from
  `Get-PfxCertificate` or the `cert:` drive) plus optional `-Reason`,
  `-Location`, `-ContactInfo`, `-SignerName` and `-SigningTime`;
  `Save-VellumPdfDocument` signs the document while writing it. Composes with
  PDF/A conformance. Signing and encryption cannot be combined (library
  constraint) - both `Set-VellumPdfSignature` and `Protect-VellumPdfDocument`
  fail fast on the conflict.
- `Set-VellumPdfOutputIntent`: replace the default sRGB PDF/A output intent
  with a custom ICC profile (`-IccProfilePath`/`-ComponentCount`) or the
  library's built-in generic CMYK profile (`-Cmyk`).

### Changed
- VellumPdf 1.2.0 brings CFF (OpenType-CFF) font subsetting, cmap subtable
  formats 0 and 6, ICC-based colour management, and hardened font parsers.
  Existing pipelines benefit transparently (smaller embedded-font output).

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

[Unreleased]: https://github.com/Tim81/PSVellumPDF/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/Tim81/PSVellumPDF/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/Tim81/PSVellumPDF/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/Tim81/PSVellumPDF/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Tim81/PSVellumPDF/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/Tim81/PSVellumPDF/releases/tag/v0.1.0
