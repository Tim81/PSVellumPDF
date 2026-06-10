# PSVellumPDF

[![CI](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml/badge.svg)](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml)

PowerShell module for generating PDFs with the
[VellumPdf](https://github.com/Tim81/VellumPDF) .NET 10 library — a modern,
zero-dependency PDF engine with PDF/A archival support.

> Status: in development (v0.1.0). Documents, headings, paragraphs, tables,
> lists, images, and embedded TrueType fonts are wrapped. Still to come on the
> [road to 1.0](https://github.com/Tim81/PSVellumPDF/issues/16): headers/footers,
> metadata, rich text, outline/links, encryption, and digital signing.

## Requirements

- **PowerShell 7.6+** (runs on .NET 10)
- **.NET 10 SDK** — needed only to restore the VellumPdf assemblies

## Getting started

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
| `New-VellumPdfDocument` | Create a document (`-Conformance`, `-PageSize`, `-DefaultFont`, `-DefaultFontSize`, `-Tagged`) |
| `Add-VellumPdfHeading` | Add a heading (`-Text`, `-Level`, `-Font`, `-FontSize`, `-Alignment`, `-BookmarkTitle`, `-FontHandle`) |
| `Add-VellumPdfParagraph` | Add body text (`-Text`, `-Font`, `-FontSize`, `-Alignment`, `-FontHandle`) |
| `Add-VellumPdfTable` | Add a table (`-Header`, `-Row`, `-ColumnWidth`, `-BorderWidth`, `-BorderColor`, `-HeaderBackground`, `-Font`, `-FontSize`, `-Alignment`) |
| `Add-VellumPdfList` | Add an ordered/unordered list (`-Item`, `-Style`, `-Indent`, `-Font`, `-FontSize`) |
| `Add-VellumPdfImage` | Embed an image (`-Path`, `-Width`, `-Height`, `-Alignment`, `-AltText`) |
| `Register-VellumPdfFont` | Load a TrueType font for embedding; returns a handle for `-FontHandle` |
| `Save-VellumPdfDocument` | Write the `.pdf` and dispose the document (`-Path`, `-KeepOpen`) |

`Get-Help <function> -Full` documents each one.

### Embedded fonts (Unicode / PDF&#8203;/A)

The base-14 fonts can't be embedded, so Unicode text and PDF/A documents need a
TrueType font:

```powershell
$doc    = New-VellumPdfDocument -Conformance PdfA2b
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfParagraph -Text 'Unicode: héllo wörld €' -FontHandle $handle |
       Save-VellumPdfDocument -Path ./unicode.pdf
```

## Development

```powershell
./build.ps1 Test    # restore (if needed) + run Pester
./build.ps1 Clean   # remove ./lib and build output
```

See [CLAUDE.md](CLAUDE.md) for architecture and contribution conventions.

## License

Apache-2.0, matching the upstream VellumPdf library.
