#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfHeader' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "header-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Set-VellumPdfHeader'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Set-VellumPdfHeader -Template 'Page {page} of {pages}'
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }

    It 'produces a valid multi-page PDF with page-number template and footer' {
        $doc = New-VellumPdfDocument
        $doc = Set-VellumPdfHeader -Document $doc -Template 'Page {page} of {pages}'
        $doc = Set-VellumPdfFooter -Document $doc -Template 'Page {page} of {pages}'
        for ($i = 1; $i -le 60; $i++) {
            $doc = Add-VellumPdfParagraph -Document $doc -Text "Paragraph $i - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor."
        }
        Save-VellumPdfDocument -Document $doc -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $head = [System.Text.Encoding]::ASCII.GetString($bytes[0..4])
        $head | Should -Be '%PDF-'

        # Confirm multi-page: count '/Type /Page' occurrences (each real page has one)
        $pdfText = [System.Text.Encoding]::Latin1.GetString($bytes)
        $pageMatches = ([regex]::Matches($pdfText, '/Type\s*/Page[^s]')).Count
        $pageMatches | Should -BeGreaterThan 1
    }

    It 'produces a valid PDF with Font, FontSize, and Alignment variants' {
        New-VellumPdfDocument |
            Set-VellumPdfHeader -Template 'Right-aligned header - {page}' `
                -Font Helvetica -FontSize 9 -Alignment Right |
            Add-VellumPdfParagraph -Text 'Body text.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Left alignment and no font override' {
        New-VellumPdfDocument |
            Set-VellumPdfHeader -Template 'Draft - {page} of {pages}' -Alignment Left |
            Add-VellumPdfParagraph -Text 'Content.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'Set-VellumPdfFooter' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "footer-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Set-VellumPdfFooter'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Set-VellumPdfFooter -Template '{page} / {pages}'
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }

    It 'produces a valid PDF with Font, FontSize, and Alignment variants' {
        New-VellumPdfDocument |
            Set-VellumPdfFooter -Template '{page} / {pages}' `
                -Font TimesRoman -FontSize 8 -Alignment Right |
            Add-VellumPdfParagraph -Text 'Body text.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with FontSize-only override' {
        New-VellumPdfDocument |
            Set-VellumPdfFooter -Template 'Page {page}' -FontSize 10 |
            Add-VellumPdfParagraph -Text 'Body.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}
