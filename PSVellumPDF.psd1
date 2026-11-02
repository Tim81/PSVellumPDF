@{
    RootModule        = 'PSVellumPDF.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'e51842c7-ddb1-4700-8ade-77055baa4f3a'
    Author            = 'Timothy van der Ham (@Tim81)'
    Copyright         = '© Timothy van der Ham. Licensed under Apache-2.0.'
    Description       = @'
Create, check and read PDF files from PowerShell on Windows, Linux, and macOS. PSVellumPDF wraps the VellumPdf 2.3 .NET 10 engine.

Flowing documents: New-VellumPdfDocument | Add-VellumPdf... | Save-VellumPdfDocument. Add headings with outline bookmarks, paragraphs, mixed-style text runs, lists, tables (merged and styled cells, embedded fonts), images (JPEG, PNG, BMP, GIF, TIFF, JBIG2, JPEG 2000, CCITT), pie charts, barcodes and 2-D codes (QR, Data Matrix, Aztec, PDF417, Code 128/39, EAN/UPC, ITF-14), free-form vector drawings, and running headers and footers with page numbers.

Page-based documents: New-VellumPdfPageDocument places text, shapes, gradients, images and barcodes by coordinate, and adds fillable form fields, links between pages, collapsible bookmarks, rotated pages, linearized "fast web view" output and byte-for-byte reproducible files.

Standards and security: PDF/A-2b/2u/2a and PDF/UA-1 output with tagged structure, language and alternate text; AES encryption with permissions; PAdES digital signatures from B-B to B-LTA (timestamps, long-term validation, external keys and HSM/KMS signers). Test-VellumPdfConformance checks any PDF against PDF/A and PDF/UA in-process, and Save-VellumPdfDocument -Validate refuses to write a non-compliant file.

Experimental reading (VellumPdf.Reader preview): Get-VellumPdfInfo, Get-VellumPdfText, Export-VellumPdfImage and Unprotect-VellumPdfDocument. PSVellumPDF cannot edit, split or merge existing PDFs.
'@

    # VellumPdf targets .NET 10; PowerShell 7.6 is the first release on .NET 10.
    PowerShellVersion       = '7.6'
    CompatiblePSEditions    = @('Core')

    # Assemblies are loaded explicitly by the .psm1 (with a friendly error when
    # ./lib is missing), so they are intentionally NOT listed in RequiredAssemblies.

    FunctionsToExport = @(
        'Add-VellumPdfBarcode'
        'Add-VellumPdfDrawing'
        'Add-VellumPdfElement'
        'Add-VellumPdfFormField'
        'Add-VellumPdfGradient'
        'Add-VellumPdfHeading'
        'Add-VellumPdfImage'
        'Add-VellumPdfLineSeparator'
        'Add-VellumPdfLink'
        'Add-VellumPdfList'
        'Add-VellumPdfOutlineEntry'
        'Add-VellumPdfPage'
        'Add-VellumPdfPageBarcode'
        'Add-VellumPdfPageImage'
        'Add-VellumPdfParagraph'
        'Add-VellumPdfPieChart'
        'Add-VellumPdfShape'
        'Add-VellumPdfTable'
        'Add-VellumPdfText'
        'Export-VellumPdfImage'
        'Get-VellumPdfInfo'
        'Get-VellumPdfText'
        'Invoke-VellumPdfCanvas'
        'New-VellumPdfDocument'
        'New-VellumPdfPageDocument'
        'New-VellumPdfTextRun'
        'Protect-VellumPdfDocument'
        'Register-VellumPdfFont'
        'Save-VellumPdfDocument'
        'Set-VellumPdfDocumentInfo'
        'Set-VellumPdfFooter'
        'Set-VellumPdfHeader'
        'Set-VellumPdfOutputIntent'
        'Set-VellumPdfSignature'
        'Test-VellumPdfConformance'
        'Unprotect-VellumPdfDocument'
    )
    FormatsToProcess  = @('PSVellumPDF.Format.ps1xml')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @(
                'PDF', 'VellumPdf', 'PDFA', 'Accessibility', 'Document', 'Reporting',
                'Create', 'Generate', 'Signing', 'PAdES', 'CrossPlatform',
                'Barcode', 'QRCode', 'Chart', 'Forms', 'Preflight', 'PDFUA', 'Validation',
                'PSEdition_Core', 'Windows', 'Linux', 'MacOS'
            )
            LicenseUri   = 'https://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/Tim81/PSVellumPDF'
            ReleaseNotes = '2.0.0: built on VellumPdf 2.3.3. New: pie charts, barcodes, vector drawing, a page-based document (forms, links, outlines, rotation, linearization, reproducible output), PDF/UA-1, PAdES B-T/B-LT/B-LTA and external signers, in-process PDF/A and PDF/UA preflight, and experimental Reader cmdlets. Fixes: -Level 1 headings are now H1, -MarginBottom now adds space, deeper-than-one-level list items are refused instead of dropped, Windows-1252 punctuation no longer triggers the encoding warning. A document can be saved once. Breaking changes and upgrade notes: https://github.com/Tim81/PSVellumPDF/blob/main/CHANGELOG.md'
        }
    }
}
