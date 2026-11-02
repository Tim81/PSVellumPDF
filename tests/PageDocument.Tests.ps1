#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    $script:gray16 = Join-Path $PSScriptRoot 'assets' 'gray16.png'

    function script:Save-Page([scriptblock]$Build, [string]$Name, [hashtable]$DocParams = @{ Language = 'en' }) {
        $path = Join-Path $TestDrive "$Name.pdf"
        $doc = New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage
        $doc = & $Build $doc
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        $path
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'New-VellumPdfPageDocument and Add-VellumPdfPage' {
    It 'creates a document with the requested defaults' {
        $doc = New-VellumPdfPageDocument -PageSize Letter -Language fr
        try {
            $doc | Should -BeOfType ([VellumPdf.Document.PdfDocument])
            $doc.DefaultPageSize.Width | Should -Be 612
            $doc.Language | Should -Be 'fr'
        }
        finally { $doc.Dispose() }
    }

    It 'adds pages with sizes, rotation and counts, and returns the page with -PassThru' {
        $doc = New-VellumPdfPageDocument
        try {
            $doc | Add-VellumPdfPage -Count 2 | Add-VellumPdfPage -PageWidthMm 100 -PageHeightMm 50 -Rotate 90 | Out-Null
            $doc.Pages.Count | Should -Be 3
            $doc.Pages[2].Rotate | Should -Be 90
            [math]::Round($doc.Pages[2].MediaBox.Width, 1) | Should -Be 283.5
            $page = $doc | Add-VellumPdfPage -PageSize A5 -PassThru
            $page | Should -BeOfType ([VellumPdf.Document.PdfPage])
        }
        finally { $doc.Dispose() }
    }

    It 'writes /Rotate and a custom MediaBox into the file' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPage -Rotate 270 } 'rot'
        Get-PdfText $path | Should -Match '/Rotate 270'
    }

    It 'refuses conflicting or invalid options' {
        { New-VellumPdfPageDocument -Linearize -UseObjectStreams } | Should -Throw '*cannot be combined*'
        { New-VellumPdfPageDocument -DocumentId ([byte[]](1, 2, 3)) } | Should -Throw '*exactly 16 bytes*'
        { New-VellumPdfPageDocument -Conformance PdfUA1 } | Should -Throw
        { New-VellumPdfPageDocument -PageWidthMm 5081 -PageHeightMm 10 } | Should -Throw
    }

    It 'writes a linearized file with -Linearize' {
        $path = Save-Page { param($d) $d | Add-VellumPdfText 'x' -X 72 -Y 700 } 'lin' @{ Linearize = $true }
        Get-PdfText $path | Should -Match '/Linearized'
    }

    It 'gives byte-identical output for a fixed -DocumentId and -Timestamp' {
        $make = {
            param($name)
            Save-Page { param($d) $d | Add-VellumPdfText 'repeatable' -X 72 -Y 700 } $name `
                @{ DocumentId = [byte[]](1..16); Timestamp = [DateTimeOffset]'2026-01-01T00:00:00Z' }
        }
        $a = [System.IO.File]::ReadAllBytes((& $make 'repro1'))
        $b = [System.IO.File]::ReadAllBytes((& $make 'repro2'))
        [System.Convert]::ToHexString($a) | Should -Be ([System.Convert]::ToHexString($b))
        $c = [System.IO.File]::ReadAllBytes((Save-Page { param($d) $d | Add-VellumPdfText 'repeatable' -X 72 -Y 700 } 'repro3'))
        [System.Convert]::ToHexString($a) | Should -Not -Be ([System.Convert]::ToHexString($c))
    }

    It 'reports page-number errors clearly' {
        $doc = New-VellumPdfPageDocument
        try {
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw '*no pages yet*'
            $doc | Add-VellumPdfPage | Out-Null
            { $doc | Add-VellumPdfShape Rectangle -Page 2 -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw '*out of range*1 page*'
        }
        finally { $doc.Dispose() }
    }

    It 'is rejected by flow-layout cmdlets, and flow documents by page cmdlets' {
        $page = New-VellumPdfPageDocument
        $flow = New-VellumPdfDocument
        try {
            { $page | Add-VellumPdfParagraph -Text 'x' -ErrorAction Stop } | Should -Throw
            { $flow | Add-VellumPdfPage -ErrorAction Stop } | Should -Throw
        }
        finally { $page.Dispose(); $flow.Dispose() }
    }
}

Describe 'Page drawing cmdlets' {
    It 'Invoke-VellumPdfCanvas draws on one shared canvas per page, in order' {
        $path = Save-Page {
            param($d)
            $d | Invoke-VellumPdfCanvas -Page 1 -ScriptBlock { param($c, $p, $doc) $c.SetFillColorRgb(1, 0, 0).Rectangle(10, 10, 20, 20).Fill() | Out-Null } |
                Add-VellumPdfShape Rectangle -X 40 -Y 10 -Width 20 -Height 20 -FillColor '#00ff00' |
                Invoke-VellumPdfCanvas -Page 1 -ScriptBlock { param($c) $c.SetFillColorGray(0.5).Rectangle(70, 10, 20, 20).Fill() | Out-Null }
        } 'canvas'
        $c = Get-PdfContentText $path
        $c | Should -Match '(?s)1 0 0 rg.*0 1 0 rg.*0\.5 g'
    }

    It 'draws rectangles, ellipses and lines with fills, strokes, CMYK, dashes and opacity' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfShape Rectangle -X 50 -Y 50 -Width 100 -Height 50 -FillColor navy -StrokeColor red -StrokeWidth 3 -Dash 4, 2 -Opacity 0.5 -StrokeOpacity 0.25 |
                Add-VellumPdfShape Ellipse -X 200 -Y 50 -Width 80 -Height 40 -FillCmyk 0, 1, 1, 0 |
                Add-VellumPdfShape Line -X 50 -Y 40 -X2 300 -Y2 40 -StrokeCmyk 1, 0, 0, 0
        } 'shapes'
        $c = Get-PdfContentText $path
        $c | Should -Match '50 50 100 50 re'
        $c | Should -Match '\[4 2\] 0 d'
        $c | Should -Match '(?s)0 0 0\.5 rg.*1 0 0 RG.*3 w.*\nB\n'
        $c | Should -Match '0 1 1 0 k\r?\n[\d. ]+ m(?s:.*?) c\r?\nh\r?\nf'
        $c | Should -Match '1 0 0 0 K(?s:.*)50 40 m\r?\n300 40 l\r?\nS'
        (Get-PdfText $path) | Should -Match '/ca 0\.5'
        (Get-PdfText $path) | Should -Match '/CA 0\.25'
    }

    It 'validates shape parameters' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfShape Line -X 1 -Y 1 } | Should -Throw '*needs -X2 and -Y2*'
            { $doc | Add-VellumPdfShape Line -X 1 -Y 1 -X2 5 -Y2 5 -FillColor red } | Should -Throw '*no fill*'
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 } | Should -Throw '*positive -Width and -Height*'
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -X2 3 } | Should -Throw '*Line only*'
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor red -FillCmyk 0, 0, 0, 1 } | Should -Throw '*not both*'
            { $doc | Add-VellumPdfShape Rectangle -X ([double]::NaN) -Y 1 -Width 5 -Height 5 } | Should -Throw '*finite*'
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -Opacity 2 } | Should -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'places base-14 text with colour and alignment, and rejects multi-line text' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfText 'Left' -X 72 -Y 700 -FontSize 20 -Color red |
                Add-VellumPdfText 'Centred' -X 300 -Y 650 -Align Center -Font TimesBold
        } 'text'
        $c = Get-PdfContentText $path
        $c | Should -Match '1 0 0 rg(?s:.*)/F1 20 Tf\r?\n1 0 0 1 72 700 Tm\r?\n\(Left\) Tj'
        $c | Should -Match '\(Centred\) Tj'
        $m = [regex]::Match($c, '1 0 0 1 ([\d.]+) 650 Tm')
        [double]$m.Groups[1].Value | Should -BeLessThan 300   # centred: starts left of x
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try { { $doc | Add-VellumPdfText "a`nb" -X 1 -Y 1 } | Should -Throw '*single line*' }
        finally { $doc.Dispose() }
    }

    It 'draws Unicode text with an embedded font' {
        $doc = New-VellumPdfPageDocument -Language cs | Add-VellumPdfPage
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $path = Join-Path $TestDrive 'uni.pdf'
        $czech = 'P' + [char]0x0159 + 'ilis'
        $doc | Add-VellumPdfText $czech -X 72 -Y 700 -FontHandle $h -WarningVariable wv | Save-VellumPdfDocument -Path $path | Out-Null
        @($wv).Count | Should -Be 0
        Get-PdfText $path | Should -Match '/FontFile2'
    }

    It 'embeds a substitute for base-14 text automatically in a PDF/A page document, which then passes the preflight' {
        $path = Save-Page { param($d) $d | Add-VellumPdfText 'Archive text' -X 72 -Y 700 -Font HelveticaBold } 'pdfa' @{ Conformance = 'PdfA2b'; Language = 'en' }
        Get-PdfText $path | Should -Match '/FontFile2'
        $r = Test-VellumPdfConformance -Path $path -Profile PdfA2b
        ($r.Assertions | Where-Object Severity -EQ 'Error' | ForEach-Object { "$($_.RuleId): $($_.Message)" }) | Should -BeNullOrEmpty
        $r.IsCompliant | Should -BeTrue
    }

    It 'warns once after saving about characters base-14 fonts cannot encode' {
        $cjk = -join ([int[]](0x65E5, 0x672C) | ForEach-Object { [char]$_ })
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        $doc | Add-VellumPdfText $cjk -X 72 -Y 700 -WarningAction SilentlyContinue | Out-Null
        $file = $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'cjk.pdf') -WarningVariable wv -WarningAction SilentlyContinue
        @($wv | Where-Object Message -Like '*written as ''?''*').Count | Should -Be 1
        $file.TextEncodingWarnings.Count | Should -Be 2
    }

    It 'paints axial and radial gradients clipped to their box' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfGradient -X 50 -Y 300 -Width 200 -Height 80 -StartColor navy -EndColor white -Direction Diagonal |
                Add-VellumPdfGradient -X 300 -Y 300 -Width 100 -Height 100 -StartColor red -EndColor yellow -Type Radial
        } 'grad'
        $c = Get-PdfContentText $path
        ([regex]::Matches($c, 'W\r?\nn\r?\n/Sh\d sh')).Count | Should -Be 2
        $t = Get-PdfText $path
        $t | Should -Match '/ShadingType 2'
        $t | Should -Match '/ShadingType 3'
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try { { $doc | Add-VellumPdfGradient -X 1 -Y 1 -Width 5 -Height 5 -StartColor red -EndColor blue -Type Radial -Direction Diagonal } | Should -Throw '*Axial gradient only*' }
        finally { $doc.Dispose() }
    }

    It 'places images keeping the aspect ratio' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPageImage $script:gray16 -X 50 -Y 450 -Width 40 | Add-VellumPdfPageImage $script:gray16 -X 120 -Y 450 -Height 10 } 'img'
        $c = Get-PdfContentText $path
        $c | Should -Match '40 0 0 40 50 450 cm\r?\n/VIm1 Do'
        $c | Should -Match '10 0 0 10 120 450 cm\r?\n/VIm2 Do'
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfPageImage (Join-Path $TestDrive 'nope.png') -X 1 -Y 1 } | Should -Throw '*file not found*'
            { $doc | Add-VellumPdfPageImage -ImageBytes ([byte[]](1, 2, 3)) -Format Png -X 1 -Y 1 } | Should -Throw '*failed to load*'
        }
        finally { $doc.Dispose() }
    }

    It 'draws barcodes at a position, validates content, and stays PDF/A compliant without a text line' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPageBarcode QrCode 'https://example.com' -X 72 -Y 600 -TargetWidth 80 } 'qr' @{ Conformance = 'PdfA2b'; Language = 'en' }
        (Get-PdfContentText $path) | Should -Match ' re\r?\n'
        (Test-VellumPdfConformance -Path $path -Profile PdfA2b).IsCompliant | Should -BeTrue

        $doc = New-VellumPdfPageDocument -Conformance PdfA2b | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfPageBarcode Ean13 '5901234123457' -X 1 -Y 1 -ShowText $true } | Should -Throw 'Add-VellumPdfPageBarcode:*PDF/A forbids*'
            { $doc | Add-VellumPdfPageBarcode Ean13 'letters' -X 1 -Y 1 } | Should -Throw 'Add-VellumPdfPageBarcode:*'
            { $doc | Add-VellumPdfPageBarcode QrCode 'x' -X 1 -Y 1 -BarHeight 5 } | Should -Throw '*only applies to linear*'
        }
        finally { $doc.Dispose() }
    }

    It 'draws the human-readable line of a 1-D barcode in a normal page document' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPageBarcode Ean13 '5901234123457' -X 72 -Y 600 } 'ean'
        (Get-PdfContentText $path) | Should -Match 'Tj'
    }
}

Describe 'PDF/A page documents against the preflight' {
    It 'a rich PDF/A-2b page document (shapes, text, image, barcode, gradient, link, outline) is compliant' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfPage | Set-VellumPdfDocumentInfo -Title 'Rich' |
                Add-VellumPdfShape Rectangle -X 50 -Y 50 -Width 100 -Height 50 -FillColor navy -StrokeColor red -Opacity 0.5 |
                Add-VellumPdfShape Line -X 50 -Y 40 -X2 300 -Y2 40 -Dash 4, 2 |
                Add-VellumPdfText 'Hello' -X 72 -Y 700 |
                Add-VellumPdfGradient -X 50 -Y 300 -Width 200 -Height 80 -StartColor navy -EndColor white |
                Add-VellumPdfPageImage $script:gray16 -X 50 -Y 450 -Width 40 |
                Add-VellumPdfPageBarcode QrCode 'x' -X 300 -Y 450 -TargetWidth 80 |
                Add-VellumPdfLink -X 72 -Y 700 -Width 60 -Height 20 -Uri 'https://example.com' |
                Add-VellumPdfLink -X 72 -Y 400 -Width 60 -Height 20 -TargetPage 2 |
                Add-VellumPdfOutlineEntry 'Ch1' -TargetPage 1 | Add-VellumPdfOutlineEntry 'Sec' -TargetPage 2 -Level 2
        } 'rich-pdfa' @{ Conformance = 'PdfA2b'; Language = 'en' }
        $r = Test-VellumPdfConformance -Path $path -Profile PdfA2b
        ($r.Assertions | Where-Object Severity -EQ 'Error' | ForEach-Object { "$($_.RuleId): $($_.Message)" }) | Should -BeNullOrEmpty
        $r.IsCompliant | Should -BeTrue
    }

    It 'CMYK colour needs a CMYK output intent: warned without, compliant with' {
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage
        $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillCmyk 0, 1, 1, 0 -WarningVariable w -WarningAction SilentlyContinue | Out-Null
        @($w | Where-Object Message -Like '*CMYK output intent*').Count | Should -Be 1
        $doc.Dispose()

        $path = Save-Page {
            param($d)
            $d | Set-VellumPdfOutputIntent -Cmyk |
                Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 50 -Height 50 -FillCmyk 0, 1, 1, 0 -WarningVariable w2 |
                Add-VellumPdfText 'x' -X 72 -Y 700
        } 'cmyk' @{ Conformance = 'PdfA2b'; Language = 'en' }
        (Test-VellumPdfConformance -Path $path -Profile PdfA2b).IsCompliant | Should -BeTrue
    }
}

Describe 'Add-VellumPdfFormField' {
    It 'writes every field type into the AcroForm' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfFormField Text -Name t1 -X 72 -Y 700 -Width 200 -Height 20 -Value 'Hi' -Multiline -Required |
                Add-VellumPdfFormField CheckBox -Name c1 -X 72 -Y 670 -Width 14 -Height 14 -Checked |
                Add-VellumPdfFormField Choice -Name ch -X 72 -Y 640 -Width 150 -Height 20 -Option a, b, c -Selected b |
                Add-VellumPdfFormField Choice -Name lb -X 72 -Y 600 -Width 150 -Height 40 -Option a, b -List |
                Add-VellumPdfFormField PushButton -Name pb -X 72 -Y 560 -Width 80 -Height 24 -Caption 'Send' |
                Add-VellumPdfFormField Radio -Name rg -Selected y -RadioOption @(
                    @{ X = 300; Y = 600; Width = 14; Height = 14; ExportValue = 'x' },
                    @{ X = 330; Y = 600; Width = 14; Height = 14; ExportValue = 'y' })
        } 'form'
        $t = Get-PdfText $path
        $t | Should -Match '/AcroForm'
        foreach ($name in 't1', 'c1', 'ch', 'lb', 'pb', 'rg') { $t | Should -Match "/T \($name\)" }
        $t | Should -Match '/FT /Tx'
        $t | Should -Match '/FT /Btn'
        $t | Should -Match '/FT /Ch'
    }

    It 'refuses text the field appearance cannot draw, before saving, and keeps the document usable' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            $cjk = [string][char]0x65E5
            { $doc | Add-VellumPdfFormField Text -Name a -X 1 -Y 1 -Width 50 -Height 20 -Value $cjk } | Should -Throw '*U+65E5*cannot draw*'
            { $doc | Add-VellumPdfFormField PushButton -Name b -X 1 -Y 1 -Width 50 -Height 20 -Caption $cjk } | Should -Throw '*cannot draw*'
            { $doc | Add-VellumPdfFormField Choice -Name c -X 1 -Y 1 -Width 50 -Height 20 -Option $cjk } | Should -Throw '*cannot draw*'
            # Windows-1252 punctuation is fine.
            { $doc | Add-VellumPdfFormField Text -Name d -X 1 -Y 1 -Width 50 -Height 20 -Value ([string][char]0x20AC) } | Should -Not -Throw
            $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'ok-form.pdf') | Out-Null
        }
        catch { $doc.Dispose(); throw }
    }

    It 'validates field options' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfFormField Text -Name a -X 1 -Y 1 -Width 5 -Height 5 -FontSize 0 } | Should -Throw '*greater than 0*'
            { $doc | Add-VellumPdfFormField Text -Name a -Width 5 -Height 5 } | Should -Throw '*needs -X*'
            { $doc | Add-VellumPdfFormField Text -Name a -X 1 -Y 1 -Width 5 -Height 5 -Checked } | Should -Throw '*CheckBox only*'
            { $doc | Add-VellumPdfFormField Choice -Name a -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw '*needs -Option*'
            { $doc | Add-VellumPdfFormField Choice -Name a -X 1 -Y 1 -Width 5 -Height 5 -Option x -Selected y } | Should -Throw '*not one of*'
            { $doc | Add-VellumPdfFormField PushButton -Name a -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw '*needs -Caption*'
            { $doc | Add-VellumPdfFormField Radio -Name a } | Should -Throw '*needs -RadioOption*'
            { $doc | Add-VellumPdfFormField Radio -Name a -RadioOption @(@{ X = 1; Y = 1; Width = 5; Height = 5 }) } | Should -Throw '*ExportValue*'
            { $doc | Add-VellumPdfFormField Text -Name '' -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'is refused in a PDF/A page document, which cannot embed the field font' {
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b | Add-VellumPdfPage
        try { { $doc | Add-VellumPdfFormField Text -Name a -X 1 -Y 1 -Width 50 -Height 20 } | Should -Throw '*PDF/A forbids*' }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfLink and Add-VellumPdfOutlineEntry' {
    It 'writes URL and internal-page links' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfPage |
                Add-VellumPdfLink -X 72 -Y 700 -Width 100 -Height 14 -Uri 'https://example.com' |
                Add-VellumPdfLink -X 72 -Y 650 -Width 100 -Height 14 -TargetPage 2 -DestTop 500
        } 'links'
        $t = Get-PdfText $path
        $t | Should -Match '/URI \(https://example\.com\)'
        $t | Should -Match '/Dest \[\d+ 0 R /XYZ 0 500 null\]'
        $t | Should -Match '/F 4'
    }

    It 'applies the link scheme allowlist and requires exactly one target' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -Uri 'javascript:alert(1)' } | Should -Throw "*scheme 'javascript'*"
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -Uri 'ftp://x' } | Should -Throw '*only http, https, and mailto*'
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 } | Should -Throw '*exactly one of*'
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -Uri 'https://x.test' -TargetPage 1 } | Should -Throw '*exactly one of*'
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -Uri 'https://x.test' -DestTop 5 } | Should -Throw '*-TargetPage only*'
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -TargetPage 9 } | Should -Throw '*out of range*'
        }
        finally { $doc.Dispose() }
    }

    It 'writes nested outline entries, collapsing a parent when asked' {
        $open = Save-Page {
            param($d)
            $d | Add-VellumPdfPage | Add-VellumPdfOutlineEntry 'Chapter' -TargetPage 1 | Add-VellumPdfOutlineEntry 'Section' -TargetPage 2 -Level 2
        } 'outline-open'
        $closed = Save-Page {
            param($d)
            $d | Add-VellumPdfPage | Add-VellumPdfOutlineEntry 'Chapter' -TargetPage 1 -Collapsed | Add-VellumPdfOutlineEntry 'Section' -TargetPage 2 -Level 2
        } 'outline-closed'
        $t = Get-PdfText $open
        $t | Should -Match '/Outlines'
        $t | Should -Match (Get-Utf16Pattern 'Chapter')
        $t | Should -Not -Match '/Count -\d'
        Get-PdfText $closed | Should -Match '/Count -1'
    }

    It 'rejects level jumps and unknown pages' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfOutlineEntry 'Deep' -TargetPage 1 -Level 2 } | Should -Throw '*cannot follow an entry at level 0*'
            { $doc | Add-VellumPdfOutlineEntry 'Gone' -TargetPage 5 } | Should -Throw '*out of range*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Shared cmdlets on page documents' {
    It 'sets document info and an output intent, and registers fonts' {
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $h | Should -BeOfType ([VellumPdf.Fonts.EmbeddedFontHandle])
        $doc | Set-VellumPdfDocumentInfo -Title 'Page doc' -Author 'Me' | Add-VellumPdfText 'x' -X 72 -Y 700 -FontHandle $h |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'info.pdf') | Out-Null
        Get-PdfText (Join-Path $TestDrive 'info.pdf') | Should -Match '/Title'
    }

    It 'encrypts a page document, but not a linearized one' {
        $pw = ConvertTo-SecureString 'pw' -AsPlainText -Force
        $path = Save-Page { param($d) $d | Add-VellumPdfText 'secret' -X 72 -Y 700 | Protect-VellumPdfDocument -UserPassword $pw -OwnerPassword (ConvertTo-SecureString 'o' -AsPlainText -Force) } 'enc'
        Get-PdfText $path | Should -Match '/Encrypt'
        $lin = New-VellumPdfPageDocument -Linearize | Add-VellumPdfPage
        try { { $lin | Protect-VellumPdfDocument -UserPassword $pw } | Should -Throw '*linearized*' }
        finally { $lin.Dispose() }
    }

    It 'signs a page document' {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Page', $rsa, 'SHA256', [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))
        try {
            $path = Save-Page { param($d) $d | Add-VellumPdfText 'signed' -X 72 -Y 700 | Set-VellumPdfSignature -Certificate $cert -Reason 'test' } 'signed'
            (Get-VellumPdfInfo -Path $path).Signatures.Count | Should -Be 1
        }
        finally { $cert.Dispose(); $rsa.Dispose() }
    }

    It 'saves to a stream and as bytes, and supports -Validate for PDF/A' {
        $bytes = New-VellumPdfPageDocument | Add-VellumPdfPage | Add-VellumPdfText 'mem' -X 72 -Y 700 | Save-VellumPdfDocument -AsByteArray
        [System.Text.Encoding]::ASCII.GetString($bytes[0..4]) | Should -Be '%PDF-'
        $path = Join-Path $TestDrive 'validated.pdf'
        New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage | Add-VellumPdfText 'ok' -X 72 -Y 700 |
            Save-VellumPdfDocument -Path $path -Validate | Out-Null
        Test-Path $path | Should -BeTrue
    }

    It 'refuses a second save and disposes after saving' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage | Add-VellumPdfText 'x' -X 72 -Y 700
        $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'once.pdf') -KeepOpen | Out-Null
        try { { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'twice.pdf') -KeepOpen } | Should -Throw '*already saved*' }
        finally { $doc.Dispose() }
    }
}

Describe 'Why form fields are refused in PDF/A' {
    It 'PROOF: a form field added through the raw engine API makes the file carry non-embedded fonts' {
        $doc = New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc | Add-VellumPdfText 'Form' -X 72 -Y 720 -FontHandle $h | Out-Null
        $doc.AddTextField($doc.Pages[0], 'name', [VellumPdf.Document.PdfRectangle]::new(72, 600, 272, 620), 'x', $null)
        $path = Join-Path $TestDrive 'pdfa-form.pdf'
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        $t = Get-PdfText $path
        # The field appearance relies on Helvetica (and ZapfDingbats), neither embedded: ISO 19005-2 6.2.11.4.1
        # requires every font to be embedded. The in-process preflight does not look at fonts used only by
        # annotation appearances, so it cannot be used to detect this.
        $t | Should -Match '/BaseFont /Helvetica'
        ([regex]::Matches($t, '/FontFile2')).Count | Should -Be 1
        ([regex]::Matches($t, '/BaseFont\s*/')).Count | Should -BeGreaterThan 1
    }
}

Describe 'Arc shapes and ICC colour' {
    BeforeAll {
        $script:srgb = Join-Path $TestDrive 'srgb.icc'
        [System.IO.File]::WriteAllBytes($script:srgb, [VellumPdf.Document.IccProfiles]::Srgb)
        $script:cmykIcc = Join-Path $TestDrive 'cmyk.icc'
        [System.IO.File]::WriteAllBytes($script:cmykIcc, [VellumPdf.Document.IccProfiles]::GenericCmyk)
    }

    It 'draws an arc that starts with a move to its first point and then Bezier curves' {
        $path = Save-Page { param($d) $d | Add-VellumPdfShape Arc -X 100 -Y 100 -Radius 50 -StartAngle 0 -EndAngle 180 -StrokeWidth 2 } 'arc'
        $c = Get-PdfContentText $path
        $c | Should -Match '(?m)^150 100 m\r?\n[\d. ]+ c\r?\n[\d. ]+ c\r?\nS'
    }

    It 'validates arc parameters' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfShape Arc -X 1 -Y 1 -Radius 5 -StartAngle 0 } | Should -Throw '*needs -EndAngle*'
            { $doc | Add-VellumPdfShape Arc -X 1 -Y 1 -Radius 5 -StartAngle 0 -EndAngle 90 -Width 3 } | Should -Throw '*does not apply to an Arc*'
            { $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -Radius 3 } | Should -Throw '*applies to an Arc only*'
        }
        finally { $doc.Dispose() }
    }

    It 'fills and strokes in ICC-based colour, embedding the profile once per page' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfShape Rectangle -X 10 -Y 10 -Width 30 -Height 30 -IccProfilePath $script:srgb -FillIcc 0.2, 0.4, 0.6 |
                Add-VellumPdfShape Rectangle -X 50 -Y 10 -Width 30 -Height 30 -IccProfilePath $script:srgb -FillIcc 1, 0, 0 -StrokeIcc 0, 0, 1 |
                Add-VellumPdfShape Rectangle -X 90 -Y 10 -Width 30 -Height 30 -IccProfilePath $script:cmykIcc -FillIcc 0, 1, 1, 0
        } 'icc'
        $c = Get-PdfContentText $path
        $c | Should -Match '/VICC1 cs\r?\n0\.2 0\.4 0\.6 scn'
        $c | Should -Match '/VICC1 CS\r?\n0 0 1 SCN'
        $c | Should -Match '/VICC2 cs\r?\n0 1 1 0 scn'
        ([regex]::Matches((Get-PdfText $path), '/ICCBased')).Count | Should -Be 2   # sRGB once + CMYK once
    }

    It 'validates ICC parameters' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            $r = @{ X = 1; Y = 1; Width = 5; Height = 5 }
            { $doc | Add-VellumPdfShape Rectangle @r -FillIcc 0, 0, 0 } | Should -Throw '*go together*'
            { $doc | Add-VellumPdfShape Rectangle @r -IccProfilePath $script:srgb -FillIcc 0, 0 } | Should -Throw '*needs 3 value(s)*'
            { $doc | Add-VellumPdfShape Rectangle @r -IccProfilePath $script:srgb -FillIcc 0, 0, 0 -FillColor red } | Should -Throw '*not several*'
            { $doc | Add-VellumPdfShape Rectangle @r -IccProfilePath (Join-Path $TestDrive 'nope.icc') -FillIcc 0, 0, 0 } | Should -Throw '*ICC profile not found*'
            $junk = Join-Path $TestDrive 'junk.icc'
            [System.IO.File]::WriteAllBytes($junk, [byte[]](1..200))
            { $doc | Add-VellumPdfShape Rectangle @r -IccProfilePath $junk -FillIcc 0, 0, 0 } | Should -Throw '*not an ICC profile*'
        }
        finally { $doc.Dispose() }
    }

    It 'keeps a PDF/A-2b page document with ICC colour compliant' {
        $path = Save-Page { param($d) $d | Add-VellumPdfShape Rectangle -X 10 -Y 10 -Width 30 -Height 30 -IccProfilePath $script:srgb -FillIcc 0.2, 0.4, 0.6 | Add-VellumPdfText 'x' -X 72 -Y 700 } 'icc-pdfa' @{ Conformance = 'PdfA2b'; Language = 'en' }
        (Test-VellumPdfConformance -Path $path -Profile PdfA2b).IsCompliant | Should -BeTrue
    }
}

Describe 'Options that must not be silently ignored' {
    It 'a fill-only shape still gets the outline its stroke options ask for' {
        $path = Save-Page { param($d) $d | Add-VellumPdfShape Rectangle -X 10 -Y 10 -Width 50 -Height 50 -FillColor yellow -StrokeWidth 3 -Dash 4, 2 } 'fillstroke'
        $c = Get-PdfContentText $path
        $c | Should -Match '3 w'
        $c | Should -Match '\[4 2\] 0 d'
        $c | Should -Match '\nB\n'
    }

    It 'rejects a position on a radio group and a non-finite -DestTop' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage -Count 2
        try {
            $ro = @(@{ X = 1; Y = 1; Width = 5; Height = 5; ExportValue = 'a' })
            { $doc | Add-VellumPdfFormField Radio -Name g -X 5 -RadioOption $ro } | Should -Throw '*does not apply to -Type Radio*'
            { $doc | Add-VellumPdfLink -X 1 -Y 1 -Width 5 -Height 5 -TargetPage 2 -DestTop ([double]::NaN) } | Should -Throw '*-DestTop must be finite*'
            { $doc | Add-VellumPdfOutlineEntry 'x' -TargetPage 2 -DestTop ([double]::PositiveInfinity) } | Should -Throw '*-DestTop must be finite*'
        }
        finally { $doc.Dispose() }
    }
}
