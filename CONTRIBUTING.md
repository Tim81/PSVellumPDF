# Contributing to PSVellumPDF

## Prerequisites

- PowerShell 7.6+ (the module runs on .NET 10)
- .NET 10 SDK (only to restore the VellumPdf assemblies)

## Workflow

```powershell
./build.ps1 Restore   # fetch VellumPdf DLLs into ./lib (locked NuGet restore)
./build.ps1 Lint      # PSScriptAnalyzer gate - must be clean
./build.ps1 Test      # Pester with code coverage - must pass, >= 70%
./build.ps1 Docs      # regenerate docs/ after changing comment-based help
./build.ps1 Stage     # assemble the publishable layout in out/ (release dry-runs)
```

CI runs Restore + Lint + Test on Windows, Linux, and macOS for every push and
pull request, plus conformance validation (qpdf, veraPDF) of generated samples.

## Rules that keep this module correct

1. **Reflect before you wrap.** Never assume a VellumPdf type or member exists.
   Load `./lib/*.dll` with `Add-Type` and inspect constructors/members first.
   Namespaces are split across `VellumPdf.Kernel` and `VellumPdf.Layout` in
   non-obvious ways.
2. **A `TextStyle` without a font renders in the library-global Helvetica**,
   not the document default. Fill style gaps from `Resolve-VellumPdfDefault`
   (the stash written by `New-VellumPdfDocument`), never hardcode a font.
3. **Tests must produce real PDFs.** Assert on actual file bytes - at minimum
   the `%PDF-` header; assert `/BaseFont`, `/Encrypt`, `/Outlines`, etc. when
   the behaviour under test is about them. "It didn't throw" is not a test.
4. **One function per file** under `Public/` (exported; add to
   `FunctionsToExport` in the manifest) or `Private/` (helpers). Pipeline
   cmdlets take `-Document` via `ValueFromPipeline` and return it.
5. **ASCII only in `.ps1` files** (the lint gate rejects non-ASCII without a
   BOM). No `Write-Host` in module code - the lint gate enforces this.
6. **Update CHANGELOG.md** (Unreleased section) with user-visible changes.

## Releasing (maintainer)

Bump `ModuleVersion` in `PSVellumPDF.psd1` (and `PrivateData.PSData.Prerelease`
for rc tags - SemVer 1.0.0 format, e.g. `rc1` not `rc.1`), update the
VellumPdf `PackageReference` + `dependencies/packages.lock.json` if upstream
moved, move CHANGELOG Unreleased notes under the new version, then
`gh release create v<version>`. The release workflow validates the tag against
the manifest and publishes via `Publish-PSResource`.

## Code signing

The module is **not Authenticode-signed** for 1.0. The PowerShell Gallery does
not require signing, and the project has no code-signing certificate. If a
certificate is acquired later: sign `*.ps1`/`*.psd1`/`*.psm1` with
`Set-AuthenticodeSignature` (plus a catalog via `New-FileCatalog`) in the
release workflow before `Publish-PSResource`, and drop `-SkipPublisherCheck`
guidance from the docs.
