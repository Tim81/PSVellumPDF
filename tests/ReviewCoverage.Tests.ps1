#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Behaviour the first review found untested: pages other than 1, roles and languages in the structure tree,
# alternate text values, colours and stroke options, clipping, and what a page band really draws.

param()

BeforeDiscovery {
    $script:render = [bool]((Get-Command pdftoppm -ErrorAction SilentlyContinue) -and (Get-Command convert -ErrorAction SilentlyContinue) -and ((& convert -version 2>&1 | Out-String) -match 'ImageMagick'))   # Windows has its own unrelated convert.exe
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)
}

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    $script:gray16 = Join-Path $PSScriptRoot 'assets' 'gray16.png'
    $script:render = [bool]((Get-Command pdftoppm -ErrorAction SilentlyContinue) -and (Get-Command convert -ErrorAction SilentlyContinue) -and ((& convert -version 2>&1 | Out-String) -match 'ImageMagick'))   # Windows has its own unrelated convert.exe
    function script:New-Pages([int]$Count = 2, [hashtable]$DocParams = @{ Language = 'en' }) { New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage -Count $Count }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Drawing on a page other than the first' {
    It 'puts <Name> on page 2 only' -ForEach @(
        @{ Name = 'a path'; Draw = { $_ | Add-VellumPdfPath 'M 11 22 L 33 44' -Page 2 }; Marker = '11 22 m' }
        @{ Name = 'a text box'; Draw = { $_ | Add-VellumPdfTextBox 'Second page' -X 10 -Y 100 -Width 100 -Page 2 }; Marker = '\(Second page\) Tj' }
        @{ Name = 'a clip with its drawing'; Draw = { $_ | Use-VellumPdfClip -Page 2 -X 5 -Y 6 -Width 7 -Height 8 -ScriptBlock { $_ | Add-VellumPdfShape Rectangle -X 1 -Y 2 -Width 3 -Height 4 -FillColor red } }; Marker = '5 6 m' }
        @{ Name = 'a table'; Draw = { $_ | Add-VellumPdfPageTable -X 10 -Y 150 -Width 100 -Row @(, @('cell')) -Page 2 }; Marker = '\(cell\) Tj' }
        @{ Name = 'a list'; Draw = { $_ | Add-VellumPdfPageList -X 10 -Y 150 -Width 100 -Item 'entry' -Page 2 }; Marker = '\(entry\) Tj' }
    ) {
        $doc = New-Pages 2
        $null = $doc | ForEach-Object -Process $Draw
        (Get-PageContent $doc 1) | Should -Not -Match $Marker
        (Get-PageContent $doc 2) | Should -Match $Marker
        $doc.Dispose()
    }
}

Describe 'Roles, languages and alternate text reach the structure tree' -Skip:(-not $script:haveQpdf) {
    It 'writes -Role, -Language and -AltText on the elements' {
        $doc = New-Pages 1 @{ Conformance = 'PdfUA1'; Language = 'en-US' }
        $pdf = Join-Path $TestDrive 'tree.pdf'
        $doc | Set-VellumPdfDocumentInfo -Title 'Tree' |
            Add-VellumPdfText 'Section title' -X 72 -Y 760 -FontSize 16 -Role H1 -Language de-DE |
            Add-VellumPdfTextBox 'Quoted words' -X 72 -Y 700 -Width 200 -Role Caption -Language fr-FR |
            Add-VellumPdfPath 'M 72 600 L 172 600 L 122 660 Z' -FillColor navy -AltText 'A navy triangle' |
            Add-VellumPdfShape Ellipse -X 72 -Y 500 -Width 80 -Height 40 -FillColor red -AltText 'A red ellipse' |
            Add-VellumPdfGradient -X 200 -Y 500 -Width 80 -Height 40 -StartColor red -EndColor blue -AltText 'A gradient' |
            Add-VellumPdfPageImage $script:gray16 -X 72 -Y 400 -Width 30 -AltText 'A grey square' |
            Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        $tree = Get-PdfStructureTree $pdf
        $tree[0].Type | Should -Be 'H1'
        $tree[0].Lang | Should -Be 'de-DE'
        $tree[1].Type | Should -Be 'Caption'
        $tree[1].Lang | Should -Be 'fr-FR'
        @($tree | Where-Object Type -EQ 'Figure' | ForEach-Object Alt) | Should -Be 'A navy triangle', 'A red ellipse', 'A gradient', 'A grey square'
    }
}

Describe 'Colours and stroke options are written' {
    It 'writes the text colour of a text box, and the opacity, miter limit and ICC stroke of a path' {
        $srgb = Join-Path $TestDrive 'srgb.icc'
        [System.IO.File]::WriteAllBytes($srgb, [VellumPdf.Document.IccProfiles]::Srgb)
        $doc = New-Pages 1
        $null = $doc | Add-VellumPdfTextBox 'Coloured' -X 10 -Y 90 -Width 80 -Color '#336699' |
            Add-VellumPdfPath 'M 10 10 L 50 50 L 90 10' -StrokeIcc 0.1, 0.2, 0.3 -IccProfilePath $srgb -MiterLimit 4 -Opacity 0.5 -StrokeOpacity 0.25 -FillColor red
        $content = Get-PageContent $doc 1
        $content | Should -Match '(?m)^0\.2 0\.4 0\.6 rg$'
        $content | Should -Match '(?m)^4 M$'
        $content | Should -Match '(?m)^/VICC1 CS$'
        $content | Should -Match '(?m)^0\.1 0\.2 0\.3 SCN?$'
        $content | Should -Match '/GS\d+ gs'
        $doc.Dispose()
    }
}

Describe 'A clip really clips' -Skip:(-not $script:render) {
    It 'keeps the drawing inside the clip box' {
        $pdf = Join-Path $TestDrive 'clip-render.pdf'
        New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm 35.2778 -PageHeightMm 35.2778 |
            Use-VellumPdfClip -X 20 -Y 30 -Width 30 -Height 20 -ScriptBlock {
                $_ | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 100 -Height 100 -FillColor black
            } | Save-VellumPdfDocument -Path $pdf | Out-Null
        $base = Join-Path $TestDrive 'clip-render'
        & pdftoppm -r 72 -gray -png $pdf $base
        $png = (Get-ChildItem "$base*.png" | Select-Object -First 1).FullName
        # y 30..50 in page coordinates is 50..70 from the top of a 100 pt page.
        (& convert $png -fuzz 20% -trim -format '%wx%h%O' info:) | Should -Be '30x20+20+50'
    }
}

Describe 'Page bands draw what they say' {
    It 'draws the band text inside an artifact, and in the embedded font that was asked for' {
        $doc = New-Pages 1 @{ Conformance = 'PdfUA1'; Language = 'en' }
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $null = $doc | Set-VellumPdfDocumentInfo -Title 'Band' | Add-VellumPdfText 'Body' -X 72 -Y 700 |
            Set-VellumPdfPageBand Footer 'Zażółć {page}' -FontHandle $font -FontSize 8
        $content = Get-PageContent $doc 1
        (Get-UnmarkedTextStart $content) | Should -BeNullOrEmpty -Because 'every text object is inside marked content'
        $content | Should -Match '(?s)/Artifact BMC.*?BT\r?\n/TT\d+ 8 Tf.*?ET.*?EMC'
        $doc.Dispose()
    }
}

Describe 'Embedded fonts are the ones drawn' {
    It 'uses the registered font in the text box and not Helvetica' {
        $doc = New-Pages 1
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $null = $doc | Add-VellumPdfTextBox 'Zażółć' -X 10 -Y 90 -Width 80 -FontHandle $font
        $content = Get-PageContent $doc 1
        $content | Should -Match '(?s)BT\r?\n/TT\d+ 12 Tf.*?<[0-9A-F]+> Tj'
        $content | Should -Not -Match '/F\d+ 12 Tf'
        $doc.Dispose()
    }
}
