#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfTable' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "table-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfTable'
    }

    It 'produces a non-empty PDF with valid %PDF- header from header and rows' {
        $headers = @('Name', 'Score', 'Grade')
        $rows = @(
            [object[]]@('Alice', '95', 'A'),
            [object[]]@('Bob', '82', 'B')
        )

        New-VellumPdfDocument |
            Add-VellumPdfTable -Header $headers -Row $rows |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with explicit column widths' {
        $rows = @(
            [object[]]@('Alpha', '1.0'),
            [object[]]@('Beta', '2.5')
        )

        New-VellumPdfDocument |
            Add-VellumPdfTable -Row $rows -ColumnWidth @(150.0, 100.0) |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with styled and aligned table' {
        $headers = @('Item', 'Qty', 'Price')
        $rows = @(
            [object[]]@('Widget', '10', '9.99'),
            [object[]]@('Gadget', '5', '24.99')
        )

        New-VellumPdfDocument |
            Add-VellumPdfTable -Header $headers -Row $rows `
                -Font Helvetica -FontSize 9 -Alignment Center `
                -BorderWidth 1.0 `
                -BorderColor @(0.0, 0.0, 0.0) `
                -HeaderBackground @(0.8, 0.8, 0.8) |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'chains with other Add-VellumPdf* functions' {
        $rows = @(
            [object[]]@('Row1Col1', 'Row1Col2')
        )

        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Table Report' -Level 1 |
            Add-VellumPdfTable -Row $rows |
            Add-VellumPdfParagraph -Text 'End of report.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $rows = @([object[]]@('X', 'Y'))
        $doc = New-VellumPdfDocument | Add-VellumPdfTable -Row $rows
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }
}
