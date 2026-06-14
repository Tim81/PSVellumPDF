@{
    RootModule        = 'PSVellumPDF.psm1'
    ModuleVersion     = '1.3.1'
    GUID              = 'e51842c7-ddb1-4700-8ade-77055baa4f3a'
    Author            = 'Timothy van der Ham (@Tim81)'
    Copyright         = '© Timothy van der Ham. Licensed under Apache-2.0.'
    Description       = @'
Create PDF files from PowerShell on Windows, Linux, and macOS. PSVellumPDF wraps the VellumPdf .NET 10 engine; you build a document with one pipeline and save it:

  New-VellumPdfDocument | Add-VellumPdf... | Save-VellumPdfDocument

Add headings with outline bookmarks, paragraphs, mixed-style text runs, ordered and unordered lists, tables, line separators, and running headers and footers that resolve {page}/{pages}. Text carries per-run colour, hyperlinks, alignment, and line spacing; tables take header rows, column widths, borders, and header backgrounds. Embed images in JPEG, PNG, BMP, GIF, TIFF, JBIG2, or JPEG 2000.

Set the page size (A0-A6, Letter, Legal, Ledger), margins, and document info. Use any of the 14 standard PDF fonts, or embed a TrueType font for full Unicode, which PDF/A also requires. Tagged structure, a /Lang language tag, and per-image alt text produce accessible output.

For archives, emit PDF/A-2b, 2u, or 2a with an output intent from the default sRGB profile, a custom ICC profile, or generic CMYK. To protect a file, apply AES encryption with user and owner passwords and permission flags, or add a PAdES digital signature, optionally with an RFC-3161 timestamp (PAdES B-T).

PSVellumPDF only writes new PDFs. It cannot read, edit, split, or merge an existing file: VellumPdf is a generation engine with no parser.
'@

    # VellumPdf targets .NET 10; PowerShell 7.6 is the first release on .NET 10.
    PowerShellVersion       = '7.6'
    CompatiblePSEditions    = @('Core')

    # Assemblies are loaded explicitly by the .psm1 (with a friendly error when
    # ./lib is missing), so they are intentionally NOT listed in RequiredAssemblies.

    FunctionsToExport = @(
        'New-VellumPdfDocument'
        'New-VellumPdfTextRun'
        'Add-VellumPdfHeading'
        'Add-VellumPdfImage'
        'Add-VellumPdfLineSeparator'
        'Add-VellumPdfList'
        'Add-VellumPdfParagraph'
        'Add-VellumPdfTable'
        'Register-VellumPdfFont'
        'Save-VellumPdfDocument'
        'Set-VellumPdfHeader'
        'Set-VellumPdfFooter'
        'Set-VellumPdfDocumentInfo'
        'Set-VellumPdfOutputIntent'
        'Set-VellumPdfSignature'
        'Protect-VellumPdfDocument'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @(
                'PDF', 'VellumPdf', 'PDFA', 'Accessibility', 'Document', 'Reporting',
                'Create', 'Generate', 'Signing', 'PAdES', 'CrossPlatform',
                'PSEdition_Core', 'Windows', 'Linux', 'MacOS'
            )
            LicenseUri   = 'https://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/Tim81/PSVellumPDF'
            ReleaseNotes = '1.3.1: hardening of the 1.3.0 features. Rich table cells now validate Font/FontSize/ColSpan/RowSpan (a bad value used to fail cryptically or silently); a colour-only cell keeps the table font instead of falling back to Helvetica. Hex colours now require a leading # (so a bare number like 255 is no longer misread as hex). Add-VellumPdfTable fails fast when rows mix record and cell-array shapes. -LinkUri is stored with embedded whitespace/control characters removed. Nested lists cap their depth to avoid an overflow on cyclic input. Full changelog: https://github.com/Tim81/PSVellumPDF/blob/main/CHANGELOG.md'
        }
    }
}
