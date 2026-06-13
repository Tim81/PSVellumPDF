@{
    RootModule        = 'PSVellumPDF.psm1'
    ModuleVersion     = '1.2.0'
    GUID              = 'e51842c7-ddb1-4700-8ade-77055baa4f3a'
    Author            = 'Timothy van der Ham (@Tim81)'
    Copyright         = '© Timothy van der Ham. Licensed under Apache-2.0.'
    Description       = @'
Create PDF files from PowerShell on Windows, Linux, and macOS, built on the VellumPdf .NET 10 engine. Documents are assembled through a fluent pipeline (New-VellumPdfDocument | Add-VellumPdf... | Save-VellumPdfDocument).

Page setup: A0-A6, Letter, Legal, and Ledger page sizes; uniform or per-side margins; one of the 14 standard PDF fonts as the document default.

Content: headings with outline bookmarks; paragraphs with per-run colour, hyperlinks, alignment, and line spacing, or composed from mixed-style text runs; ordered and unordered lists; tables with header rows, explicit column widths, borders, and header backgrounds; images in JPEG, PNG, BMP, GIF, TIFF, JBIG2, and JPEG 2000 with sizing, alignment, and alt text; horizontal line separators; running headers and footers with {page}/{pages} tokens.

Fonts and text: the 14 standard fonts, or embed a TrueType font for full Unicode (also required for PDF/A); per-element font, size, and colour.

Metadata and accessibility: title, author, subject, keywords, creator, and producer; tagged-PDF structure, a document /Lang language tag, and image alt text for accessible output.

Archival and colour: PDF/A-2b, 2u, and 2a conformance; output intents using the default sRGB profile, a custom ICC profile, or generic CMYK.

Security and signing: AES encryption with user/owner passwords and permission flags; PAdES digital signatures, including RFC-3161 timestamps (PAdES B-T).

This module generates new PDFs. It does not read, edit, split, or merge existing PDF files; VellumPdf is a write-only engine with no parser.
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
            ReleaseNotes = '1.2.0: built on VellumPdf 1.5.3 (was 1.2.0). Set-VellumPdfSignature gains RFC-3161 timestamps (-TimestampUrl, -TimestampTimeout, -TimestampRequestCertificate), upgrading PAdES B-B signatures to B-T. Add-VellumPdfImage now accepts JBIG2 (.jbig2/.jb2) and JPEG 2000 (.jp2/.jpx/.j2k/.jpf) images, and the upstream engine adds more image codecs (interlaced/16-bit PNG, more TIFF compressions) plus font, colour, and accessibility improvements that existing pipelines pick up transparently. Full changelog: https://github.com/Tim81/PSVellumPDF/blob/main/CHANGELOG.md'
        }
    }
}
