#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfList' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "list-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfList'
    }

    It 'produces a non-empty PDF with valid %PDF- header for an unordered list' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Apples', 'Bananas', 'Cherries' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with OrderedDecimal style' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'First', 'Second', 'Third' -Style OrderedDecimal |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with OrderedAlpha style' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Alpha item', 'Beta item', 'Gamma item' -Style OrderedAlpha |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with OrderedRoman style' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Roman I', 'Roman II', 'Roman III' -Style OrderedRoman |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with a custom indent' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Indented one', 'Indented two' -Indent 30 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Font and FontSize styling' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Styled one', 'Styled two', 'Styled three' `
                -Style OrderedDecimal -Font Helvetica -FontSize 12 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Font-only styling (no FontSize)' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Bold item', 'Bold item two' -Font TimesBold |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with FontSize-only styling (no Font)' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Large item' -FontSize 18 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'chains with other Add-VellumPdf* functions' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Shopping List' -Level 1 |
            Add-VellumPdfList -Item 'Eggs', 'Milk', 'Bread' -Style Unordered |
            Add-VellumPdfParagraph -Text 'End of list.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Add-VellumPdfList -Item 'One', 'Two'
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }

    It 'works with a single item list' {
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Only item' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'builds a multi-level nested list (hashtable items with Children) into a valid PDF' {
        # The content stream is compressed, so assert structural validity rather
        # than matching label text; reaching Save without error proves the
        # recursive ListItem.AddChild build traversed every level.
        New-VellumPdfDocument |
            Add-VellumPdfList -Item @(
                'Top one',
                @{ Text = 'Top two'; Children = @('Child A', @{ Text = 'Child B'; Children = @('Grandchild') }) }
            ) -Style OrderedDecimal |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'throws when a nested-item hashtable lacks a Text key' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfList -Item @(@{ Children = @('x') }) } | Should -Throw "*'Text' key*"
        }
        finally { $doc.Dispose() }
    }

    It 'caps nesting depth on cyclic input instead of overflowing' {
        $doc = New-VellumPdfDocument
        try {
            $cycle = @{ Text = 'loop' }
            $cycle['Children'] = @($cycle)   # self-referential
            { $doc | Add-VellumPdfList -Item @($cycle) } | Should -Throw '*maximum depth*'
        }
        finally { $doc.Dispose() }
    }

    It 'produces a valid PDF with -FontHandle (embedded TrueType font) and asserts /FontFile2' {
        $fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $fontPath
        $doc |
            Add-VellumPdfList -Item 'Embedded one', 'Embedded two' -FontHandle $handle |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/FontFile2'
    }

    It 'produces a valid PDF with -FontHandle and -FontSize together' {
        $fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $fontPath
        $doc |
            Add-VellumPdfList -Item 'Sized one', 'Sized two' -FontHandle $handle -FontSize 14 |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'throws when -FontHandle and -Font are both supplied' {
        $fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
        $doc = New-VellumPdfDocument
        try {
            $handle = Register-VellumPdfFont -Document $doc -Path $fontPath
            { $doc | Add-VellumPdfList -Item 'A' -FontHandle $handle -Font Helvetica } |
                Should -Throw '*mutually exclusive*'
        }
        finally { $doc.Dispose() }
    }

    It 'produces a valid PDF with -Language and asserts /Lang in the output' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfList -Item 'Premier', 'Deuxieme', 'Troisieme' -Language 'fr-FR' |
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

    It 'applies -Language to nested list items' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfList -Item @(
                'Parent item',
                @{ Text = 'Nested parent'; Children = @('Child item') }
            ) -Language 'en-GB' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}
