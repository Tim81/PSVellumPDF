# PSVellumPDF

[![CI](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml/badge.svg)](https://github.com/Tim81/PSVellumPDF/actions/workflows/ci.yml)

PowerShell module for generating PDFs with the
[VellumPdf](https://github.com/Tim81/VellumPDF) .NET 10 library — a modern,
zero-dependency PDF engine with PDF/A archival support.

> Status: early scaffold (v0.1.0). Document creation, headings, paragraphs, and
> save are wrapped; tables, lists, images, fonts, and signing are not yet.

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
| `Add-VellumPdfHeading` | Add a heading (`-Text`, `-Level`, `-Font`, `-FontSize`, `-Alignment`, `-BookmarkTitle`) |
| `Add-VellumPdfParagraph` | Add body text (`-Text`, `-Font`, `-FontSize`, `-Alignment`) |
| `Save-VellumPdfDocument` | Write the `.pdf` and dispose the document (`-Path`, `-KeepOpen`) |

`Get-Help <function> -Full` documents each one.

## Development

```powershell
./build.ps1 Test    # restore (if needed) + run Pester
./build.ps1 Clean   # remove ./lib and build output
```

See [CLAUDE.md](CLAUDE.md) for architecture and contribution conventions.

## License

Apache-2.0, matching the upstream VellumPdf library.
