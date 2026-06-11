# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PSVellumPDF is a **PowerShell 7.6 script module** that wraps the
[VellumPdf](https://github.com/Tim81/VellumPDF) .NET 10 PDF library (NuGet:
`VellumPdf.Layout` / `VellumPdf.Kernel`). It exposes cmdlet-style functions that
build and save PDFs by driving VellumPdf's high-level `Document` layout API.
Upstream library work lives in the VellumPDF repo; this repo is only the
PowerShell wrapper and syncs to https://github.com/Tim81/PSVellumPDF.

PowerShell 7.6 is required because VellumPdf targets .NET 10 and 7.6 is the first
PowerShell release on .NET 10. The .NET 10 SDK is required only to *restore* the
assemblies, not at runtime.

## Commands

```powershell
./build.ps1 Restore   # publish dependencies/ and copy VellumPdf*.dll into ./lib (run after clone)
./build.ps1 Test      # Restore if needed, then run Pester
./build.ps1 Clean     # remove ./lib and dependencies build output

# Import the module for manual use (lib/ must be populated first):
Import-Module ./PSVellumPDF.psd1 -Force

# Run a single test by name:
Invoke-Pester -Path ./tests/PSVellumPDF.Tests.ps1 -FullNameFilter '*PDF/A-2b*'
```

`./lib/` is generated and git-ignored — a fresh clone has no assemblies until
`./build.ps1 Restore` runs. Importing the module before that throws a message
pointing at the restore step (see `PSVellumPDF.psm1`).

## Architecture

The module is a thin, idiomatic PowerShell skin over VellumPdf — it owns no PDF
logic of its own.

- **Assembly acquisition is decoupled from the module.** `dependencies/Dependencies.csproj`
  exists only to pull the VellumPdf NuGet packages; `build.ps1` `dotnet publish`es
  it and copies `VellumPdf*.dll` into `./lib`. The module never references the
  `.csproj` at runtime. To bump the library version, edit the `PackageReference`
  version and re-run `./build.ps1 Restore`.
- **`PSVellumPDF.psm1` is the loader.** At import it `Add-Type`s the two DLLs from
  `./lib`, then dot-sources every `*.ps1` under `Private/` then `Public/`, and
  exports only the `Public/` function names. One function per file; the file's
  basename is the function name.
- **The pipeline model is fluent.** `New-VellumPdfDocument` returns a live
  `VellumPdf.Layout.Document`; each `Add-VellumPdf*` takes the document
  `ValueFromPipeline`, mutates it, and re-emits it; `Save-VellumPdfDocument` is
  the terminal step that writes the file and disposes the document. So the
  canonical usage is one pipeline:
  ```powershell
  New-VellumPdfDocument -Conformance PdfA2b |
      Add-VellumPdfHeading -Text 'Report' -Level 1 |
      Add-VellumPdfParagraph -Text 'Body.' -Alignment Justify |
      Save-VellumPdfDocument -Path ./report.pdf
  ```
- **`Document` is IDisposable.** Only `Save-VellumPdfDocument` disposes it (unless
  `-KeepOpen`). Any code path that creates a document but does not save it must
  call `$doc.Dispose()`.
- **`Private/New-VellumTextStyle.ps1`** centralizes font/size → `TextStyle`
  construction so the public functions stay consistent.

### Mapping to the VellumPdf API

Wrappers call these real types (namespaces matter — they are not all `VellumPdf.Layout`):

| Wrapper | VellumPdf type / call |
|---|---|
| `New-VellumPdfDocument` | `VellumPdf.Layout.Document`, `.Conformance` (`VellumPdf.Document.PdfConformance`), `.PageSize` (`VellumPdf.Document.PageSize::A4` etc.), `.SetDefaultFont(TextStyle)` |
| `Add-VellumPdfHeading` | `VellumPdf.Layout.Elements.Heading(text, style)`, `.Add(heading)` |
| `Add-VellumPdfParagraph` | `VellumPdf.Layout.Elements.Paragraph(text, style)` or `.Add(text, style)` for the default font |
| `Add-VellumPdfTable` | `VellumPdf.Layout.Elements.Table.TableElement` (`AddHeaderRow`/`AddRow`/`AddCell`/`SetColumnWidths`), `.Add(table)` |
| `Add-VellumPdfList` | `VellumPdf.Layout.Elements.ListElement(ListStyle, items)`, `.Add(text, style)`, `.Add(list)` |
| `Add-VellumPdfImage` | `VellumPdf.Images.*ImageLoader::Load(byte[])` (static) → `LayoutImage`, `.Add(image)` |
| `Register-VellumPdfFont` | `Document.LoadTrueTypeFont(path)` → `EmbeddedFontHandle` |
| `New-VellumPdfTextRun` | `VellumPdf.Layout.Elements.TextRun(text, style)` — style must be non-null (renderer NREs on null-style runs) |
| `Set-VellumPdfHeader`/`Footer` | `Document.SetHeader/SetFooter(template, style, alignment)`; `{page}`/`{pages}` tokens resolved by `RunningBand.Resolve` |
| `Set-VellumPdfDocumentInfo` | `Document.Info` (`PdfDocumentInfo` props) |
| `Protect-VellumPdfDocument` | `Document.Encrypt(PdfEncryptionSettings)`; `PdfPermissions` flags; PDF/A + encryption is rejected (fail-fast in the cmdlet; the library only throws at `Save`) |
| `Set-VellumPdfSignature` | stages a `VellumPdf.Signing.PdfSignatureSettings` as ETS note property `PSVellumSignature`; `Save-VellumPdfDocument` then calls `VellumPdf.Signing.SigningExtensions::Sign(doc, stream, settings)` instead of `Save` — signing IS the write step. PAdES `ETSI.CAdES.detached`; composes with PDF/A; mutually exclusive with encryption (fail-fast in both cmdlets) |
| `Set-VellumPdfOutputIntent` | `Document.SetPdfAOutputIntent(byte[], int, string, string)` / `UseCmykOutputIntent(string)`; PDF/A only — the library silently ignores the intent on non-conformant docs, so the cmdlet fails fast |
| text styling | `VellumPdf.Layout.Core.TextStyle` (`.Font` = `VellumPdf.Fonts.Standard14::Helvetica` …, `.FontSize`, or `.FontRef` = `FontReference(EmbeddedFontHandle)` for embedded fonts) |
| alignment | `VellumPdf.Layout.Core.HorizontalAlignment` (Left/Center/Right/Justify) |

The full layout API is now wrapped. Not wrapped (and not wrappable at the layout
level): internal go-to links and standalone outline entries — `PdfLinkAnnotation`/
`PdfOutlineEntry` need kernel `PdfPage` refs that the layout `Document` does not
expose; outlines come from heading `-BookmarkTitle`/`-Level`, external links from
`-LinkUri`. PAdES signing (`VellumPdf.Signing`, wrapped since 1.1.0) depends on
`System.Security.Cryptography.Pkcs`, which resolves from `$PSHOME` (PowerShell
ships it for its CMS cmdlets) — it is intentionally not copied into `./lib`.

Embedded fonts: `Register-VellumPdfFont` returns an `EmbeddedFontHandle`; pass it
to `Add-VellumPdfHeading`/`Add-VellumPdfParagraph` via `-FontHandle`. Required for
Unicode text and PDF/A (the base-14 fonts can't be embedded). The test suite
vendors `tests/assets/DejaVuSans.ttf` for this.

## Conventions for extending the module

- **Verify the API by reflection before writing a wrapper — do not guess type
  names or members.** Namespaces are split across `VellumPdf.Kernel` and
  `VellumPdf.Layout` in non-obvious ways. After `./build.ps1 Restore`:
  ```powershell
  Add-Type -Path ./lib/VellumPdf.Kernel.dll; Add-Type -Path ./lib/VellumPdf.Layout.dll
  [VellumPdf.Layout.Document].GetMethods('Public,Instance,DeclaredOnly') |
      Where-Object { -not $_.IsSpecialName }
  ```
- Add a new exported function as one file in `Public/`; the loader and the
  manifest's `FunctionsToExport` both need it — update `PSVellumPDF.psd1`.
- Mirror the existing `ValidateSet` lists (font names, page sizes, conformance,
  alignment) so callers get tab-completion and early validation.
- Every change should keep the Pester smoke test green; it asserts the output
  begins with the `%PDF-` magic bytes, which is the cheapest real proof the
  wrapper produced a valid file.

## Roadmap

**1.1.0 is published on the PowerShell Gallery** (built on VellumPdf 1.2.0):
PAdES digital signing (#24, `Set-VellumPdfSignature`) and custom PDF/A output
intents (`Set-VellumPdfOutputIntent`, from the 1.2.0 ICC colour work in #27).
The milestone epic is
[#29 "Epic: v1.1.0 — signing, conformance, barcodes"](https://github.com/Tim81/PSVellumPDF/issues/29);
still open in it: conformance-validator (#25) and barcodes (#26), both gated on
upstream packages that have not shipped, further engine-capability adoption as
upstream releases land (#27 — linearization, new image codecs remain), plus 1.x
maintenance (#28 — note the PSGallery API key expires mid-2027).

User-visible changes belong in `CHANGELOG.md` (Unreleased section); releases
move them under the version heading and feed the manifest ReleaseNotes. See
`CONTRIBUTING.md` for the full workflow and module-specific rules.

## Repo-specific git conventions

- Module author metadata is **Timothy van der Ham (@Tim81)**; there is no
  CompanyName.
- **Do not mention Claude or add a `Co-Authored-By: Claude` trailer** in commits
  or PRs for this repo.
