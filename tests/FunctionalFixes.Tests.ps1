#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Functional fixes from the review: word spacing with embedded fonts, document default font reaching every
# element, spans in table alignment, text box edge cases, page scopes, page band overflow and canvas balance.

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    function script:New-Page([hashtable]$DocParams = @{ Language = 'en' }) { New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage }
    function script:Save-It($Doc, [string]$Name) { $p = Join-Path $TestDrive "$Name.pdf"; $Doc | Save-VellumPdfDocument -Path $p | Out-Null; $p }
    # Right edge of the dark pixels of page 1 in points, or $null when no renderer is installed.
    function script:Get-InkRight([string]$Pdf) {
        if (-not (Get-Command pdftoppm -ErrorAction SilentlyContinue) -or -not (Get-Command convert -ErrorAction SilentlyContinue)) { return $null }
        $base = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & pdftoppm -r 72 -png -f 1 -l 1 $Pdf $base
        $png = Get-ChildItem "$base*.png" | Select-Object -First 1
        $geometry = (& convert $png.FullName -fuzz 10% -trim -format '%w %X' info:) -split ' '
        # %X prints "+offset"; width + offset is the right edge in pixels (72 dpi: pixels = points).
        [double]$geometry[0] + [double]($geometry[1] -replace '^\+', '')
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Word spacing with an embedded font' {
    It 'places the words one by one, keeps right alignment, and writes no Tw operator' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm 211.67 -PageHeightMm 70.6
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $pdf = Save-It ($doc | Add-VellumPdfText 'A B C D E F' -X 400 -Y 100 -FontSize 20 -WordSpacing 30 -Align Right -FontHandle $font) 'tw-emb'
        $content = Get-PdfContentText $pdf
        $content | Should -Not -Match '(?m)^[-\d.]+ Tw$'
        ([regex]::Matches($content, '<[0-9A-F]+> Tj')).Count | Should -Be 6
        $right = Get-InkRight $pdf
        if ($null -ne $right) { $right | Should -BeGreaterThan 395; $right | Should -BeLessThan 405 }
    }

    It 'still uses Tw for a base-14 font' {
        $pdf = Save-It (New-Page | Add-VellumPdfText 'A B C' -X 100 -Y 100 -WordSpacing 12) 'tw-std'
        Get-PdfContentText $pdf | Should -Match '(?m)^12 Tw$'
    }
}

Describe 'The document default font reaches every element' {
    It 'draws lists, table cells, bands and runs in the default font and size' {
        $doc = New-VellumPdfDocument -DefaultFont Courier -DefaultFontSize 14
        $pdf = Save-It ($doc | Add-VellumPdfParagraph -Text 'PARA' |
                Add-VellumPdfList -Item 'LISTITEM' |
                Add-VellumPdfTable -Header 'H1' -Row @(, @('CELL1')) |
                Add-VellumPdfParagraph -Run (New-VellumPdfTextRun -Text 'RUNTEXT') |
                Add-VellumPdfParagraph -Run (New-VellumPdfTextRun -Text 'BOLDRUN' -Font HelveticaBold -FontSize 9) |
                Set-VellumPdfHeader -Template 'HDR {page}' | Set-VellumPdfFooter -Template 'FTR {page}') 'default-font'
        $text = Get-PdfText $pdf
        $content = Get-PdfContentText $pdf
        foreach ($word in 'PARA', 'LISTITEM', 'H1', 'CELL1', 'RUNTEXT', 'HDR 1', 'FTR 1') {
            $content | Should -Match "/F\d+ 14 Tf[^(]*\($word\) Tj" -Because "$word should use the 14 pt default"
        }
        $content | Should -Match '/F\d+ 9 Tf[^(]*\(BOLDRUN\) Tj'
        $text | Should -Match '/BaseFont\s*/Courier\b'
        $text | Should -Match '/BaseFont\s*/Helvetica-Bold'
        $text | Should -Not -Match '/BaseFont\s*/Helvetica\b(?!-)'
    }
}

Describe 'Table columns follow ColSpan and RowSpan' {
    It 'aligns cells by their grid column' {
        $doc = New-VellumPdfDocument
        $pdf = Save-It ($doc | Add-VellumPdfTable -Header 'Item', 'Qty', 'Price' -ColumnAlignment Left, Left, Right -ColumnWidth 150, 150, 150 -Row @(
                @('Widget', '2', '10.00'),
                @(@{ Text = 'Shipping'; ColSpan = 2 }, '5.00'),
                @(@{ Text = 'Rowspan'; RowSpan = 2 }, 'x', 'y'),
                @('p', 'q'))) 'spans'
        $x = @{}
        foreach ($m in [regex]::Matches((Get-PdfContentText $pdf), '1 0 0 1 ([\d.]+) [\d.]+ Tm\r?\n\(([^)]*)\) Tj')) { $x[$m.Groups[2].Value] = [double]$m.Groups[1].Value }
        $x['5.00'] | Should -BeGreaterThan 450      # right aligned in column 3, not left aligned in column 2
        $x['10.00'] | Should -BeGreaterThan 450
        $x['p'] | Should -BeLessThan 300             # the row-spanned first column pushes p to column 2, not column 1
        $x['p'] | Should -Be $x['x']
        $x['q'] | Should -BeGreaterThan 450
    }

    It 'counts grid columns for the -ColumnWidth warning' {
        $w = $null
        $null = New-VellumPdfDocument | Add-VellumPdfTable -Header @(@{ Text = 'Wide'; ColSpan = 2 }) -Row @(, @('a', 'b')) -ColumnWidth 100, 100 -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -BeNullOrEmpty
    }
}

Describe 'Text box edge cases' {
    It 'keeps a no-break space inside a word' {
        $pdf = Save-It (New-Page | Add-VellumPdfTextBox "aaaa 100$([char]0x00A0)km" -X 10 -Y 500 -Width 41) 'nbsp'
        $strings = [regex]::Matches((Get-PdfContentText $pdf), '\(([^)]*)\) Tj') | ForEach-Object { $_.Groups[1].Value }
        ($strings | Where-Object { $_ -match 'km' }) | Should -Match "100.km"
        ($strings | Where-Object { $_ -match 'km' }) | Should -Not -Match '^km$'
    }

    It 'fits an exact multiple of the leading and draws nothing under one line' {
        $doc = New-Page
        $info = $doc | Add-VellumPdfTextBox ((1..7 | ForEach-Object { "w$_" }) -join "`n") -X 10 -Y 700 -Width 100 -FontSize 7 -MaxHeight 58.8 -PassThru -WarningAction SilentlyContinue
        $info.LineCount | Should -Be 7
        $w = $null
        $none = $doc | Add-VellumPdfTextBox 'text' -X 10 -Y 500 -Width 100 -MaxHeight 5 -PassThru -WarningVariable w -WarningAction SilentlyContinue
        $none.LineCount | Should -Be 0
        "$w" | Should -Match 'fits 0'
        $doc.Dispose()
    }
}

Describe 'Scopes carry their page' {
    It 'draws inside a clip on the clip page when -Page is not repeated, and warns when it differs' {
        $doc = New-Page
        $doc = $doc | Add-VellumPdfPage
        $w = $null
        $pdfPath = Save-It ($doc | Use-VellumPdfClip -Page 2 -X 10 -Y 10 -Width 50 -Height 50 -ScriptBlock {
                $_ | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 200 -Height 200 -FillColor green
                $_ | Add-VellumPdfShape Rectangle -Page 1 -X 0 -Y 0 -Width 5 -Height 5 -FillColor red -WarningVariable w -WarningAction SilentlyContinue
            }) 'clip-page'
        # Page 1 holds only the red rectangle, page 2 the clipped green one.
        $content = Get-PdfContentText $pdfPath
        $content | Should -Match '(?s)0 0\.5 0 rg\r?\n0 0 200 200 re'
        $content | Should -Match '(?s)W\r?\nn\r?\n.*0 0\.5 0 rg'
        "$w" | Should -Match 'differs from the enclosing scope'
    }
}

Describe 'Page bands wider than the page' {
    It 'warns once per band when the text runs off the page' {
        $w = $null
        $doc = New-Page | Add-VellumPdfPage | Set-VellumPdfPageBand Footer ('Very long footer text ' * 12) -Font Helvetica
        $null = $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'wide-band.pdf') -WarningVariable w -WarningAction SilentlyContinue
        @($w | Where-Object { "$_" -match 'runs off the page' }).Count | Should -Be 1
    }
}

Describe 'Invoke-VellumPdfCanvas keeps the graphics state balanced' {
    It 'refuses to save a document whose script block saved more than it restored' {
        $doc = New-Page
        $doc | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.SaveState().Rectangle(0, 0, 5, 5).Clip().EndPath() | Out-Null } | Out-Null
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'unbalanced.pdf') } | Should -Throw '*saved and restored the graphics state unevenly*'
        $doc.Dispose()
    }

    It 'accepts balanced use, including q and Q inside strings' {
        $pdf = Save-It (New-Page | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.SaveState().Rectangle(0, 0, 5, 5).Fill().RestoreState() | Out-Null } |
                Add-VellumPdfText '(q Q) Q q' -X 10 -Y 10) 'balanced'
        Test-Path $pdf | Should -BeTrue
    }

    It 'scans operators, strings, comments and inline images correctly' {
        $scan = { param([string]$s) [PSVellumPDF.Interop.ContentStreamBalance]::Scan([System.Text.Encoding]::Latin1.GetBytes($s)) }
        (& $scan "q 1 0 0 1 0 0 cm Q").FinalDepth | Should -Be 0
        (& $scan "q q Q").FinalDepth | Should -Be 1
        (& $scan "Q").MinDepth | Should -Be -1
        (& $scan "(q Q \) q) Tj % q q`nq Q").FinalDepth | Should -Be 0
        (& $scan "<7120> Tj /Q /q q Q").FinalDepth | Should -Be 0
        (& $scan "q BI /W 1 /H 1 ID q Q q EI Q").FinalDepth | Should -Be 0
    }
}

Describe 'Numeric validation messages' {
    It 'explains a NaN font size' {
        { New-Page | Add-VellumPdfText 'x' -X 1 -Y 1 -FontSize ([double]::NaN) } | Should -Throw '*NaN*'
    }
}
