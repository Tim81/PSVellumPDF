#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfDocumentInfo' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "info-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Set-VellumPdfDocumentInfo'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Set-VellumPdfDocumentInfo -Title 'Test'
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }

    It 'sets Title, Author, Subject and Keywords in-memory before saving' {
        $doc = New-VellumPdfDocument |
            Set-VellumPdfDocumentInfo -Title 'Annual Report 2026' `
                -Author 'Acme Corp' -Subject 'Finance' -Keywords 'finance,annual'

        $doc.Info.Title    | Should -Be 'Annual Report 2026'
        $doc.Info.Author   | Should -Be 'Acme Corp'
        $doc.Info.Subject  | Should -Be 'Finance'
        $doc.Info.Keywords | Should -Be 'finance,annual'
        $doc.Dispose()
    }

    It 'sets Creator and Producer in-memory' {
        $doc = New-VellumPdfDocument |
            Set-VellumPdfDocumentInfo -Creator 'MyApp 1.0' -Producer 'PSVellumPDF'

        $doc.Info.Creator  | Should -Be 'MyApp 1.0'
        $doc.Info.Producer | Should -Be 'PSVellumPDF'
        $doc.Dispose()
    }

    It 'partial set: only -Title leaves other Info props untouched' {
        $doc = New-VellumPdfDocument |
            Set-VellumPdfDocumentInfo -Author 'Original Author'
        $doc = $doc | Set-VellumPdfDocumentInfo -Title 'Only Title Changed'

        $doc.Info.Title  | Should -Be 'Only Title Changed'
        $doc.Info.Author | Should -Be 'Original Author'
        $doc.Dispose()
    }

    It 'produces a valid PDF with metadata set' {
        New-VellumPdfDocument |
            Set-VellumPdfDocumentInfo -Title 'Test PDF' -Author 'Tester' |
            Add-VellumPdfParagraph -Text 'Hello metadata.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'New-VellumPdfDocument margins' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "margins-$([guid]::NewGuid()).pdf"
    }

    It '-Margin 30 sets all four sides to 30 before saving' {
        $doc = New-VellumPdfDocument -Margin 30
        $doc.Margins.Top    | Should -Be 30
        $doc.Margins.Right  | Should -Be 30
        $doc.Margins.Bottom | Should -Be 30
        $doc.Margins.Left   | Should -Be 30
        $doc.Dispose()
    }

    It '-Margin 30 -MarginLeft 50 yields Left=50, others=30' {
        $doc = New-VellumPdfDocument -Margin 30 -MarginLeft 50
        $doc.Margins.Top    | Should -Be 30
        $doc.Margins.Right  | Should -Be 30
        $doc.Margins.Bottom | Should -Be 30
        $doc.Margins.Left   | Should -Be 50
        $doc.Dispose()
    }

    It 'per-side without -Margin uses library defaults for unspecified sides' {
        $defaultDoc = New-VellumPdfDocument
        $defaultTop = $defaultDoc.Margins.Top
        $defaultRight = $defaultDoc.Margins.Right
        $defaultDoc.Dispose()

        $doc = New-VellumPdfDocument -MarginBottom 40
        $doc.Margins.Top   | Should -Be $defaultTop
        $doc.Margins.Right | Should -Be $defaultRight
        $doc.Margins.Bottom | Should -Be 40
        $doc.Dispose()
    }

    It 'no margin params leaves margins at library defaults' {
        $docA = New-VellumPdfDocument
        $docB = New-VellumPdfDocument
        $docA.Margins.Top | Should -Be $docB.Margins.Top
        $docA.Dispose()
        $docB.Dispose()
    }

    It 'produces a valid PDF with custom margins' {
        New-VellumPdfDocument -Margin 40 |
            Add-VellumPdfParagraph -Text 'Custom margins document.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}
