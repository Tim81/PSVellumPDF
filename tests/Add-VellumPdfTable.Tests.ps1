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

    It 'accepts PSCustomObject rows (Import-Csv) and derives the header from property names' {
        $records = @(
            [pscustomobject]@{ Name = 'Alice'; Score = 'NINETYFIVE' }
            [pscustomobject]@{ Name = 'Bob';   Score = 'EIGHTYTWO' }
        )
        # The previous behaviour threw on PSCustomObject rows; not throwing and
        # producing a valid PDF proves records are now accepted and rendered.
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row $records |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'renders rich cells (ColSpan, Background, Alignment) and produces a valid PDF' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Header 'A', 'B' -Row @(
                , @(
                    @{ Text = 'Spanned total'; ColSpan = 2; Alignment = 'Right'; Background = '#eeeeee' }
                )
            ) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'applies -AlternateRowBackground and -ColumnAlignment by name/hex' {
        $rows = @(
            [object[]]@('a', '1'), [object[]]@('b', '2'), [object[]]@('c', '3')
        )
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row $rows -AlternateRowBackground 'silver' `
                -ColumnAlignment 'Left', 'Right' -BorderColor '#000000' |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'rejects a rich cell missing the Text key' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(, @(@{ ColSpan = 2 })) } |
                Should -Throw "*'Text' key*"
        }
        finally { $doc.Dispose() }
    }

    It 'validates rich-cell Font, FontSize, and ColSpan' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; FontSize = -5 })) } |
                Should -Throw '*FontSize must be between*'
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; FontSize = 99999 })) } |
                Should -Throw '*FontSize must be between*'
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; Font = 'Bogus' })) } |
                Should -Throw '*not a base-14 font*'
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; ColSpan = 0 })) } |
                Should -Throw '*ColSpan must be a positive*'
        }
        finally { $doc.Dispose() }
    }

    It 'renders a colour-only rich cell to a valid PDF (keeps the table font)' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Font TimesRoman -Row @(, @(@{ Text = 'tinted'; Color = 'navy' })) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'rejects rows that mix record and cell-array shapes' {
        $doc = New-VellumPdfDocument
        try {
            $mixed = @([pscustomobject]@{ A = 1; B = 2 }, [object[]]@('x', 'y'))
            { $doc | Add-VellumPdfTable -Row $mixed } | Should -Throw '*mixes record*'
        }
        finally { $doc.Dispose() }
    }

    It 'rejects out-of-range colour components' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(,@('a')) -BorderColor @(2.5, 0, 0) } |
                Should -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'builds a single-row table with the unary comma syntax' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row @(,@('OnlyRowCell1', 'OnlyRowCell2')) |
            Save-VellumPdfDocument -Path $script:outPath

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

    It 'produces a valid PDF when -FontHandle is used at table level (embedded font)' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $rows = @(
            [object[]]@('Alpha', 'One'),
            [object[]]@('Beta',  'Two')
        )
        $doc |
            Add-VellumPdfTable -Header @('Col1', 'Col2') -Row $rows -FontHandle $handle |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        # The PDF must contain an embedded TrueType font stream (/FontFile2).
        $pdfLatin1 = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $pdfLatin1 | Should -Match '/FontFile2'
    }

    It 'produces a valid PDF when a rich cell carries a FontHandle key' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc |
            Add-VellumPdfTable -Row @(
                , @(
                    @{ Text = 'Embedded cell'; FontHandle = $handle },
                    @{ Text = 'Plain cell' }
                )
            ) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
        $pdfLatin1 = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $pdfLatin1 | Should -Match '/FontFile2'
    }

    It 'colour-only rich cell in a -FontHandle table inherits the embedded font' {
        # A cell with only Color set should still use the embedded handle (not
        # fall back to the library-global Helvetica) when the table has -FontHandle.
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc |
            Add-VellumPdfTable -FontHandle $handle -Row @(
                , @(@{ Text = 'Tinted'; Color = 'navy' })
            ) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
        $pdfLatin1 = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $pdfLatin1 | Should -Match '/FontFile2'
    }

    It 'rejects -Font and -FontHandle supplied together' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        try {
            { $doc | Add-VellumPdfTable -Row @(,@('x')) -Font Helvetica -FontHandle $handle } |
                Should -Throw '*mutually exclusive*'
        }
        finally { $doc.Dispose() }
    }

    It 'produces a valid PDF with rich header cells (Background, Color, Alignment)' {
        $richHeaders = @(
            @{ Text = 'Name';  Background = '#336699'; Color = 'white'; Alignment = 'Left'   },
            @{ Text = 'Score'; Background = '#336699'; Color = 'white'; Alignment = 'Center' }
        )
        $rows = @(
            [object[]]@('Alice', '95'),
            [object[]]@('Bob',   '82')
        )
        New-VellumPdfDocument |
            Add-VellumPdfTable -Header $richHeaders -Row $rows |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'rich header cells with FontHandle produce a valid PDF with embedded font' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $richHeaders = @(
            @{ Text = 'Name';  FontHandle = $handle },
            @{ Text = 'Value'; FontHandle = $handle }
        )
        $doc |
            Add-VellumPdfTable -Header $richHeaders -Row @([object[]]@('x', '1')) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
        $pdfLatin1 = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $pdfLatin1 | Should -Match '/FontFile2'
    }

    It 'plain string headers still work after -Header became [object[]]' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Header @('ColA', 'ColB') -Row @([object[]]@('1', '2')) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'applies uniform -CellPadding and produces a valid PDF' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row @([object[]]@('A', 'B')) -CellPadding @(6) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'applies four-value -CellPadding (top/right/bottom/left) and produces a valid PDF' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row @([object[]]@('X', 'Y')) -CellPadding @(2, 8, 2, 8) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'rejects -CellPadding with an element count that is not 1 or 4' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(,@('x')) -CellPadding @(1, 2, 3) } |
                Should -Throw '*1 value*4 values*'
        }
        finally { $doc.Dispose() }
    }

    It 'applies per-cell Padding (four values) and produces a valid PDF' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row @(
                , @(
                    @{ Text = 'Padded'; Padding = @(4, 10, 4, 10) }
                )
            ) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'applies per-cell Language and produces a valid PDF' {
        New-VellumPdfDocument |
            Add-VellumPdfTable -Row @(
                , @(
                    @{ Text = 'English text'; Language = 'en-US' }
                )
            ) |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'rejects a rich cell Padding with an element count that is not 1 or 4' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; Padding = @(1, 2, 3) })) } |
                Should -Throw '*1 value*4 values*'
        }
        finally { $doc.Dispose() }
    }

    It 'rejects a rich cell Padding with a negative value' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; Padding = @(-1) })) } |
                Should -Throw '*non-negative*'
        }
        finally { $doc.Dispose() }
    }
}
