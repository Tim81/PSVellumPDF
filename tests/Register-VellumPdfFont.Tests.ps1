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

Describe 'Register-VellumPdfFont' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "font-$([guid]::NewGuid()).pdf"
        $script:doc = New-VellumPdfDocument
    }

    AfterEach {
        if ($script:doc) {
            try { $script:doc.Dispose() } catch { Write-Verbose "Dispose skipped: $_" }
        }
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Register-VellumPdfFont'
    }

    It 'returns an EmbeddedFontHandle' {
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath
        $handle | Should -BeOfType 'VellumPdf.Fonts.EmbeddedFontHandle'
    }

    It 'throws when the font path does not exist' {
        { Register-VellumPdfFont -Document $script:doc -Path 'C:\nonexistent\missing.ttf' } |
            Should -Throw
    }

    It 'produces a valid PDF when a heading uses -FontHandle' {
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath
        $script:doc |
            Add-VellumPdfHeading -Text 'Embedded Font Heading' -FontHandle $handle |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF when a paragraph uses -FontHandle' {
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath
        $script:doc |
            Add-VellumPdfParagraph -Text 'Embedded font paragraph text.' -FontHandle $handle |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid non-empty PDF for a PDF/A-2b document with embedded-font text' {
        $script:doc.Dispose()
        $script:doc = New-VellumPdfDocument -Conformance PdfA2b
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath

        $script:doc |
            Add-VellumPdfHeading -Text 'Archival Heading' -FontHandle $handle |
            Add-VellumPdfParagraph -Text 'Archival body text with embedded TrueType font.' -FontHandle $handle |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'New-VellumTextStyle with FontHandle (private helper)' {
    BeforeAll {
        $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
        $script:helperDoc = New-VellumPdfDocument
        $script:handle = Register-VellumPdfFont -Document $script:helperDoc -Path $script:fontPath
    }

    AfterAll {
        if ($script:helperDoc) {
            try { $script:helperDoc.Dispose() } catch { Write-Verbose "Dispose skipped: $_" }
        }
    }

    It 'returns a TextStyle with FontRef.IsEmbedded = $true when -FontHandle is supplied' {
        $h = $script:handle
        $style = InModuleScope PSVellumPDF -Parameters @{ h = $h } {
            New-VellumTextStyle -FontHandle $h
        }
        $style | Should -Not -BeNullOrEmpty
        $style.FontRef.IsEmbedded | Should -BeTrue
    }
}
