#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    function script:Get-PdfText([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::Latin1) }
    # PDF text strings that are not pure ASCII are stored as UTF-16BE with a BOM.
    function script:Get-Utf16Pattern([string]$Text) {
        '\xFE\xFF' + (($Text.ToCharArray() | ForEach-Object { '\x00' + [regex]::Escape([string]$_) }) -join '')
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfPieChart appearance options reach the file' {
    BeforeAll {
        function script:Save-Pie([hashtable]$Extra, [string]$Name) {
            $path = Join-Path $TestDrive "$Name.pdf"
            New-VellumPdfDocument | Add-VellumPdfPieChart -Slice @(@{ Value = 1 }, @{ Value = 1 }) @Extra |
                Save-VellumPdfDocument -Path $path | Out-Null
            Get-PdfContentText $path
        }
    }

    It 'draws the separator stroke in the requested colour and width' {
        $plain = Save-Pie @{} 'nostroke'
        $plain | Should -Not -Match '1 0 0 RG'
        $c = Save-Pie @{ StrokeColor = 'red'; StrokeWidth = 2 } 'stroke'
        $c | Should -Match '1 0 0 RG'
        $c | Should -Match '(?m)^2 w$'
    }

    It 'moves the chart down: -MarginTop replaces the chart default of 6pt' {
        $y = { param($c) [double][regex]::Match($c, '[\d.]+ ([\d.]+) m').Groups[1].Value }
        $base = & $y (Save-Pie @{} 'm0')
        $moved = & $y (Save-Pie @{ MarginTop = 100 } 'm100')
        $base - $moved | Should -Be 94   # 100 - the built-in 6pt
    }
}

Describe 'Add-VellumPdfPieChart' {
    It 'draws a chart from slices and returns the document for chaining' {
        $out = Join-Path $TestDrive 'pie.pdf'
        $doc = New-VellumPdfDocument
        $result = $doc | Add-VellumPdfPieChart -Slice @(@{ Value = 3; Label = 'a' }, @{ Value = 1; Label = 'b' })
        [object]::ReferenceEquals($result, $doc) | Should -BeTrue
        $result | Save-VellumPdfDocument -Path $out | Out-Null
        (Get-Item $out).Length | Should -BeGreaterThan 500
    }

    It 'accepts pipeline data objects with -ValueProperty and -LabelProperty' {
        $out = Join-Path $TestDrive 'data.pdf'
        $doc = New-VellumPdfDocument -Tagged -Language en
        [pscustomobject]@{ Region = 'North'; Sales = 40 }, [pscustomobject]@{ Region = 'South'; Sales = 60 } |
            Add-VellumPdfPieChart -Document $doc -ValueProperty Sales -LabelProperty Region |
            Save-VellumPdfDocument -Path $out | Out-Null
        # Without -AltText the engine composes it from the labels and shares.
        Get-PdfText $out | Should -Match (Get-Utf16Pattern 'Pie chart: North 40%, South 60%')
    }

    It 'uses -AltText, and -Decorative leaves no Figure' {
        $a = Join-Path $TestDrive 'alt.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfPieChart -Slice @(@{ Value = 1 }) -AltText 'Market share' |
            Save-VellumPdfDocument -Path $a | Out-Null
        Get-PdfText $a | Should -Match (Get-Utf16Pattern 'Market share')

        $d = Join-Path $TestDrive 'deco.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfPieChart -Slice @(@{ Value = 1 }) -Decorative |
            Save-VellumPdfDocument -Path $d | Out-Null
        Get-PdfText $d | Should -Not -Match '/S\s*/Figure'
    }

    It 'adds a legend table with label and percentage' {
        $out = Join-Path $TestDrive 'legend.pdf'
        New-VellumPdfDocument |
            Add-VellumPdfPieChart -Legend -Slice @(@{ Value = 1; Label = 'One' }, @{ Value = 3; Label = 'Three' }) |
            Save-VellumPdfDocument -Path $out | Out-Null
        # No -Legend is a chart only; with it the page also carries table text.
        $plain = Join-Path $TestDrive 'nolegend.pdf'
        New-VellumPdfDocument |
            Add-VellumPdfPieChart -Slice @(@{ Value = 1; Label = 'One' }, @{ Value = 3; Label = 'Three' }) |
            Save-VellumPdfDocument -Path $plain | Out-Null
        (Get-Item $out).Length | Should -BeGreaterThan (Get-Item $plain).Length
    }

    It 'validates slices before the document is saved' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Value = -1 }) } | Should -Throw '*finite number >= 0*'
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Value = [double]::NaN }) } | Should -Throw '*finite number >= 0*'
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Value = 0 }, @{ Value = 0 }) } | Should -Throw '*more than zero*'
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Label = 'x' }) } | Should -Throw '*numeric Value*'
            { $doc | Add-VellumPdfPieChart -Slice @() } | Should -Throw
            { $doc | Add-VellumPdfPieChart -Slice @(5) } | Should -Throw '*must be a hashtable*'
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Value = 1 }) -AltText 'x' -Decorative } | Should -Throw '*cannot be combined*'
            { $doc | Add-VellumPdfPieChart -Slice @(@{ Value = 1 }) -Alignment Justify } | Should -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'warns when the diameter exceeds the content width' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Add-VellumPdfPieChart -Slice @(@{ Value = 1 }) -Diameter 5000 -WarningVariable wv -WarningAction SilentlyContinue | Out-Null
            @($wv | Where-Object Message -Like '*wider than*').Count | Should -Be 1
        }
        finally { $doc.Dispose() }
    }

    It 'accepts PieSlice objects, colours, stroke and angle options' {
        $out = Join-Path $TestDrive 'opts.pdf'
        $slice = [VellumPdf.Layout.Elements.PieSlice]::new(2, [VellumPdf.Layout.Core.ColorRgb]::new(1, 0, 0), 'red')
        { New-VellumPdfDocument |
                Add-VellumPdfPieChart -Slice $slice, @{ Value = 1; Color = 'navy' } -StrokeColor white -StrokeWidth 1 `
                    -StartAngle 0 -CounterClockwise -Diameter 120 -Alignment Left -MarginTop 5 -MarginBottom 5 |
                Save-VellumPdfDocument -Path $out } | Should -Not -Throw
    }
}
