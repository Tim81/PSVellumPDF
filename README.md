# PSVellumPDF

[![CI](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml/badge.svg)](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSVellumPDF)](https://www.powershellgallery.com/packages/PSVellumPDF)

PowerShell module for creating PDF files on Windows, Linux, and macOS, built on
the [VellumPdf](https://github.com/Tim81/VellumPDF) .NET 10 library: a
zero-dependency PDF engine with PDF/A archival conformance and tagged,
accessible-PDF output.

This module generates new PDFs. It does not read, edit, split, or merge existing
files; VellumPdf is a write-only engine with no PDF parser.

> Status: **1.4.0 (pre-release)**, on VellumPdf 1.5.4. The full VellumPdf layout API
> is wrapped: documents, headings, paragraphs (incl. mixed-style runs, colour,
> hyperlinks, line spacing), tables, lists, images, line separators, embedded
> TrueType fonts, headers/footers, metadata, margins, bookmarks, encryption,
> **PAdES digital signing (with RFC-3161 timestamps)**, and custom PDF/A output
> intents. PDF/A-2b output (plain and signed) is validated with veraPDF in CI on
> every push. See the [CHANGELOG](https://github.com/Tim81/PSVellumPDF/blob/main/CHANGELOG.md) for release history.

## Requirements

- **PowerShell 7.6+** (runs on .NET 10)
- **.NET 10 SDK** — needed only to restore the VellumPdf assemblies

## Install

From the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSVellumPDF):

```powershell
Install-PSResource PSVellumPDF
```

### From source

```powershell
git clone https://github.com/Tim81/PSVellumPDF
cd PSVellumPDF

# Fetch the VellumPdf assemblies into ./lib (one-time, and after version bumps):
./build.ps1 Restore

Import-Module ./PSVellumPDF.psd1
```

## Usage

The functions form a fluent pipeline: create a document, add content, save.

```powershell
New-VellumPdfDocument -Conformance PdfA2b -PageSize A4 |
    Add-VellumPdfHeading   -Text 'Quarterly Report' -Level 1 -FontSize 20 |
    Add-VellumPdfParagraph -Text 'Generated with PSVellumPDF.' -Alignment Justify |
    Save-VellumPdfDocument -Path ./report.pdf
```

| Function | Purpose |
|---|---|
| `New-VellumPdfDocument` | Create a document (`-Conformance` incl. `PdfUA1`, `-PageSize`, `-PageWidthMm`/`-PageHeightMm`, `-DefaultFont`, `-DefaultFontSize`, `-Tagged`, `-Language`, `-Margin`/per-side margins, `-UseObjectStreams`) |
| `Add-VellumPdfHeading` | Add a heading (`-Text`, `-Level`, `-Font`, `-FontSize`, `-Alignment`, `-Color`, `-BookmarkTitle`, `-FontHandle`, `-Language`, `-MarginTop/Bottom`) |
| `Add-VellumPdfParagraph` | Add body text (`-Text`, `-Font`, `-FontSize`, `-Alignment`, `-FontHandle`, `-Color`, `-LinkUri`, `-Leading`, `-Language`, `-MarginTop/Bottom`) or mixed-style runs (`-Run`) |
| `New-VellumPdfTextRun` | Build a styled run (`-Text`, `-Font`, `-FontSize`, `-FontHandle`, `-Color`, `-LinkUri`, `-Leading`) for `-Run` paragraphs |
| `Add-VellumPdfTable` | Add a table — value arrays, `Import-Csv` records, or rich per-cell hashtables (`-Header`, `-Row`, `-ColumnWidth`, `-ColumnAlignment`, `-BorderWidth`, `-BorderColor`, `-HeaderBackground`, `-AlternateRowBackground`, `-Font`, `-FontHandle`, `-FontSize`, `-CellPadding`, `-Alignment`, `-MarginTop/Bottom`); header and body cells accept `Background`, `Alignment`, `Font`/`FontHandle`, `FontSize`, `Color`, `Padding`, `Language`, `ColSpan`, `RowSpan` |
| `Add-VellumPdfList` | Add an ordered/unordered list, flat or nested (`-Item` strings or `@{Text;Children}`, `-Style`, `-Indent`, `-Font`, `-FontHandle`, `-FontSize`, `-Language`, `-MarginTop/Bottom`) |
| `Add-VellumPdfImage` | Embed an image from a file or memory — JPEG, PNG, BMP, GIF, TIFF, JBIG2, JPEG 2000 (`-Path` or `-ImageBytes`/`-Format`, `-Width`, `-Height`, `-Alignment`, `-AltText`, `-MarginTop/Bottom`) |
| `Add-VellumPdfLineSeparator` | Add a horizontal rule (`-LineWidth`, `-Color`, `-MarginTop/Bottom`) |
| `Register-VellumPdfFont` | Load a TrueType font for embedding (`-Path` or `-FontBytes`); returns a handle for `-FontHandle` |
| `Set-VellumPdfHeader` / `Set-VellumPdfFooter` | Running bands with `{page}`/`{pages}` tokens (`-Template`, `-Font`, `-FontSize`, `-Alignment`) |
| `Set-VellumPdfDocumentInfo` | Document metadata (`-Title`, `-Author`, `-Subject`, `-Keywords`, `-Creator`, `-Producer`) |
| `Protect-VellumPdfDocument` | Password protection (`-UserPassword`/`-OwnerPassword` as SecureString, `-Permission` flags, `-EncryptMetadata`) |
| `Set-VellumPdfSignature` | Stage a PAdES digital signature (`-Certificate` with private key, `-Reason`, `-Location`, `-ContactInfo`, `-SignerName`, `-SigningTime`, and `-TimestampUrl`/`-TimestampTimeout`/`-TimestampRequestCertificate` for an RFC-3161 B-T timestamp); applied by `Save-VellumPdfDocument` |
| `Set-VellumPdfOutputIntent` | Replace the default sRGB PDF/A output intent (`-IccProfilePath`/`-ComponentCount` or `-Cmyk`) |
| `Save-VellumPdfDocument` | Write the `.pdf` — signing it if a signature is staged — and dispose the document (`-Path`, `-KeepOpen`, `-PassThru`, `-Force`) |

`Add-VellumPdfHeading -BookmarkTitle`/`-Level` builds the PDF outline (bookmarks).
Dangerous `-LinkUri` schemes (`javascript:`, `file:`, …) are rejected, and the
cmdlets fail fast on stale (already-saved) documents and cross-document font
handles.

### Scope and limitations

PSVellumPDF writes PDFs; it has no reader. Reading text or metadata from an
existing PDF, editing one in place, and splitting or merging files are out of
scope, because VellumPdf provides no parser to build them on.

A few VellumPdf features stay unwrapped because they need low-level kernel
`PdfPage` references that the layout `Document` does not expose: AcroForm
interactive form fields, outline expand/collapse state
(`PdfOutlineEntry.IsExpanded`), internal go-to links, and standalone outline
entries. Bookmarks still come from heading `-BookmarkTitle`/`-Level`, and
external links from `-LinkUri`.

`Get-Help <function> -Full` documents each one. A generated markdown reference
lives in [docs/PSVellumPDF](https://github.com/Tim81/PSVellumPDF/tree/main/docs/PSVellumPDF),
and runnable demo scripts in the Examples section below.

### Embedded fonts (Unicode / PDF&#8203;/A)

The base-14 fonts cover only Latin-1: text containing characters beyond it
(e.g. Czech diacritics, CJK, the euro sign) renders **mangled** with those
fonts — the cmdlets emit a warning when this is about to happen. The fix, which
also satisfies PDF/A's embedding requirement, is a TrueType font:

```powershell
$doc    = New-VellumPdfDocument -Conformance PdfA2b
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfParagraph -Text 'Unicode: héllo wörld €' -FontHandle $handle |
       Save-VellumPdfDocument -Path ./unicode.pdf
```

## Cookbook

Each snippet is a complete, runnable pipeline. Requires `./build.ps1 Restore` first.

### Coloured heading

```powershell
New-VellumPdfDocument |
    Add-VellumPdfHeading -Text 'Warning' -Level 1 -Color 'crimson' |
    Save-VellumPdfDocument -Path ./warning.pdf
```

`-Color` accepts an RGB triple (`1.0, 0.0, 0.0`), a hex string (`#dc143c`), or a
named colour. The palette includes standard CSS/X11 names: `darkblue`, `steelblue`,
`forestgreen`, `crimson`, `coral`, `gold`, `indigo`, `turquoise`, and ~30 more.

### Embedded-font table (Unicode / PDF/A)

The headline 1.4.0 addition: `-FontHandle` now works on `Add-VellumPdfTable`.
Before this, a PDF/A document could not contain a styled table, because the base-14
fonts cannot be embedded.

```powershell
$doc  = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
$font = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf

$doc |
    Add-VellumPdfHeading -Text 'Sales' -Level 1 -FontHandle $font |
    Add-VellumPdfTable `
        -Header 'Region', 'Units' `
        -Row @([object[]]@('EMEA', '2,318')), @([object[]]@('North', '1,204')) `
        -FontHandle $font -CellPadding 5 -ColumnWidth 160, 100 -BorderWidth 0.5 |
    Save-VellumPdfDocument -Path ./sales.pdf
```

### Rich header cells with per-cell Padding and Color

```powershell
$header = @(
    @{ Text = 'Region'; Background = 'steelblue'; Color = 'white'; Padding = 6, 10, 6, 10 },
    @{ Text = 'Units';  Background = 'steelblue'; Color = 'white'; Padding = 6, 10, 6, 10 }
)
New-VellumPdfDocument |
    Add-VellumPdfTable -Header $header `
        -Row @([object[]]@('EMEA', '2,318')) `
        -ColumnWidth 160, 100 -BorderWidth 0.5 |
    Save-VellumPdfDocument -Path ./rich-header.pdf
```

### Embedded-font list with -Language

```powershell
$doc  = New-VellumPdfDocument -Language 'en-US'
$font = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc |
    Add-VellumPdfList -Item 'Alpha', 'Beta', 'Gamma' `
        -FontHandle $font -Language 'en-US' |
    Save-VellumPdfDocument -Path ./list.pdf
```

### Custom mm page size

```powershell
New-VellumPdfDocument -PageWidthMm 148 -PageHeightMm 210 |
    Add-VellumPdfParagraph -Text 'A5 page.' |
    Save-VellumPdfDocument -Path ./a5.pdf
```

`-PageWidthMm` and `-PageHeightMm` are supplied together and are mutually exclusive
with `-PageSize`.

### PDF/UA-1 (accessible) document

```powershell
$doc  = New-VellumPdfDocument -Conformance PdfUA1 -Tagged -Language 'en-US'
$font = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc |
    Add-VellumPdfHeading -Text 'Accessible Report' -Level 1 `
        -FontHandle $font -Language 'en-US' |
    Add-VellumPdfParagraph -Text 'Body text.' -FontHandle $font -Language 'en-US' |
    Save-VellumPdfDocument -Path ./accessible.pdf
```

PDF/UA-1 requires embedded fonts and `-Tagged`. The document language set on
`New-VellumPdfDocument` covers the whole document; `-Language` on individual
elements overrides it for that element.

### Save -PassThru and -Force

`-PassThru` returns the live `Document` instead of a `FileInfo`. The document stays
open; the caller is responsible for disposing it.

```powershell
$doc = New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Hello.' |
    Save-VellumPdfDocument -Path ./out/sub/hello.pdf -Force -PassThru
# Do more work with $doc here, then:
$doc.Dispose()
```

`-Force` creates a missing parent directory (`./out/sub/` in the example) instead
of failing.

## Examples

Runnable scripts in [`examples/`](https://github.com/Tim81/PSVellumPDF/tree/main/examples):

- [01-quarterly-report.ps1](https://github.com/Tim81/PSVellumPDF/blob/main/examples/01-quarterly-report.ps1) — headings with bookmarks, justified body text, a table, a list, headers/footers with page numbers
- [02-pdfa-archival.ps1](https://github.com/Tim81/PSVellumPDF/blob/main/examples/02-pdfa-archival.ps1) — PDF/A-2b with an embedded TrueType font and Unicode text
- [03-rich-text-and-encryption.ps1](https://github.com/Tim81/PSVellumPDF/blob/main/examples/03-rich-text-and-encryption.ps1) — mixed-style text runs, colour, hyperlinks, and AES encryption
- [04-digital-signing.ps1](https://github.com/Tim81/PSVellumPDF/blob/main/examples/04-digital-signing.ps1) — PAdES digital signature with an RFC-3161 timestamp
- [05-accessible-tables-and-fonts.ps1](https://github.com/Tim81/PSVellumPDF/blob/main/examples/05-accessible-tables-and-fonts.ps1) — embedded-font table, rich header cells, per-cell Padding/Color, coloured heading, embedded-font list with -Language, custom mm page, Save -PassThru

Each script writes its output PDF beside itself and prints the path.

## Development

```powershell
./build.ps1 Lint    # PSScriptAnalyzer gate
./build.ps1 Test    # restore (if needed) + run Pester with coverage
./build.ps1 Docs    # regenerate docs/ from comment-based help (PlatyPS)
./build.ps1 Clean   # remove ./lib and build output
```

See [CONTRIBUTING.md](https://github.com/Tim81/PSVellumPDF/blob/main/CONTRIBUTING.md) for architecture and contribution conventions.

## License

Apache-2.0, matching the upstream VellumPdf library.
