#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfLineSeparator' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "sep-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfLineSeparator'
    }

    It 'produces a non-empty PDF with valid %PDF- header using defaults' {
        New-VellumPdfDocument |
            Add-VellumPdfLineSeparator |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with a custom LineWidth' {
        New-VellumPdfDocument |
            Add-VellumPdfLineSeparator -LineWidth 3.0 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with a custom Color' {
        New-VellumPdfDocument |
            Add-VellumPdfLineSeparator -Color 0.2, 0.4, 0.8 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with MarginTop and MarginBottom' {
        New-VellumPdfDocument |
            Add-VellumPdfLineSeparator -MarginTop 15 -MarginBottom 15 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with all styling options combined' {
        New-VellumPdfDocument |
            Add-VellumPdfLineSeparator -LineWidth 2.0 -Color 0.1, 0.2, 0.3 `
                -MarginTop 10 -MarginBottom 10 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'chains with other Add-VellumPdf* functions' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Above the separator.' |
            Add-VellumPdfLineSeparator -LineWidth 1.5 |
            Add-VellumPdfParagraph -Text 'Below the separator.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Add-VellumPdfLineSeparator
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }

    It 'rejects a LineWidth below the minimum (0.1)' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfLineSeparator -LineWidth 0.0 } | Should -Throw
        } finally { $doc.Dispose() }
    }

    It 'rejects a Color with out-of-range components' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfLineSeparator -Color 2.0, 0.0, 0.0 } | Should -Throw
        } finally { $doc.Dispose() }
    }
}
