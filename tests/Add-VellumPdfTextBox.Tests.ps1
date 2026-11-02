#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'

    # Page content split into the text lines the cmdlet drew: one entry per BT..ET block.
    function script:Get-DrawnLines([string]$Path) {
        $content = Get-PdfContentText $Path
        foreach ($m in [regex]::Matches($content, '(?s)BT\r?\n(.*?)ET')) {
            $parts = [regex]::Matches($m.Groups[1].Value, '1 0 0 1 (-?[\d.]+) (-?[\d.]+) Tm\r?\n\((.*?)\) Tj')
            [pscustomobject]@{
                Text = (($parts | ForEach-Object { $_.Groups[3].Value.TrimEnd() }) -join ' ')
                X    = [double]$parts[0].Groups[1].Value
                Y    = [double]$parts[0].Groups[2].Value
                XEnd = [double]$parts[-1].Groups[1].Value
            }
        }
    }
    function script:Save-Box([scriptblock]$Build, [hashtable]$DocParams = @{ Language = 'en' }) {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.pdf')
        $doc = New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage
        $doc = & $Build $doc
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        $path
    }
    $script:lorem = 'The quick brown fox jumps over the lazy dog and keeps running through the forest until night falls.'
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfTextBox' {
    It 'wraps text so that no line is wider than the column and keeps every word in order' {
        $path = Save-Box { param($d) $d | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 150 }
        $lines = @(Get-DrawnLines $path)
        $lines.Count | Should -BeGreaterThan 3
        ($lines.Text -join ' ') | Should -Be $script:lorem
        $probe = New-VellumPdfPageDocument
        try {
            $helv = $probe.UseFont([VellumPdf.Fonts.Standard14]::Helvetica)
            foreach ($l in $lines) { $helv.MeasureString($l.Text, 12) | Should -BeLessOrEqual 150.01 }
        }
        finally { $probe.Dispose() }
        $lines[0].Y | Should -Be 688           # one font size below the top
        ($lines[1].Y - $lines[0].Y) | Should -BeLessThan 0
        [Math]::Round($lines[0].Y - $lines[1].Y, 3) | Should -Be 14.4   # default leading 1.2 x 12
    }

    It 'honours -Leading, paragraph breaks and blank lines' {
        $path = Save-Box { param($d) $d | Add-VellumPdfTextBox "one`ntwo`n`nfour" -X 10 -Y 500 -Width 300 -Leading 20 }
        $lines = @(Get-DrawnLines $path)
        $lines.Text | Should -Be 'one', 'two', 'four'
        $lines.Y | Should -Be 488, 468, 428    # the empty third line still takes its space
    }

    It 'returns the document, or a summary with -PassThru' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            $plain = $doc | Add-VellumPdfTextBox 'a b c' -X 0 -Y 100 -Width 100
            $plain | Should -BeOfType ([VellumPdf.Document.PdfDocument])
            $info = $doc | Add-VellumPdfTextBox "one`ntwo" -X 0 -Y 100 -Width 100 -Leading 10 -FontSize 8 -PassThru
            $info.Document | Should -BeOfType ([VellumPdf.Document.PdfDocument])
            $info.LineCount | Should -Be 2
            $info.Height | Should -Be 20
            $info.Bottom | Should -Be 80
        }
        finally { $doc.Dispose() }
    }

    It 'centres and right-aligns lines about the column' {
        $pathR = Save-Box { param($d) $d | Add-VellumPdfTextBox 'right' -X 100 -Y 300 -Width 200 -Align Right }
        $pathC = Save-Box { param($d) $d | Add-VellumPdfTextBox 'mid' -X 100 -Y 300 -Width 200 -Align Center }
        $probe = New-VellumPdfPageDocument
        try {
            $helv = $probe.UseFont([VellumPdf.Fonts.Standard14]::Helvetica)
            [Math]::Round((Get-DrawnLines $pathR).X, 2) | Should -Be ([Math]::Round(300 - $helv.MeasureString('right', 12), 2))
            [Math]::Round((Get-DrawnLines $pathC).X, 2) | Should -Be ([Math]::Round(200 - $helv.MeasureString('mid', 12) / 2, 2))
        }
        finally { $probe.Dispose() }
    }

    It 'justifies every line but the last of a paragraph to the full column width' {
        $path = Save-Box { param($d) $d | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 150 -Align Justify }
        $lines = @(Get-DrawnLines $path)
        $probe = New-VellumPdfPageDocument
        try {
            $helv = $probe.UseFont([VellumPdf.Fonts.Standard14]::Helvetica)
            $multiWord = @($lines[0..($lines.Count - 2)] | Where-Object { $_.Text -match ' ' })
            $multiWord.Count | Should -BeGreaterThan 0
            foreach ($l in $multiWord) {
                $last = ($l.Text -split ' ')[-1]
                ($l.XEnd + $helv.MeasureString($last, 12)) | Should -BeGreaterThan (72 + 150 - 0.05)
                ($l.XEnd + $helv.MeasureString($last, 12)) | Should -BeLessThan (72 + 150 + 0.05)
            }
            # The last line stays ragged.
            $final = $lines[-1]
            ($final.XEnd + $helv.MeasureString(($final.Text -split ' ')[-1], 12)) | Should -BeLessThan (72 + 150 - 1)
        }
        finally { $probe.Dispose() }
    }

    It 'keeps the spaces between words when text is extracted from justified lines' {
        $path = Save-Box { param($d) $d | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 150 -Align Justify }
        $extracted = (Get-VellumPdfText -Path $path) -join ' '
        ($extracted -split '\s+' | Where-Object { $_ }) | Should -Be ($script:lorem -split ' ')
    }

    It 'ends every justified word but the last of a line with a space glyph in an embedded font' {
        # Reader's preview extraction skips embedded (CID) fonts, so check the glyph runs themselves.
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $path = Join-Path $TestDrive 'justify-emb.pdf'
        $doc | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 150 -Align Justify -FontHandle $font |
            Save-VellumPdfDocument -Path $path | Out-Null
        $firstLine = [regex]::Match((Get-PdfContentText $path), '(?s)BT\r?\n(.*?)ET').Groups[1].Value
        $runs = @([regex]::Matches($firstLine, '<([0-9A-F]+)> Tj') | ForEach-Object { $_.Groups[1].Value })
        $runs.Count | Should -BeGreaterThan 2
        foreach ($run in $runs[0..($runs.Count - 2)]) { $run | Should -Match '0003$' }
        $runs[-1] | Should -Not -Match '0003$'
    }

    It 'splits a word that is wider than the column' {
        $path = Save-Box { param($d) $d | Add-VellumPdfTextBox ('W' * 40) -X 10 -Y 300 -Width 100 }
        $lines = @(Get-DrawnLines $path)
        $lines.Count | Should -BeGreaterThan 3
        ($lines.Text -join '') | Should -Be ('W' * 40)
    }

    It 'drops lines beyond -MaxHeight with a warning' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            $info = $doc | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 100 -MaxHeight 30 -Leading 14 -PassThru -WarningVariable w -WarningAction SilentlyContinue
            $info.LineCount | Should -Be 2
            "$w" | Should -Match 'fits 2'
        }
        finally { $doc.Dispose() }
    }

    It 'draws Unicode text in an embedded font' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $path = Join-Path $TestDrive 'emb.pdf'
        $doc | Add-VellumPdfTextBox "Zażółć gęślą jaźń $($script:lorem)" -X 72 -Y 700 -Width 180 -FontHandle $font -Align Justify |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-PdfText $path) | Should -Match '/FontFile2'
        (Get-PdfContentText $path) | Should -Match '(?s)BT.*ET'
    }

    It 'rejects bad input' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfTextBox 'x' -X 0 -Y 0 -Width 0 -ErrorAction Stop } | Should -Throw
            { $doc | Add-VellumPdfTextBox 'x' -X ([double]::NaN) -Y 0 -Width 10 -ErrorAction Stop } | Should -Throw '*finite*'
        }
        finally { $doc.Dispose() }
    }

    It 'is one structure element in a PDF/UA-1 document and passes the PDF/A-2b and PDF/UA-1 preflights' {
        $ua = Join-Path $TestDrive 'box-ua.pdf'
        New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US | Add-VellumPdfPage |
            Set-VellumPdfDocumentInfo -Title 'Box' |
            Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 200 -Language en-GB -Align Justify |
            Save-VellumPdfDocument -Path $ua | Out-Null
        (Test-VellumPdfConformance -Path $ua -Profile PdfUA1).IsCompliant | Should -BeTrue
        $content = Get-PdfContentText $ua
        ([regex]::Matches($content, '/P <</MCID \d+>> BDC|/P <</MCID \d+>>BDC')).Count | Should -Be 1
        ([regex]::Matches($content, '(?m)^BT')).Count | Should -BeGreaterOrEqual 3

        $a2b = Save-Box { param($d) $d | Add-VellumPdfTextBox $script:lorem -X 72 -Y 700 -Width 200 -Font TimesRoman } @{ Conformance = 'PdfA2b'; Language = 'en' }
        (Test-VellumPdfConformance -Path $a2b -Profile PdfA2b).IsCompliant | Should -BeTrue
    }
}
