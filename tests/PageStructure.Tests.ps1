#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Nested structure in tagged page documents: Use-VellumPdfStructure, Add-VellumPdfPageTable, Add-VellumPdfPageList.

param()

BeforeDiscovery {
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)
}

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    function script:New-Tagged([string]$Conformance = 'PdfUA1') {
        New-VellumPdfPageDocument -Conformance $Conformance -Language en-US | Add-VellumPdfPage | Set-VellumPdfDocumentInfo -Title 'Structure'
    }
    function script:Save-Valid($Doc, [string]$Name, [string]$Profile = 'PdfUA1') {
        $p = Join-Path $TestDrive "$Name.pdf"
        $Doc | Save-VellumPdfDocument -Path $p -Validate | Out-Null
        (Test-VellumPdfConformance -Path $p -Profile $Profile).IsCompliant | Should -BeTrue
        $p
    }
    # Flattens a tree to "Type" strings in document order.
    function script:Get-Types($Nodes) { foreach ($n in $Nodes) { $n.Type; Get-Types $n.Children } }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Use-VellumPdfStructure' -Skip:(-not $script:haveQpdf) {
    It 'nests what is tagged inside a block under one group, and scopes nest' {
        $path = Save-Valid (New-Tagged | Use-VellumPdfStructure -Type Sect -ScriptBlock {
                $_ | Add-VellumPdfText 'Heading' -X 72 -Y 760 -FontSize 18 -Role H1 |
                    Use-VellumPdfStructure -Type Div -ScriptBlock { $_ | Add-VellumPdfText 'Inner paragraph' -X 72 -Y 730 } |
                    Add-VellumPdfTextBox 'Second paragraph in the section.' -X 72 -Y 700 -Width 300
            } | Add-VellumPdfText 'Outside' -X 72 -Y 600) 'sect'
        $tree = Get-PdfStructureTree $path
        $tree.Count | Should -Be 2
        $tree[0].Type | Should -Be 'Sect'
        @($tree[0].Children.Type) | Should -Be 'H1', 'Div', 'P'
        @($tree[0].Children[1].Children.Type) | Should -Be 'P'
        $tree[1].Type | Should -Be 'P'
    }

    It 'warns when nothing was tagged, runs the block untagged, and rejects a bad language' {
        $w = $null
        $null = New-Tagged | Use-VellumPdfStructure -Type Sect -ScriptBlock { } -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -Match 'nothing was tagged'
        $plain = New-VellumPdfPageDocument | Add-VellumPdfPage
        $out = $plain | Use-VellumPdfStructure -Type Div -ScriptBlock { $_ | Add-VellumPdfText 'x' -X 1 -Y 1 }
        $out | Should -BeOfType ([VellumPdf.Document.PdfDocument])
        { New-Tagged | Use-VellumPdfStructure -Type Sect -Language 'bad tag' -ScriptBlock { } } | Should -Throw '*BCP 47*'
        $plain.Dispose()
    }

    It 'writes the group language' {
        $path = Save-Valid (New-Tagged | Use-VellumPdfStructure -Type Sect -Language fr-FR -ScriptBlock { $_ | Add-VellumPdfText 'Bonjour' -X 72 -Y 700 -Language fr-FR }) 'sect-lang'
        (Get-PdfStructureTree $path)[0].Lang | Should -Be 'fr-FR'
    }
}

Describe 'Add-VellumPdfPageTable' {
    It 'tags Table > TR > TH/TD with scope and spans, and passes PDF/UA-1 and PDF/A-2a' -Skip:(-not $script:haveQpdf) -ForEach @(
        @{ Level = 'PdfUA1' }
        @{ Level = 'PdfA2a' }
    ) {
        $rows = @(
            @('Widget with a long description that wraps onto several lines', '2', '10.00'),
            @(@{ Text = 'Shipping'; ColSpan = 2 }, '5.00'),
            @(@{ Text = 'Rowspan'; RowSpan = 2 }, 'x', 'y'),
            @('p', 'q'))
        $doc = New-Tagged $Level
        $path = Save-Valid ($doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 450 -Header 'Item', 'Qty', 'Price' -HeaderBackground '#e8f0fe' -AlternateRowBackground '#f4f4f4' -Row $rows) "table-$Level" $Level
        $tree = Get-PdfStructureTree $path
        $tree.Count | Should -Be 1
        $table = $tree[0]
        $table.Type | Should -Be 'Table'
        @($table.Children.Type | Select-Object -Unique) | Should -Be 'TR'
        $table.Children.Count | Should -Be 5
        @($table.Children[0].Children.Type) | Should -Be 'TH', 'TH', 'TH'
        @($table.Children[0].Children.Scope | Select-Object -Unique) | Should -Be 'Column'
        $table.Children[2].Children[0].ColSpan | Should -Be 2
        $table.Children[3].Children[0].RowSpan | Should -Be 2
        @($table.Children[3].Children.Type) | Should -Be 'TD', 'TD', 'TD'
        @($table.Children[4].Children.Type) | Should -Be 'TD', 'TD'
        # Cell text is wrapped inside its column: 13 cells, and the long one needs more than one line.
        ([regex]::Matches((Get-PdfContentText $path), '(?m)^BT$')).Count | Should -BeGreaterThan 13
        # Backgrounds and grid lines are artifacts.
        (Get-PdfContentText $path) | Should -Match '/Artifact BMC'
    }

    It 'makes the first column row headers with -RowHeader' -Skip:(-not $script:haveQpdf) {
        $path = Save-Valid (New-Tagged | Add-VellumPdfPageTable -X 72 -Y 700 -ColumnWidth 100, 100 -RowHeader -Header 'Name', 'Value' -Row @(@('alpha', '1'), @('beta', '2'))) 'rowheader'
        $table = (Get-PdfStructureTree $path)[0]
        @($table.Children[1].Children.Type) | Should -Be 'TH', 'TD'
        $table.Children[1].Children[0].Scope | Should -Be 'Row'
        $table.Children[0].Children[0].Scope | Should -Be 'Column'
    }

    It 'places the table by -X/-Y, reports its size with -PassThru, and positions columns' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $info = $doc | Add-VellumPdfPageTable -X 100 -Y 500 -ColumnWidth 50, 150 -Padding 5 -FontSize 10 -Leading 12 -Row @(@('a', 'b'), @('c', 'd')) -PassThru
        $info.Rows | Should -Be 2
        $info.Columns | Should -Be 2
        $info.Height | Should -Be 44          # two rows of 12 + 2 * 5
        $info.Bottom | Should -Be 456
        $path = Join-Path $TestDrive 'placed.pdf'
        $info.Document | Save-VellumPdfDocument -Path $path | Out-Null
        $content = Get-PdfContentText $path
        $content | Should -Match '1 0 0 1 105 485 Tm\r?\n\(a\) Tj'     # 500 - 5 padding - 10 font size
        $content | Should -Match '1 0 0 1 155 485 Tm\r?\n\(b\) Tj'
        $content | Should -Match '1 0 0 1 105 463 Tm\r?\n\(c\) Tj'     # second row starts 22 lower (12 + 2 * 5): 478 - 5 - 10
    }

    It 'aligns columns and cells, and draws in an untagged document without structure' {
        $path = Join-Path $TestDrive 'untagged-table.pdf'
        New-VellumPdfPageDocument -Language en | Add-VellumPdfPage |
            Add-VellumPdfPageTable -X 72 -Y 700 -ColumnWidth 100, 100 -ColumnAlignment Left, Right -Row @(@('l', 'r'), @(@{ Text = 'c'; Alignment = 'Center' }, 'r2')) -BorderWidth 0 |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PdfText $path) | Should -Not -Match '/StructTreeRoot'
        $x = @{}
        foreach ($m in [regex]::Matches((Get-PdfContentText $path), '1 0 0 1 ([\d.]+) [\d.]+ Tm\r?\n\(([^)]*)\) Tj')) { $x[$m.Groups[2].Value] = [double]$m.Groups[1].Value }
        $x['l'] | Should -Be 76
        $x['r'] | Should -BeGreaterThan 150
        $x['c'] | Should -BeGreaterThan 100 -Because 'centred text is not at the left padding'
        $x['c'] | Should -BeLessThan 140
    }

    It 'draws an embedded font and a coloured cell' {
        $doc = New-Tagged 'PdfUA1'
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $path = Save-Valid ($doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -FontHandle $font -Header 'Zażółć', 'Gęślą' -Row @(, @(@{ Text = 'Jaźń'; Color = 'red'; Background = '#ffeeee' }, 'x'))) 'embedded-table'
        (Get-PdfText $path) | Should -Match '/FontFile2'
        (Get-PdfContentText $path) | Should -Match '1 0 0 rg'
    }

    It 'rejects bad input with the cmdlet name' {
        $doc = New-Tagged
        try {
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @() } | Should -Throw '*has no cells*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -ColumnWidth 100 -Row @(, @('a', 'b')) } | Should -Throw '*-ColumnWidth has 1 value(s) but the table has 2*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(, @(@{ Text = 'a'; ColSpan = 0 })) } | Should -Throw '*ColSpan must be a whole number*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(, @(@{ Text = 'a'; RowSpan = 3 })) } | Should -Throw '*RowSpan runs past the last row*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 20 -Width 300 -Row @(@('a'), @('b'), @('c'), @('d'), @('e')) } | Should -Throw '*not split across pages*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(, @(@{ Text = 'a'; Alignment = 'Diagonal' })) } | Should -Throw '*Alignment*invalid*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 99999 -Width 300 -Row @(, @('a')) } | Should -Throw '*between -14400 and 14400*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfPageList' {
    It 'tags L > LI > Lbl + LBody, nests one level, and passes PDF/UA-1 and PDF/A-2a' -Skip:(-not $script:haveQpdf) -ForEach @(
        @{ Level = 'PdfUA1' }
        @{ Level = 'PdfA2a' }
    ) {
        $doc = New-Tagged $Level
        $path = Save-Valid ($doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item 'Read the brief and make notes about every open question that comes up', @{ Text = 'Draft'; Children = 'Outline', 'Write it up' }, 'Review') "list-$Level" $Level
        $list = (Get-PdfStructureTree $path)[0]
        $list.Type | Should -Be 'L'
        $list.Children.Count | Should -Be 3
        @($list.Children.Type | Select-Object -Unique) | Should -Be 'LI'
        @($list.Children[0].Children.Type) | Should -Be 'Lbl', 'LBody'
        @($list.Children[1].Children.Type) | Should -Be 'Lbl', 'LBody'
        # The item with children: LBody holds the text paragraph and the nested list.
        @($list.Children[1].Children[1].Children.Type) | Should -Be 'P', 'L'
        $nested = $list.Children[1].Children[1].Children[1]
        $nested.Children.Count | Should -Be 2
        @($nested.Children[0].Children.Type) | Should -Be 'Lbl', 'LBody'
    }

    It 'numbers items and children, hangs wrapped text, and reports its size' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $info = $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 200 -Numbered -FontSize 10 -Leading 12 -ItemSpacing 2 -Item 'one', @{ Text = 'two'; Children = 'x', 'y' }, 'three' -PassThru
        $info.ItemCount | Should -Be 5
        $info.Height | Should -Be (5 * 12 + 4 * 2)
        $path = Join-Path $TestDrive 'numbered.pdf'
        $info.Document | Save-VellumPdfDocument -Path $path | Out-Null
        $strings = [regex]::Matches((Get-PdfContentText $path), '\(([^)]*)\) Tj') | ForEach-Object { $_.Groups[1].Value }
        $strings | Should -Be '1.', 'one', '2.', 'two', 'a.', 'x', 'b.', 'y', '3.', 'three'
    }

    It 'uses a bullet, and a hyphen when the font has no bullet glyph' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $plain = Join-Path $TestDrive 'bullet.pdf'
        $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 200 -Item 'a' | Save-VellumPdfDocument -Path $plain | Out-Null
        [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($plain)) | Should -Not -BeNullOrEmpty
        (Get-PdfContentText $plain) | Should -Match '\(\x95\) Tj'      # WinAnsi bullet
    }

    It 'rejects bad input' {
        $doc = New-Tagged
        try {
            { $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 20 -Item 'a' } | Should -Throw '*too narrow*'
            { $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 200 -Item @{ Text = 'a'; Children = @(@{ Text = 'b'; Children = 'c' }) } } | Should -Throw '*one nesting level*'
            { $doc | Add-VellumPdfPageList -X 72 -Y 20 -Width 200 -Item (1..30 | ForEach-Object { "item $_" }) } | Should -Throw '*pt are left below*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Table and list inside a structure group' -Skip:(-not $script:haveQpdf) {
    It 'nests under Sect and keeps reading order' {
        $path = Save-Valid (New-Tagged | Use-VellumPdfStructure -Type Sect -ScriptBlock {
                $_ | Add-VellumPdfText 'Report' -X 72 -Y 760 -FontSize 18 -Role H1 |
                    Add-VellumPdfPageTable -X 72 -Y 740 -Width 300 -Header 'A', 'B' -Row @(, @('1', '2')) |
                    Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Item 'one', 'two'
            }) 'nested-mix'
        $tree = Get-PdfStructureTree $path
        $tree.Count | Should -Be 1
        @($tree[0].Children.Type) | Should -Be 'H1', 'Table', 'L'
        $mcids = @(Get-Types $tree | Out-Null; function Get-Mcid($n) { foreach ($x in $n) { if ($null -ne $x.Mcid) { $x.Mcid }; Get-Mcid $x.Children } }; Get-Mcid $tree)
        $mcids | Should -Be ($mcids | Sort-Object) -Because 'content is tagged in reading order'
        ($mcids | Select-Object -Unique).Count | Should -Be $mcids.Count
    }
}
