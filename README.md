# PSVellumPDF

[![CI](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml/badge.svg)](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSVellumPDF)](https://www.powershellgallery.com/packages/PSVellumPDF)

PowerShell module for creating, checking and reading PDF files on Windows,
Linux, and macOS, built on the [VellumPdf](https://github.com/Tim81/VellumPDF)
.NET 10 library: a zero-dependency PDF engine with PDF/A and PDF/UA
conformance, tagged accessible output, digital signatures and barcodes.

> Status: **2.0.0**, on VellumPdf 2.3.3. See the [CHANGELOG](CHANGELOG.md) for
> release history and the [upgrade notes](#upgrading-from-1x). PDF/A-2b and
> PDF/UA-1 output is validated with veraPDF in CI, and in-process by
> `Test-VellumPdfConformance`.

What it does:

- **Flowing documents**: headings with bookmarks, paragraphs and mixed-style
  runs, lists, tables (merged and styled cells, embedded fonts), images, pie
  charts, barcodes and 2-D codes, free-form vector drawing, running headers and
  footers.
- **Page-based documents**: place text, shapes, gradients, images and barcodes
  by coordinate; fillable form fields; links between pages; collapsible
  bookmarks; rotated pages; linearized ("fast web view") and byte-for-byte
  reproducible files.
- **Standards and security**: PDF/A-2b/2u/2a, PDF/UA-1, AES encryption, PAdES
  signatures from B-B to B-LTA with timestamps, long-term validation and
  external (HSM / cloud KMS) signers.
- **Checking and reading**: in-process PDF/A and PDF/UA preflight, and
  experimental cmdlets that read page counts, text, images and signatures from
  existing PDFs. It cannot edit, split or merge existing files.

## Requirements

- **PowerShell 7.6+** (runs on .NET 10)
- **.NET 10 SDK** - needed only to restore the VellumPdf assemblies when
  building from source

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

Two kinds of document, one verb vocabulary. **Flow documents** lay text out and
paginate for you; **page documents** put things where you say.

```powershell
# A flowing, archival document
$doc  = New-VellumPdfDocument -Conformance PdfA2b -Language en-US
$font = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf   # PDF/A needs embedded fonts
$doc |
    Set-VellumPdfDocumentInfo -Title 'Quarterly Report' |
    Add-VellumPdfHeading   -Text 'Quarterly Report' -FontHandle $font |
    Add-VellumPdfParagraph -Text 'Generated with PSVellumPDF.' -FontHandle $font -Alignment Justify |
    Add-VellumPdfPieChart  -Legend -FontHandle $font -AltText 'Regional share' -Slice @(
        @{ Value = 60; Label = 'North' }, @{ Value = 40; Label = 'South' }) |
    Save-VellumPdfDocument -Path ./report.pdf -Validate      # refuses to write a non-compliant file

# A page-based document: everything by coordinate (points, origin bottom-left)
New-VellumPdfPageDocument -Language en-US |
    Add-VellumPdfPage |
    Add-VellumPdfText 'Hello' -X 72 -Y 740 -FontSize 24 |
    Add-VellumPdfFormField Text -Name email -X 72 -Y 690 -Width 240 -Height 22 |
    Save-VellumPdfDocument -Path ./form.pdf

Test-VellumPdfConformance ./report.pdf            # in-process PDF/A / PDF/UA preflight
```

### Flow documents

| Function | Purpose |
|---|---|
| `New-VellumPdfDocument` | Create a document: `-Conformance` (None, PdfA2b/2u/2a, PdfUA1), `-PageSize` or `-PageWidthMm`/`-PageHeightMm`, `-DefaultFont`, `-Tagged`, `-Language`, margins, `-UseObjectStreams` |
| `Add-VellumPdfHeading` | Heading with outline bookmark: `-Level`, `-Color`, `-Leading`, `-Language`, `-FontHandle` |
| `Add-VellumPdfParagraph` | Body text or mixed-style runs: `-Font`, `-FontHandle`, `-Color`, `-LinkUri`, `-Leading`, `-Language`, `-Alignment` |
| `New-VellumPdfTextRun` | A styled run for `-Run` paragraphs |
| `Add-VellumPdfTable` | Tables from arrays, `Import-Csv` records or rich cells: spans, padding, per-cell fonts, rich headers, `-FontHandle`, zebra rows |
| `Add-VellumPdfList` | Ordered/unordered lists with one nesting level and per-item styles: `-FontHandle`, `-Color`, `-Language` |
| `Add-VellumPdfImage` | JPEG, PNG, BMP, GIF, TIFF, JBIG2, JPEG 2000 or raw CCITT from a file or memory; `-ReduceToEightBit`, `-DecodeToRaster`, margins |
| `Add-VellumPdfPieChart` | Pie chart from slices or pipeline data, with palette, legend and alternate text |
| `Add-VellumPdfBarcode` | QR, Micro QR, Data Matrix, Aztec, PDF417, Code 128/39, EAN/UPC, ITF-14; GS1; Structured Append; validated when added |
| `Add-VellumPdfDrawing` | Reserve a block and draw into it with a script block that receives the canvas |
| `Add-VellumPdfElement` | Add any custom `IRenderer` |
| `Add-VellumPdfLineSeparator` | Horizontal rule |
| `Set-VellumPdfHeader` / `Set-VellumPdfFooter` | Running bands with `{page}`/`{pages}`: `-Color`, `-FontHandle`, `-Height` |

### Page documents

| Function | Purpose |
|---|---|
| `New-VellumPdfPageDocument` | Create one: `-Conformance` (None, PdfA2b/2u), page size, `-Linearize`, `-DocumentId`/`-Timestamp` for reproducible output |
| `Add-VellumPdfPage` | Add pages: size, `-Rotate`, `-Count` |
| `Add-VellumPdfShape` / `-Text` / `-Gradient` / `-PageImage` / `-PageBarcode` | Draw at x/y (RGB or CMYK colour, dashes, opacity, alignment) |
| `Invoke-VellumPdfCanvas` | Full canvas access from a script block |
| `Add-VellumPdfFormField` | Text, check box, choice, radio group and push button fields |
| `Add-VellumPdfLink` | Link a rectangle to a URL or another page |
| `Add-VellumPdfOutlineEntry` | Nested bookmarks, optionally collapsed |

### Both kinds of document

| Function | Purpose |
|---|---|
| `Register-VellumPdfFont` | Load a TrueType font for embedding; returns a handle for `-FontHandle` |
| `Set-VellumPdfDocumentInfo` | Title, author, subject, keywords |
| `Set-VellumPdfOutputIntent` | Replace the default sRGB PDF/A output intent (`-IccProfilePath` or `-Cmyk`) |
| `Protect-VellumPdfDocument` | AES password protection with permissions |
| `Set-VellumPdfSignature` | PAdES signature: `-Level` B-B/B-T/B-LT/B-LTA, `-TimestampUrl`, `-RevocationClient`, `-SignaturePage`, `-ExternalPrivateKey`, `-ExternalSigner` |
| `Save-VellumPdfDocument` | Write the file (`-Path`, `-Stream` or `-AsByteArray`), signing it if staged; `-Validate`, `-PassThru`, `-Force`, `-KeepOpen`. A document can be saved once |

### Check and read existing PDFs

| Function | Purpose |
|---|---|
| `Test-VellumPdfConformance` | Validate any PDF against PDF/A-2b/2u/2a or PDF/UA-1, in-process; every finding with rule, clause and message |
| `Get-VellumPdfInfo` | *(experimental)* Pages, encryption, signatures, claimed profiles, diagnostics |
| `Get-VellumPdfText` | *(experimental)* Text of a document or of chosen pages |
| `Export-VellumPdfImage` | *(experimental)* Save embedded images (PNG, or the original JPEG/JPEG 2000/JBIG2/CCITT) |
| `Unprotect-VellumPdfDocument` | *(experimental)* Write a decrypted copy of a password-protected PDF |

`Get-Help <function> -Full` documents each one. A generated markdown reference
lives in [docs/PSVellumPDF](docs/PSVellumPDF), and runnable demo scripts in
[examples/](examples): a report with tables and page numbers, PDF/A archival,
rich text and encryption, digital signing, an accessible PDF/UA report, charts
and barcodes and drawing, a form with links and pages, and preflight/reader/
signing.

### Scope and limitations

- The reading cmdlets sit on VellumPdf.Reader, which is still a preview
  package: its text extraction handles simple fonts only and inserts no spaces
  between positioned runs, and it does not verify signatures. Editing,
  splitting and merging existing PDFs are out of scope.
- Flow documents render list nesting one level deep, and `-LinkUri` links are
  not tagged (a PDF/UA document containing one is not fully conformant).
  Headings, lists and table cells have no link support (a link key in a table
  cell is refused rather than silently dropped).
- Page documents write untagged content, so PDF/UA-1 and PDF/A-2a are flow-
  document levels. Form fields use the non-embedded Helvetica font, so PDF/A
  page documents cannot contain them.
- CMYK colour is available in page documents and drawings; flow-layout
  elements take RGB. A PDF/A document using CMYK needs
  `Set-VellumPdfOutputIntent -Cmyk`.
- `Test-VellumPdfConformance` covers the checks decidable in-process; it does
  not examine fonts used only by form fields. Use veraPDF for a formal
  compliance statement.
- `Add-VellumPdfDrawing` script blocks run during the save on the PowerShell
  thread: they cannot be combined with an asynchronous signer
  (`-ExternalSigner`).

### Embedded fonts (Unicode / PDF&#8203;/A / PDF&#8203;/UA)

The base-14 fonts cover only Windows-1252 (Latin-1 plus the euro sign, curly
quotes, bullets and dashes): text containing characters beyond it
(e.g. Czech diacritics, CJK, emoji) renders **mangled** with those fonts - the
cmdlets warn when this is about to happen, and `Save-VellumPdfDocument` lists
what the engine actually replaced (also on the returned object's
`TextEncodingWarnings`). The fix, which also satisfies the PDF/A and PDF/UA
embedding requirement, is a TrueType font:

```powershell
$doc    = New-VellumPdfDocument -Conformance PdfA2b
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfParagraph -Text 'Unicode: héllo wörld €' -FontHandle $handle |
       Save-VellumPdfDocument -Path ./unicode.pdf
```

## Upgrading from 1.x

Existing scripts keep working, apart from these changes (details in the
[CHANGELOG](CHANGELOG.md)):

- **Heading levels**: `-Level 1` is now tagged `H1`. It was `H2`, because the
  engine counts levels from zero. Outlines and tag trees shift accordingly.
- **`-MarginBottom`** on paragraphs, headings, lists and tables now adds space
  before the next element. It did nothing before.
- **Lists** deeper than one nesting level are refused with an error instead of
  silently dropping the inner items.
- **Saving**: a document can be saved once. A second `Save-VellumPdfDocument`,
  or one after a failed save, is refused. Build a new document.
- **Encoding warnings** follow Windows-1252: `€ – — “ ”` no longer warn,
  because the engine now renders them.
- **Encryption**: an empty `-OwnerPassword` next to a user password and
  encryption with `-UseObjectStreams` are refused; PDF/UA-1 documents may be
  encrypted if `-Permission` includes `Extract`. Encrypted files differ at the
  byte level (`/P` permission bits), and `-EncryptMetadata:$false` now really
  leaves the metadata readable.
- **Signing**: PAdES signatures no longer carry a CMS `signing-time`
  attribute (the claimed time is in the signature dictionary).
- **Layout**: text is measured with Windows-1252 widths, tables no longer
  double their margin, and over-long header/footer text is cut at a word
  boundary (reported when saving).
- **Installation**: the module now loads eight assemblies, including
  `VellumPdf.Reader` and a small `PSVellumPDF.Interop`. Run
  `./build.ps1 Restore` after pulling; a stale `lib/` is detected and
  explained at import.

## Development

```powershell
./build.ps1 Lint    # PSScriptAnalyzer gate
./build.ps1 Test    # restore (if needed) + run Pester with coverage
./build.ps1 Docs    # regenerate docs/ from comment-based help (PlatyPS)
./build.ps1 Clean   # remove ./lib and build output
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions. `tools/Get-VellumPdfApiSurface.py` diffs the public API of two VellumPdf releases when planning an engine upgrade, and `docs/plans/` holds the design notes behind each major version.

## License

Apache-2.0, matching the upstream VellumPdf library.
