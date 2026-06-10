@{
    RootModule        = 'PSVellumPDF.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e51842c7-ddb1-4700-8ade-77055baa4f3a'
    Author            = 'Timothy van der Ham (@Tim81)'
    Copyright         = '© Timothy van der Ham. Licensed under Apache-2.0.'
    Description       = 'PowerShell module for generating PDFs with the VellumPdf .NET 10 library.'

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
        'Add-VellumPdfList'
        'Add-VellumPdfParagraph'
        'Add-VellumPdfTable'
        'Register-VellumPdfFont'
        'Save-VellumPdfDocument'
        'Set-VellumPdfHeader'
        'Set-VellumPdfFooter'
        'Set-VellumPdfDocumentInfo'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @(
                'PDF', 'VellumPdf', 'PDFA', 'Document', 'Reporting',
                'PSEdition_Core', 'Windows', 'Linux', 'MacOS'
            )
            LicenseUri   = 'https://www.apache.org/licenses/LICENSE-2.0'
            ProjectUri   = 'https://github.com/Tim81/PSVellumPDF'
            ReleaseNotes = 'Initial scaffold: document creation, headings, paragraphs, save.'
        }
    }
}
