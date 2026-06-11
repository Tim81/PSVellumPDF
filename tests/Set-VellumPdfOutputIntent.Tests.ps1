#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:fontPath = Join-Path $PSScriptRoot 'assets/DejaVuSans.ttf'

    # The library embeds ICC profile bytes as-is (no validation), so a synthetic
    # profile is sufficient to assert the wrapper forwards everything correctly.
    $script:iccPath = Join-Path $TestDrive 'synthetic.icc'
    [System.IO.File]::WriteAllBytes($script:iccPath, [byte[]](1..128))

    function script:New-PdfADocument {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc |
            Set-VellumPdfDocumentInfo -Title 'Intent test' -Author 'Tests' |
            Add-VellumPdfParagraph -Text 'Output intent body.' -FontHandle $font
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfOutputIntent' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "intent-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        (Get-Module PSVellumPDF).ExportedFunctions.Keys | Should -Contain 'Set-VellumPdfOutputIntent'
    }

    It 'returns the document instance for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $result = $doc | Set-VellumPdfOutputIntent -Cmyk
        [object]::ReferenceEquals($doc, $result) | Should -BeTrue
        $doc.Dispose()
    }

    It 'embeds a custom ICC profile with identifier and info in the saved PDF' {
        New-PdfADocument |
            Set-VellumPdfOutputIntent -IccProfilePath $script:iccPath -ComponentCount 3 `
                -OutputConditionIdentifier 'CUSTOMINTENT42' -Info 'INTENTINFO42' |
            Save-VellumPdfDocument -Path $script:outPath

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        [System.Text.Encoding]::ASCII.GetString($bytes[0..4]) | Should -Be '%PDF-'
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/OutputIntent'
        $content | Should -Match 'CUSTOMINTENT42'
        $content | Should -Match 'INTENTINFO42'
    }

    It 'writes the built-in generic CMYK intent with -Cmyk' {
        New-PdfADocument |
            Set-VellumPdfOutputIntent -Cmyk |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Match '/OutputIntent'
        $content | Should -Match 'Generic CMYK'
    }

    It '-Cmyk honours a custom -OutputConditionIdentifier' {
        New-PdfADocument |
            Set-VellumPdfOutputIntent -Cmyk -OutputConditionIdentifier 'CMYKCOND77' |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Match 'CMYKCOND77'
    }

    It 'throws a clear error for a non-conformant document' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Plain.'
        try {
            { $doc | Set-VellumPdfOutputIntent -Cmyk } |
                Should -Throw '*only written for PDF/A conformant documents*'
        }
        finally { $doc.Dispose() }
    }

    It 'throws when the ICC profile file does not exist' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        try {
            { $doc | Set-VellumPdfOutputIntent -IccProfilePath (Join-Path $TestDrive 'missing.icc') `
                    -ComponentCount 3 -OutputConditionIdentifier 'X' } |
                Should -Throw '*ICC profile not found*'
        }
        finally { $doc.Dispose() }
    }

    It 'throws a clear error when used on an already-saved (disposed) document' {
        # Plain document: the stale-document guard fires before the conformance
        # check, and a PDF/A document cannot be saved with the base-14 default font.
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Stale.'
        $doc | Save-VellumPdfDocument -Path $script:outPath
        { $doc | Set-VellumPdfOutputIntent -Cmyk } | Should -Throw '*disposed*'
    }
}
