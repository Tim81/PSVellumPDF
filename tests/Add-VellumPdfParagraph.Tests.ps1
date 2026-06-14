#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    if (-not (Test-Path $script:fontPath)) {
        throw "Test font asset not found at '$($script:fontPath)'. Cannot run embedded-font tests."
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfParagraph' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "para-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfParagraph'
    }

    It 'produces a non-empty PDF with valid %PDF- header (Text set)' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Simple paragraph text.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF for each alignment value' {
        foreach ($align in 'Left', 'Center', 'Right', 'Justify') {
            $path = Join-Path $TestDrive "para-align-$align-$([guid]::NewGuid()).pdf"
            New-VellumPdfDocument |
                Add-VellumPdfParagraph -Text "Aligned $align." -Alignment $align |
                Save-VellumPdfDocument -Path $path

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($path)[0..4])
            $head | Should -Be '%PDF-'
        }
    }

    It 'produces a valid PDF with -Language (Text set) and asserts /Lang in the output' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfParagraph -Text 'Bonjour le monde.' -Language 'fr-FR' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/Lang'
    }

    It 'produces a valid PDF with -Language (Runs set) and asserts /Lang in the output' {
        $run1 = New-VellumPdfTextRun -Text 'Hola '
        $run2 = New-VellumPdfTextRun -Text 'mundo.' -Font HelveticaBold
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfParagraph -Run $run1, $run2 -Language 'es-ES' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/Lang'
    }

    It 'produces a valid PDF with -Language combined with -Font and -FontSize' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfParagraph -Text 'Styled and tagged.' `
                -Font TimesBold -FontSize 12 -Language 'en-GB' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with -Language combined with -FontHandle' {
        $doc = New-VellumPdfDocument -Tagged
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc |
            Add-VellumPdfParagraph -Text 'Embedded font with language.' `
                -FontHandle $handle -Language 'de-DE' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/Lang'
        $raw | Should -Match '/FontFile2'
    }

    It 'produces a valid PDF with -Language when no other overrides are present' {
        # Exercises the path where Language bypasses the short-circuit fast-path
        # and builds a real Paragraph with document-default font.
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfParagraph -Text 'Default font, just language.' -Language 'en-US' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/Lang'
    }

    It 'chains with other Add-VellumPdf* functions' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Title' -Level 1 |
            Add-VellumPdfParagraph -Text 'First paragraph.' -Language 'en-US' |
            Add-VellumPdfParagraph -Text 'Second paragraph.' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Paragraph.' -Language 'en-US'
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }
}
