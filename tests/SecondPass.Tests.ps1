#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Regression tests for the second review pass: failures leave a consistent structure tree, bad text and fonts
# are refused before drawing, tables and lists check their input up front, and the image export handles
# CCITT without end-of-line codes.

param()

BeforeDiscovery {
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)
    $script:render = [bool]((Get-Command pdftoppm -ErrorAction SilentlyContinue) -and (Get-Command convert -ErrorAction SilentlyContinue) -and ((& convert -version 2>&1 | Out-String) -match 'ImageMagick'))   # Windows has its own unrelated convert.exe
}

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:assets = Join-Path $PSScriptRoot 'assets'
    $script:fontPath = Join-Path $script:assets 'DejaVuSans.ttf'
    $script:lone = [string][char]0xD800
    function script:New-Tagged { New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US | Add-VellumPdfPage | Set-VellumPdfDocumentInfo -Title 'Second pass' }
    function script:Get-Mcid([string]$Content) { @([regex]::Matches($Content, '/MCID (\d+)') | ForEach-Object { [int]$_.Groups[1].Value }) }
    function script:Get-TreeMcid($Nodes) { foreach ($n in $Nodes) { if ($null -ne $n.Mcid) { $n.Mcid }; Get-TreeMcid $n.Children } }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'A failure after some content was tagged keeps the structure tree consistent' -Skip:(-not $script:haveQpdf) {
    It 'registers what Use-VellumPdfStructure tagged before its block threw' {
        $doc = New-Tagged
        { $doc | Use-VellumPdfStructure -Type Art -ScriptBlock { $_ | Add-VellumPdfText 'before' -X 72 -Y 700; throw 'boom' } } | Should -Throw '*boom*'
        $pdf = Join-Path $TestDrive 'failed-scope.pdf'
        $doc | Add-VellumPdfText 'after' -X 72 -Y 600 | Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        $tree = Get-PdfStructureTree $pdf
        @($tree.Type) | Should -Be 'Art', 'P'
        @(Get-TreeMcid $tree | Sort-Object) | Should -Be @(Get-Mcid (Get-PdfContentText $pdf) | Sort-Object) -Because 'every MCID in the page is owned by a structure element'
    }

    It 'refuses a bad cell colour before anything is drawn' {
        $doc = New-Tagged
        { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(, @('first', @{ Text = 'second'; Color = 'nocolor' })) } | Should -Throw '*colour*'
        { $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(, @(@{ Text = 'x'; Background = 'nocolor' })) } | Should -Throw '*colour*'
        $pdf = Join-Path $TestDrive 'bad-colour.pdf'
        $doc | Add-VellumPdfText 'after' -X 72 -Y 600 | Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        (Get-PdfContentText $pdf) | Should -Not -Match '/TD <<'
        @((Get-PdfStructureTree $pdf).Type) | Should -Be 'P'
    }
}

Describe 'Text the engine cannot handle is refused before any text object starts' {
    It 'rejects an unpaired surrogate in <Name>' -ForEach @(
        @{ Name = 'Add-VellumPdfText'; Run = { param($d) $d | Add-VellumPdfText "a$($script:lone)" -X 1 -Y 1 } }
        @{ Name = 'Add-VellumPdfTextBox'; Run = { param($d) $d | Add-VellumPdfTextBox "a$($script:lone)" -X 1 -Y 100 -Width 50 } }
        @{ Name = 'Add-VellumPdfPageTable'; Run = { param($d) $d | Add-VellumPdfPageTable -X 1 -Y 100 -Width 50 -Row @(, @("a$($script:lone)")) } }
        @{ Name = 'Add-VellumPdfPageList'; Run = { param($d) $d | Add-VellumPdfPageList -X 1 -Y 100 -Width 100 -Item "a$($script:lone)" } }
        @{ Name = 'Set-VellumPdfPageBand'; Run = { param($d) $d | Set-VellumPdfPageBand Footer "a$($script:lone)" } }
        @{ Name = 'Measure-VellumPdfText'; Run = { Measure-VellumPdfText "a$($script:lone)" } }
    ) {
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage
        { & $Run $doc } | Should -Throw "*$Name*unpaired UTF-16 surrogate*"
        $pdf = Join-Path $TestDrive "surrogate-$Name.pdf"
        $doc | Add-VellumPdfText 'fine' -X 10 -Y 10 | Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        $c = Get-PdfContentText $pdf
        ([regex]::Matches($c, '(?m)^BT$')).Count | Should -Be ([regex]::Matches($c, '(?m)^ET$')).Count
    }

    It 'accepts a valid surrogate pair' {
        { Measure-VellumPdfText ([char]::ConvertFromUtf32(0x1F600)) } | Should -Not -Throw
    }

    It 'refuses Symbol and ZapfDingbats where text must be measured, and still draws them left-aligned' {
        { Measure-VellumPdfText 'abc' -Font Symbol } | Should -Throw '*has no width table*'
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfTextBox 'abc' -X 1 -Y 100 -Width 50 -Font ZapfDingbats } | Should -Throw '*ZapfDingbats*'
            { $doc | Add-VellumPdfPageTable -X 1 -Y 100 -Width 50 -Font Symbol -Row @(, @('a')) } | Should -Throw '*Symbol*'
            { $doc | Add-VellumPdfPageList -X 1 -Y 100 -Width 100 -Font Symbol -Item 'a' } | Should -Throw '*Symbol*'
            { $doc | Add-VellumPdfText 'abc' -X 50 -Y 50 -Font Symbol -Align Right } | Should -Throw '*Symbol*'
            { $doc | Add-VellumPdfText 'abc' -X 50 -Y 50 -Font Symbol } | Should -Not -Throw
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Page numbers are checked before drawing' {
    It 'names the cmdlet for a page that does not exist (<Name>)' -ForEach @(
        @{ Name = 'table'; Run = { param($d) $d | Add-VellumPdfPageTable -X 1 -Y 100 -Width 50 -Row @(, @('a')) -Page 9 } }
        @{ Name = 'list'; Run = { param($d) $d | Add-VellumPdfPageList -X 1 -Y 100 -Width 100 -Item 'a' -Page 9 } }
    ) {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        { & $Run $doc } | Should -Throw '*Page 9 is out of range*'
        $doc.Dispose()
    }
}

Describe 'Table input' {
    It 'refuses records, cell hashtables without Text, and fractional spans' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfPageTable -X 1 -Y 100 -Width 100 -Row @([pscustomobject]@{ Name = 'Widget'; Qty = 2 }) } | Should -Throw '*records are not supported*'
            { $doc | Add-VellumPdfPageTable -X 1 -Y 100 -Width 100 -Row @(@{ Name = 'Widget' }) } | Should -Throw '*needs a Text key*'
            { $doc | Add-VellumPdfPageTable -X 1 -Y 100 -Width 100 -Row @(, @(@{ Text = 'a'; ColSpan = 1.5 })) } | Should -Throw '*whole number*'
        }
        finally { $doc.Dispose() }
    }

    It 'makes only the grid column 0 a row header, and warns about rows that do not fill the grid' -Skip:(-not $script:haveQpdf) {
        $doc = New-Tagged
        $w = $null
        $null = $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -RowHeader -Header 'A', 'B', 'C' -Row @(
            @(@{ Text = 'Span'; RowSpan = 2 }, 'a', 'b'),
            @('c', 'd')) -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -BeNullOrEmpty
        $pdf = Join-Path $TestDrive 'rowheader-span.pdf'
        $doc | Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        $table = (Get-PdfStructureTree $pdf)[0]
        @($table.Children[1].Children.Type) | Should -Be 'TH', 'TD', 'TD'
        @($table.Children[2].Children.Type) | Should -Be 'TD', 'TD' -Because 'column 0 of this row is covered by the row span'

        $w = $null
        $d2 = New-VellumPdfPageDocument | Add-VellumPdfPage
        $null = $d2 | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Row @(@('1', '2', '3'), @('4')) -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -Match 'do not fill all 3 grid columns'
        $d2.Dispose()
    }

    It 'passes the PDF/A-2b preflight with a CMYK intent, because no colour was asked for' {
        $pdf = Join-Path $TestDrive 'table-cmyk.pdf'
        New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage | Set-VellumPdfOutputIntent -Cmyk |
            Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Header 'A', 'B' -Row @(, @('1', '2')) |
            Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Item 'one', 'two' |
            Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        (Test-VellumPdfConformance -Path $pdf -Profile PdfA2b).IsCompliant | Should -BeTrue
    }
}

Describe 'List details' {
    It 'widens the marker column for numbers of 100 and above, and labels more than 26 children aa, ab ...' {
        $doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm 300 -PageHeightMm 900
        $children = 1..28 | ForEach-Object { "c$_" }
        $info = $doc | Add-VellumPdfPageList -X 10 -Y 2400 -Width 200 -Numbered -FontSize 10 -ItemSpacing 0 -PassThru -Item ((1..100 | ForEach-Object { "item $_" }) + @(@{ Text = 'last'; Children = $children }))
        $pdf = Join-Path $TestDrive 'long-list.pdf'
        $info.Document | Save-VellumPdfDocument -Path $pdf | Out-Null
        $c = Get-PdfContentText $pdf
        $markerX = [double][regex]::Match($c, '1 0 0 1 ([\d.]+) [\d.]+ Tm\r?\n\(100\.\) Tj').Groups[1].Value
        $textX = [double][regex]::Match($c, '1 0 0 1 ([\d.]+) [\d.]+ Tm\r?\n\(item 100\) Tj').Groups[1].Value
        $probe = New-VellumPdfPageDocument
        $width = $probe.UseFont([VellumPdf.Fonts.Standard14]::Helvetica).MeasureString('100.', 10)
        $probe.Dispose()
        ($textX - $markerX) | Should -BeGreaterThan $width -Because 'the text starts after the widest marker'
        $c | Should -Match '\(aa\.\) Tj'
        $c | Should -Match '\(ab\.\) Tj'
        $c | Should -Match '\(z\.\) Tj'
    }

    It 'allows an empty item and refuses a null one' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfPageList -X 1 -Y 100 -Width 100 -Item 'a', '' } | Should -Not -Throw
            { $doc | Add-VellumPdfPageList -X 1 -Y 100 -Width 100 -Item 'a', $null } | Should -Throw
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Values from one pipeline item do not leak into the next' {
    It 'rotates text for every document, and keeps the bullet for every document' {
        $a = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $b = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $null = $a, $b | Add-VellumPdfText 'hi' -X 100 -Y 200 -Rotation 30
        (Get-PageContent $a 1) | Should -Match '0\.86603 0\.5 -0\.5 0\.86603 100 200 cm'
        (Get-PageContent $b 1) | Should -Match '0\.86603 0\.5 -0\.5 0\.86603 100 200 cm'
        $c = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $d = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $null = $c, $d | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item 'one', @{ Text = 'two'; Children = 'c1' }
        (Get-PageContent $c 1) | Should -Match ([char]0x95)
        (Get-PageContent $d 1) | Should -Match ([char]0x95)
        $a.Dispose(); $b.Dispose(); $c.Dispose(); $d.Dispose()
    }

    It 'follows the scope page for the first document only' {
        $first = New-VellumPdfPageDocument | Add-VellumPdfPage -Count 2
        $second = New-VellumPdfPageDocument | Add-VellumPdfPage -Count 2
        $null = $first | Use-VellumPdfClip -Page 2 -X 0 -Y 0 -Width 50 -Height 50 -ScriptBlock { $_ | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 3 -Height 3 -FillColor red }
        $null = $second | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 3 -Height 3 -FillColor red
        (Get-PageContent $first 2) | Should -Match '1 1 3 3 re'
        (Get-PageContent $second 1) | Should -Match '1 1 3 3 re'
        $first.Dispose(); $second.Dispose()
    }
}

Describe 'Small contract fixes' {
    It 'accepts the script block first in Use-VellumPdfStructure, and -Type by name' -Skip:(-not $script:haveQpdf) {
        $doc = New-Tagged
        $pdf = Join-Path $TestDrive 'positional.pdf'
        $doc | Use-VellumPdfStructure { $_ | Add-VellumPdfText 'in a section' -X 72 -Y 700 } |
            Use-VellumPdfStructure -Type Div -ScriptBlock { $_ | Add-VellumPdfText 'in a division' -X 72 -Y 650 } |
            Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        @((Get-PdfStructureTree $pdf).Type) | Should -Be 'Sect', 'Div'
    }

    It 'bounds the scale of a transform' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Use-VellumPdfTransform -Scale 1e300 -ScriptBlock { } } | Should -Throw '*between 0.000001 and 1,000,000*'
            { $doc | Use-VellumPdfTransform -Scale 1e-9 -ScriptBlock { } } | Should -Throw '*between 0.000001 and 1,000,000*'
            { $doc | Use-VellumPdfTransform -Scale 1e-6 -ScriptBlock { } } | Should -Not -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'refuses a file name with a NUL character, and does not blame margins for an unbalanced canvas' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        { $doc | Save-VellumPdfDocument -Path "a`0b.pdf" } | Should -Throw '*not allowed in a file name*'
        $doc | Invoke-VellumPdfCanvas -ScriptBlock { param($c) $c.SaveState() | Out-Null } | Out-Null
        $message = try { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'unbalanced.pdf') } catch { $_.Exception.Message }
        $message | Should -Match 'saved and restored the graphics state unevenly'
        $message | Should -Not -Match 'extreme margin'
        $doc.Dispose()
    }

    It 'keeps an embedded font in a run that sets no size' {
        $doc = New-VellumPdfDocument -DefaultFont TimesRoman -DefaultFontSize 14
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $pdf = Join-Path $TestDrive 'run-font.pdf'
        $doc | Add-VellumPdfParagraph -Run (New-VellumPdfTextRun "Zażółć $([char]0x03A9)" -FontHandle $font), (New-VellumPdfTextRun ' plain') |
            Save-VellumPdfDocument -Path $pdf | Out-Null
        (Get-PdfText $pdf) | Should -Match '/FontFile2'
        (Get-PdfText $pdf) | Should -Match '/BaseFont\s*/Times-Roman'
        (Get-PdfContentText $pdf) | Should -Match '/F\d+ 14 Tf'
    }
}

Describe 'CCITT without end-of-line codes' {
    It 'writes one-dimensional byte-aligned data as TIFF compression 2, pixel-identical to the PDF' -Skip:(-not $script:render) {
        $pdf = Join-Path $TestDrive 'rle.pdf'
        New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm 22.5778 -PageHeightMm 16.9333 |
            Add-VellumPdfPageImage (Join-Path $script:assets 'sample-rle.tif') -X 0 -Y 0 -Width 64 -AltText 'sample' |
            Save-VellumPdfDocument -Path $pdf | Out-Null
        $file = @(Export-VellumPdfImage $pdf -DestinationPath (Join-Path $TestDrive 'o-rle'))[0]
        $file.Extension | Should -Be '.tif'
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $count = [BitConverter]::ToUInt16($bytes, 8)
        $tags = @{}
        for ($i = 0; $i -lt $count; $i++) { $o = 10 + 12 * $i; $tags[[int][BitConverter]::ToUInt16($bytes, $o)] = [BitConverter]::ToUInt16($bytes, $o + 8) }
        $tags[259] | Should -Be 2
        $tags.ContainsKey(292) | Should -BeFalse
        $base = Join-Path $TestDrive 'rle-ref'
        & pdftoppm -r 288 -gray -aa no -aaVector no -png $pdf $base
        $reference = (Get-ChildItem "$base*.png" | Select-Object -First 1).FullName
        $exported = Join-Path $TestDrive 'rle-out.png'
        & convert $file.FullName -colorspace Gray -filter point -resize 400% $exported
        # ImageMagick 6 prints '0', ImageMagick 7 prints '0 (0)': compare the differing-pixel count only.
        (((& (Get-Command compare -CommandType Application | Select-Object -First 1) -metric AE -fuzz 20% $reference $exported null: 2>&1) | Out-String).Trim() -split '\s+')[0] | Should -Be '0'
    }

    It 'skips Group 3 data TIFF cannot describe, and absurd sizes' {
        $build = { param($w, $h, $k, $black, $align, $eol) [PSVellumPDF.Interop.ImageContainers]::BuildCcittTiff($w, $h, $k, $black, $align, $eol, [byte[]]@(1, 2, 3)) }
        (& $build 64 48 0 $true $false $false) | Should -BeNullOrEmpty    # no EOL, not byte-aligned
        (& $build 64 48 3 $true $true $false) | Should -BeNullOrEmpty     # 2-D without EOL
        (& $build 64 48 0 $true $true $false) | Should -Not -BeNullOrEmpty
        (& $build 100001 48 -1 $true $false $true) | Should -BeNullOrEmpty
        (& $build 64 2147483647 -1 $true $false $true) | Should -BeNullOrEmpty
    }

    It 'survives a hostile JBIG2 segment header' {
        # Segment number 0x00020000, flags, then a long-form referred-to count of 0x1FFFFFFF.
        $hostile = [byte[]]@(0, 2, 0, 0, 0x30, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0)
        { [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File($hostile, $null) } | Should -Not -Throw
        [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File($hostile, $null) | Should -BeNullOrEmpty
    }
}
