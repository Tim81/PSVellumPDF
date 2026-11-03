#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Regression tests for review findings on the page-document cmdlets: page lists and tables with unusual input,
# structure type spelling, tabs, text box overflow, alignment with character spacing, use after -KeepOpen,
# Add-VellumPdfPage -PassThru and the raw-canvas balance check.

param()

BeforeDiscovery {
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)
    # The word-box tests parse poppler's 'pdftotext -bbox'. The Windows runner has a pdftotext that is not poppler's
    # (no -bbox output), so require poppler, not just a command of that name.
    $script:havePdftotext = [bool](Get-Command pdftotext -ErrorAction SilentlyContinue) -and
        ((& pdftotext -v 2>&1 | Out-String) -match 'poppler')
}

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    function script:New-Page { New-VellumPdfPageDocument | Add-VellumPdfPage }
    function script:New-Tagged([string]$Conformance = 'PdfUA1') {
        New-VellumPdfPageDocument -Conformance $Conformance -Language en-US | Add-VellumPdfPage | Set-VellumPdfDocumentInfo -Title 'Review fixes'
    }
    # Words with their x extent, from pdftotext -bbox.
    function script:Get-WordBox([string]$Path) {
        $html = (& pdftotext -bbox $Path - 2>$null) -join "`n"
        foreach ($m in [regex]::Matches($html, '<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>')) {
            [pscustomobject]@{ XMin = [double]$m.Groups[1].Value; XMax = [double]$m.Groups[3].Value; Text = $m.Groups[5].Value }
        }
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfPageList items' {
    It 'treats a missing Children as no children (finding 1)' {
        $doc = New-Page
        try {
            $r = $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Numbered -PassThru -Item @(@{ Text = 'first' }, @{ Text = 'second' })
            $r.ItemCount | Should -Be 2
            $r2 = $doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -PassThru -Item @(@{ Text = 'a'; Children = $null }, @{ Text = 'b'; Children = @() })
            $r2.ItemCount | Should -Be 2
        }
        finally { $doc.Dispose() }
    }

    It 'reads Text and Children from an object, and refuses an item without Text' {
        $doc = New-Page
        try {
            $r = $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -PassThru -Item ([pscustomobject]@{ Text = 'parent'; Children = 'x', 'y' }), 'plain'
            $r.ItemCount | Should -Be 4
            { $doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Item @{ Txt = 'typo' } } | Should -Throw '*has no Text*'
            { $doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Item @{ Text = 'ok'; Children = @(@{ Name = 'x' }) } } | Should -Throw '*has no Text*'
        }
        finally { $doc.Dispose() }
    }

    It 'draws the object item as its text, not as a literal hashtable dump' -Skip:(-not $script:havePdftotext) {
        $doc = New-Page
        $p = Join-Path $TestDrive 'list-object.pdf'
        $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item ([pscustomobject]@{ Text = 'parent'; Children = 'child' }) | Save-VellumPdfDocument -Path $p | Out-Null
        $text = (& pdftotext $p - 2>$null) -join "`n"
        $text | Should -Match 'parent'
        $text | Should -Not -Match '@\{'
    }

    It 'accepts a large -FontSize whose computed marker column exceeds the -Indent range (finding 2)' {
        $doc = New-Page
        try {
            $r = $doc | Add-VellumPdfPageList -X 10 -Y 830 -Width 3000 -FontSize 600 -Item 'a' -PassThru
            $r.ItemCount | Should -Be 1
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfPageTable edge cases' {
    It 'draws a row that RowSpans from above cover completely (finding 3)' {
        $rows = @(@(@{ Text = 'x'; RowSpan = 2 }, @{ Text = 'y'; RowSpan = 2 }), @(), @('c', 'd'))
        $doc = New-Page
        try {
            $r = $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 200 -Header 'A', 'B' -Row $rows -PassThru
            $r.Rows | Should -Be 4
            $r.Columns | Should -Be 2
        }
        finally { $doc.Dispose() }
    }

    It 'writes valid PDF/UA structure for it, keeping a TR for the covered row' -Skip:(-not $script:haveQpdf) {
        $rows = @(@(@{ Text = 'x'; RowSpan = 2 }, @{ Text = 'y'; RowSpan = 2 }), @(), @('c', 'd'))
        $p = Join-Path $TestDrive 'covered-row.pdf'
        New-Tagged | Add-VellumPdfPageTable -X 72 -Y 700 -Width 200 -Header 'A', 'B' -Row $rows | Save-VellumPdfDocument -Path $p -Validate | Out-Null
        (Test-VellumPdfConformance -Path $p -Profile PdfUA1).IsCompliant | Should -BeTrue
        $table = (Get-PdfStructureTree $p)[0]
        $table.Type | Should -Be 'Table'
        @($table.Children.Type) | Should -Be 'TR', 'TR', 'TR', 'TR'
        @($table.Children | ForEach-Object { $_.Children.Count }) | Should -Be 2, 2, 0, 2
    }

    It 'validates a non-numeric ColSpan before converting it' {
        $doc = New-Page
        try {
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 200 -Header 'A', 'B' -Row @(, @(@{ Text = 'x'; ColSpan = 'two' }, 'y')) } |
                Should -Throw '*ColSpan must be a whole number*'
            { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 200 -Header @{ Text = 'h'; ColSpan = 'two' } -Row @() } |
                Should -Throw '*ColSpan must be a whole number*'
        }
        finally { $doc.Dispose() }
    }

    It 'allows a header-only table, and says what is missing when there is nothing' {
        $doc = New-Page
        try {
            ($doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 200 -Header 'A', 'B' -Row @() -PassThru).Rows | Should -Be 1
            ($doc | Add-VellumPdfPageTable -X 72 -Y 600 -Width 200 -Header 'A', 'B' -PassThru).Rows | Should -Be 1
            { $doc | Add-VellumPdfPageTable -X 72 -Y 500 -Width 200 -Row @() } | Should -Throw '*give at least one -Row*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Structure type spelling (finding 4)' -Skip:(-not $script:haveQpdf) {
    It 'writes the canonical type for -Type sect and -Role h1' {
        $p = Join-Path $TestDrive 'case.pdf'
        New-Tagged | Use-VellumPdfStructure -Type sect -ScriptBlock {
            $_ | Add-VellumPdfText 'Heading' -X 72 -Y 760 -FontSize 18 -Role h1 |
                Add-VellumPdfTextBox 'Caption text' -X 72 -Y 700 -Width 200 -Role caption
        } | Save-VellumPdfDocument -Path $p -Validate | Out-Null
        $tree = Get-PdfStructureTree $p
        $tree[0].Type | Should -Be 'Sect'
        @($tree[0].Children.Type) | Should -Be 'H1', 'Caption'
    }
}

Describe 'Tabs in page text (finding 5)' {
    It 'expands a tab to four spaces in Measure-VellumPdfText' {
        $tab = (Measure-VellumPdfText "a`tb").Width
        $spaces = (Measure-VellumPdfText 'a    b').Width
        $tab | Should -Be $spaces
        (Measure-VellumPdfText "`t").Width | Should -BeGreaterThan 0
    }

    It 'draws a tab in Add-VellumPdfText, Add-VellumPdfTextBox and a page band as spaces, valid for PDF/A' -Skip:(-not $script:haveQpdf) {
        $font = $null
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b | Add-VellumPdfPage
        $font = $doc | Register-VellumPdfFont -Path $script:fontPath
        $p = Join-Path $TestDrive 'tabs.pdf'
        $doc | Add-VellumPdfText "one`ttwo" -X 72 -Y 700 -FontHandle $font |
            Add-VellumPdfTextBox "three`tfour" -X 72 -Y 650 -Width 300 -FontHandle $font |
            Set-VellumPdfPageBand Footer "left`tright" -FontHandle $font |
            Save-VellumPdfDocument -Path $p -Validate | Out-Null
        Test-Path $p | Should -BeTrue
    }

    It 'leaves a visible gap of four spaces and aligns by the width that is drawn' -Skip:(-not $script:havePdftotext) {
        $text = "ab`tcd"
        $width = (Measure-VellumPdfText $text -FontSize 20).Width
        $p = Join-Path $TestDrive 'tab-right.pdf'
        New-Page | Add-VellumPdfText $text -X 400 -Y 700 -FontSize 20 -Align Right | Save-VellumPdfDocument -Path $p | Out-Null
        $words = @(Get-WordBox $p)
        $words.Count | Should -Be 2
        ($words[1].XMin - $words[0].XMax) | Should -BeGreaterThan 15 -Because 'four Helvetica spaces at 20 pt are 22 pt wide'
        $words[1].XMax | Should -BeGreaterThan 395
        $words[1].XMax | Should -BeLessThan 401
        $words[0].XMin | Should -BeGreaterThan (400 - $width - 1)
        $words[0].XMin | Should -BeLessThan (400 - $width + 3)
    }
}

Describe 'Add-VellumPdfTextBox overflow (finding 6)' {
    It 'throws when the text would run below the bottom of the page' {
        $doc = New-Page
        try {
            $text = (1..2000 | ForEach-Object { 'word' }) -join ' '
            { $doc | Add-VellumPdfTextBox $text -X 72 -Y 100 -Width 400 } | Should -Throw '*pt are left below -Y*'
        }
        finally { $doc.Dispose() }
    }

    It 'still draws a box that fits, and -MaxHeight still cuts off with a warning' {
        $doc = New-Page
        try {
            $text = (1..2000 | ForEach-Object { 'word' }) -join ' '
            ($doc | Add-VellumPdfTextBox 'short' -X 72 -Y 100 -Width 400 -PassThru).LineCount | Should -Be 1
            $r = $doc | Add-VellumPdfTextBox $text -X 72 -Y 100 -Width 400 -MaxHeight 60 -PassThru -WarningAction SilentlyContinue
            $r.Bottom | Should -BeGreaterThan 0
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Alignment with -CharSpacing (finding 7)' -Skip:(-not $script:havePdftotext) {
    It 'ends right-aligned text at X and centres on the visible glyphs' {
        $p = Join-Path $TestDrive 'charspacing.pdf'
        # Right-aligned at x 400 (y 700) and centred on x 300 (y 600).
        New-Page | Add-VellumPdfText 'Hello' -X 400 -Y 700 -FontSize 20 -CharSpacing 20 -Align Right |
            Add-VellumPdfText 'Hello' -X 300 -Y 600 -FontSize 20 -CharSpacing 20 -Align Center |
            Save-VellumPdfDocument -Path $p | Out-Null
        $html = (& pdftotext -bbox $p - 2>$null) -join "`n"
        # pdftotext reports each widely spaced letter as a word: take the extent of each line (grouped by yMin).
        $lines = [regex]::Matches($html, '<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="[\d.]+">') |
            Group-Object { $_.Groups[2].Value } | Sort-Object { [double]$_.Name }
        $lines.Count | Should -Be 2
        # pdftotext measures y from the top: the first group is y 700 (right-aligned), the second y 600 (centred).
        $right = $lines[0].Group; $centred = $lines[1].Group
        $rightEnd = ($right | ForEach-Object { [double]$_.Groups[3].Value } | Measure-Object -Maximum).Maximum
        # A glyph's advance is wider than its ink, so allow a few points of sidebearing; the old code was 20 pt short.
        $rightEnd | Should -BeGreaterThan 396
        $rightEnd | Should -BeLessThan 401
        $left = ($centred | ForEach-Object { [double]$_.Groups[1].Value } | Measure-Object -Minimum).Minimum
        $end = ($centred | ForEach-Object { [double]$_.Groups[3].Value } | Measure-Object -Maximum).Maximum
        [math]::Abs((($left + $end) / 2) - 300) | Should -BeLessThan 3
    }

    It 'keeps Measure-VellumPdfText as the advance width including the trailing spacing' {
        $plain = (Measure-VellumPdfText 'Hello' -FontSize 20).Width
        (Measure-VellumPdfText 'Hello' -FontSize 20 -CharSpacing 20).Width | Should -Be ($plain + 100)
    }
}

Describe 'Use after a -KeepOpen save (finding 8)' {
    It 'refuses to draw on a saved page document, and does not call it a layout document' {
        $doc = New-Page
        try {
            $doc | Add-VellumPdfText 'first' -X 72 -Y 700 | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'kept.pdf') -KeepOpen | Out-Null
            { $doc | Add-VellumPdfText 'more' -X 72 -Y 600 } | Should -Throw '*already saved*'
            { $doc | Add-VellumPdfTextBox 'more' -X 72 -Y 600 -Width 100 } | Should -Throw '*already saved*'
            { $doc | Add-VellumPdfPage } | Should -Throw '*already saved*'
            { $doc | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $null = $c } } | Should -Throw '*already saved*'
            $message = try { $doc | Add-VellumPdfText 'more' -X 72 -Y 600 } catch { $_.Exception.Message }
            $message | Should -Not -Match 'layout document'
            $message | Should -Match 'New-VellumPdfPageDocument'
            $again = try { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'twice.pdf') -KeepOpen } catch { $_.Exception.Message }
            "$again" | Should -Not -Match 'layout document'
            "$again" | Should -Match 'already saved'
        }
        finally { $doc.Dispose() }
    }

    It 'explains that -KeepOpen is for inspection after a normal save' {
        $doc = New-Page
        $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'normal.pdf') | Out-Null
        $message = try { $doc | Add-VellumPdfText 'x' -X 1 -Y 1 } catch { $_.Exception.Message }
        $message | Should -Match 'already saved and disposed'
        $message | Should -Not -Match 'to keep working with it'
        $message | Should -Match 'inspection only'
    }
}

Describe 'Add-VellumPdfPage -PassThru (finding 9)' {
    It 'returns every page added with -Count' {
        $doc = New-VellumPdfPageDocument
        try {
            $pages = @($doc | Add-VellumPdfPage -Count 3 -PassThru)
            $pages.Count | Should -Be 3
            $pages[0] | Should -BeOfType ([VellumPdf.Document.PdfPage])
            $doc.Pages.Count | Should -Be 3
            [object]::ReferenceEquals($pages[0], $pages[2]) | Should -BeFalse
            [object]::ReferenceEquals($pages[2], $doc.Pages[2]) | Should -BeTrue
            ($doc | Add-VellumPdfPage -PassThru) | Should -BeOfType ([VellumPdf.Document.PdfPage])
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Raw canvas balance beyond q/Q (finding 10)' {
    It 'scans BT/ET and BMC|BDC/EMC without mistaking strings, names or comments for operators' {
        $scan = { param([string]$s) [PSVellumPDF.Interop.ContentStreamBalance]::Scan([System.Text.Encoding]::Latin1.GetBytes($s)) }
        (& $scan 'BT /F1 12 Tf (BT ET EMC) Tj ET /Span <</MCID 0>> BDC EMC /Tag BMC EMC % BT').IsBalanced | Should -BeTrue
        (& $scan 'q BI /W 1 /H 1 ID BT EMC EI Q').IsBalanced | Should -BeTrue
        (& $scan 'BT').TextFinalDepth | Should -Be 1
        (& $scan 'ET').TextMinDepth | Should -Be -1
        (& $scan '/P BMC').MarkedFinalDepth | Should -Be 1
        (& $scan 'EMC').MarkedMinDepth | Should -Be -1
        (& $scan 'BT ET').Describe() | Should -Be ''
        (& $scan 'BT').Describe() | Should -Match 'BT/ET'
        (& $scan 'EMC').Describe() | Should -Match 'EMC'
    }

    It 'refuses an extra EndMarkedContent in a tagged document, naming the operator' -Skip:(-not $script:haveQpdf) {
        $doc = New-Tagged
        $doc | Add-VellumPdfText 'tagged' -X 72 -Y 700 | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.EndMarkedContent() | Out-Null } | Out-Null
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'extra-emc.pdf') } | Should -Throw '*BMC|BDC/EMC*'
        $doc.Dispose()
    }

    It 'refuses a text object that is left open' {
        $doc = New-Page
        $doc | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.BeginText() | Out-Null } | Out-Null
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'open-bt.pdf') } | Should -Throw '*BT/ET*'
        $doc.Dispose()
    }

    It 'accepts a balanced raw text object' {
        $doc = New-Page
        $doc | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.BeginText().EndText() | Out-Null } | Out-Null
        $p = Join-Path $TestDrive 'ok-bt.pdf'
        $doc | Save-VellumPdfDocument -Path $p | Out-Null
        Test-Path $p | Should -BeTrue
    }
}
