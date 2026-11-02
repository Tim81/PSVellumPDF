#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Use-VellumPdfTransform, -Rotation on text and images, Measure-VellumPdfText, grey colours and
# the signature bytes of Get-VellumPdfInfo.

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    $script:photo = Join-Path $PSScriptRoot 'assets' 'photo.jpg'
    $script:render = [bool]((Get-Command pdftoppm -ErrorAction SilentlyContinue) -and (Get-Command convert -ErrorAction SilentlyContinue))
    function script:New-Page([double]$Mm = 35.2778) { New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm $Mm -PageHeightMm $Mm }   # 100 x 100 pt
    function script:Save-It($Doc, [string]$Name) { $p = Join-Path $TestDrive "$Name.pdf"; $Doc | Save-VellumPdfDocument -Path $p | Out-Null; $p }
    # "WxH+X+Y" of the dark pixels of page 1 rendered at 72 dpi (origin top-left), or $null without renderer tools.
    function script:Get-InkBox([string]$Pdf) {
        if (-not $script:render) { return $null }
        $base = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & pdftoppm -r 72 -gray -png -f 1 -l 1 $Pdf $base
        $png = (Get-ChildItem "$base*.png" | Select-Object -First 1).FullName
        (& convert $png -fuzz 20% -trim -format '%wx%h%O' info:)
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Use-VellumPdfTransform' {
    It 'writes the matrix for rotation about an origin, scale, mirror and translation' -ForEach @(
        @{ Name = 'rotate 90 about the origin'; Params = @{ Rotate = 90 }; Matrix = '0 1 -1 0 0 0' }
        @{ Name = 'rotate 90 about (100,100)'; Params = @{ Rotate = 90; OriginX = 100; OriginY = 100 }; Matrix = '0 1 -1 0 200 0' }
        @{ Name = 'scale 2'; Params = @{ Scale = 2 }; Matrix = '2 0 0 2 0 0' }
        @{ Name = 'scale 2 and 3 about (10,10)'; Params = @{ Scale = 2, 3; OriginX = 10; OriginY = 10 }; Matrix = '2 0 0 3 -10 -20' }
        @{ Name = 'mirror horizontally'; Params = @{ Scale = -1, 1 }; Matrix = '-1 0 0 1 0 0' }
        @{ Name = 'translate'; Params = @{ TranslateX = 5; TranslateY = -7 }; Matrix = '1 0 0 1 5 -7' }
    ) {
        $pdf = Save-It (New-Page | Use-VellumPdfTransform @Params -ScriptBlock { $_ | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor red }) 'matrix'
        (Get-PdfContentText $pdf) | Should -Match "(?m)^$([regex]::Escape($Matrix)) cm$"
    }

    It 'turns the drawing: a rectangle rotated 90 degrees about the page centre' -Skip:(-not $script:render) {
        $pdf = Save-It (New-Page | Use-VellumPdfTransform -Rotate 90 -OriginX 50 -OriginY 50 -ScriptBlock {
                $_ | Add-VellumPdfShape Rectangle -X 40 -Y 40 -Width 20 -Height 10 -FillColor black
            }) 'rotated-box'
        # x 50..60, y 40..60 in page coordinates: 10 x 20 pixels at (50, 40) from the top-left.
        Get-InkBox $pdf | Should -Be '10x20+50+40'
    }

    It 'balances the graphics state when the block throws, and drops the block output' {
        $doc = New-Page
        { $doc | Use-VellumPdfTransform -Rotate 10 -ScriptBlock { throw 'boom' } } | Should -Throw '*boom*'
        $out = @($doc | Use-VellumPdfTransform -Scale 2 -ScriptBlock { 'noise'; 42 })
        $out.Count | Should -Be 1
        $out[0] | Should -BeOfType ([VellumPdf.Document.PdfDocument])
        $pdf = Save-It $doc 'balanced'
        $c = Get-PdfContentText $pdf
        ([regex]::Matches($c, '(?m)^q$')).Count | Should -Be ([regex]::Matches($c, '(?m)^Q$')).Count
    }

    It 'nests, and carries its page to the drawing inside' {
        $doc = New-Page | Add-VellumPdfPage
        $pdf = Save-It ($doc | Use-VellumPdfTransform -Page 2 -Scale 2 -ScriptBlock {
                $_ | Use-VellumPdfTransform -TranslateX 3 -ScriptBlock { $_ | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 4 -Height 4 -FillColor green }
            }) 'nested-transform'
        $content = Get-PdfContentText $pdf
        $content | Should -Match '(?s)2 0 0 2 0 0 cm.*1 0 0 1 3 0 cm.*1 1 4 4 re'
        $second = New-Page | Add-VellumPdfPage
        $warnings = @($second | Use-VellumPdfTransform -Page 1 -Rotate 5 -ScriptBlock {
                $_ | Add-VellumPdfShape Rectangle -Page 2 -X 0 -Y 0 -Width 1 -Height 1 -FillColor red
            } 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        "$($warnings[0].Message)" | Should -Match 'differs from the enclosing scope'
        $second.Dispose()
    }

    It 'rejects values that cannot make a matrix' {
        $doc = New-Page
        try {
            { $doc | Use-VellumPdfTransform -Scale 0 -ScriptBlock { } } | Should -Throw '*not zero*'
            { $doc | Use-VellumPdfTransform -Rotate ([double]::PositiveInfinity) -ScriptBlock { } } | Should -Throw '*finite*'
            { $doc | Use-VellumPdfTransform -TranslateX 99999 -ScriptBlock { } } | Should -Throw '*between -14400 and 14400*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Rotation of text and images' {
    It 'rotates text about its anchor, and aligns along the rotated baseline' {
        $pdf = Save-It (New-Page | Add-VellumPdfText 'Up' -X 40 -Y 30 -Rotation 90 | Add-VellumPdfText 'Mid' -X 60 -Y 50 -Rotation 90 -Align Center) 'text-rotation'
        $c = Get-PdfContentText $pdf
        $c | Should -Match '(?m)^0 1 -1 0 40 30 cm$'
        $c | Should -Match '(?m)^0 1 -1 0 60 50 cm$'
        $c | Should -Match '1 0 0 1 0 0 Tm\r?\n\(Up\) Tj'
        # Centred: the start is shifted back by half the width, along the rotated baseline.
        $half = (Measure-VellumPdfText 'Mid' -FontSize 12).Width / 2
        $c | Should -Match ('1 0 0 1 -' + [regex]::Escape(([math]::Round($half, 5)).ToString([cultureinfo]::InvariantCulture)) + ' 0 Tm')
    }

    It 'draws rotated text upwards on the page' -Skip:(-not $script:render) {
        $pdf = Save-It (New-Page | Add-VellumPdfText 'Vertical text' -X 50 -Y 10 -FontSize 14 -Rotation 90) 'vertical-text'
        $box = Get-InkBox $pdf
        $w, $h = ($box -split '[x+]')[0, 1] | ForEach-Object { [int]$_ }
        $h | Should -BeGreaterThan ($w * 3)
    }

    It 'rotates an image about its centre' {
        $pdf = Save-It (New-Page | Add-VellumPdfPageImage $script:photo -X 10 -Y 10 -Width 40 -Height 20 -Rotation 90 -AltText 'photo') 'image-rotation'
        (Get-PdfContentText $pdf) | Should -Match '(?m)^0 40 -20 0 40 0 cm$'
    }

    It 'leaves the matrix alone without a rotation, and rejects a non-finite one' {
        $pdf = Save-It (New-Page | Add-VellumPdfPageImage $script:photo -X 10 -Y 10 -Width 40 -Height 20 -AltText 'photo') 'image-plain'
        (Get-PdfContentText $pdf) | Should -Match '(?m)^40 0 0 20 10 10 cm$'
        { New-Page | Add-VellumPdfText 'x' -X 1 -Y 1 -Rotation ([double]::NaN) } | Should -Throw '*finite*'
    }

    It 'keeps rotated text tagged: one paragraph in a PDF/UA-1 document' {
        $ua = Join-Path $TestDrive 'rot-ua.pdf'
        New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US | Add-VellumPdfPage | Set-VellumPdfDocumentInfo -Title 'Rot' |
            Add-VellumPdfText 'Sideways' -X 100 -Y 100 -Rotation 90 | Save-VellumPdfDocument -Path $ua -Validate | Out-Null
        (Test-VellumPdfConformance -Path $ua -Profile PdfUA1).IsCompliant | Should -BeTrue
    }
}

Describe 'Measure-VellumPdfText' {
    It 'measures a base-14 font exactly like the engine' {
        (Measure-VellumPdfText 'Hello' -FontSize 12).Width | Should -Be 27.336
        (Measure-VellumPdfText 'Hello' -FontSize 24).Width | Should -Be 54.672
        (Measure-VellumPdfText 'Hello' -FontSize 12 -Font HelveticaBold).Width | Should -BeGreaterThan 27.336
        (Measure-VellumPdfText '' ).Width | Should -Be 0
    }

    It 'adds character spacing, word spacing and scaling' {
        $plain = (Measure-VellumPdfText 'a b' -FontSize 10).Width
        (Measure-VellumPdfText 'a b' -FontSize 10 -CharSpacing 1).Width | Should -Be ($plain + 3)
        (Measure-VellumPdfText 'a b' -FontSize 10 -WordSpacing 4).Width | Should -Be ($plain + 4)
        (Measure-VellumPdfText 'a b' -FontSize 10 -HorizontalScale 50).Width | Should -Be ($plain / 2)
    }

    It 'measures an embedded font, and reports missing glyphs and unencodable characters' {
        $doc = New-Page
        $font = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $m = Measure-VellumPdfText "Zażółć $([char]0x65E5)" -FontSize 12 -FontHandle $font
        $m.Width | Should -Be ([math]::Round($font.MeasureString("Zażółć $([char]0x65E5)", 12), 4))
        $m.MissingGlyphs | Should -Be ([string][char]0x65E5)
        $m.Font | Should -Be 'embedded'
        $s = Measure-VellumPdfText "caf$([char]0xE9) $([char]0x017C)" -FontSize 12
        $s.UnencodableCharacters | Should -Be ([string][char]0x017C)
        $doc.Dispose()
    }

    It 'agrees with the width Add-VellumPdfText uses to right-align' {
        $width = (Measure-VellumPdfText 'Right' -FontSize 12).Width
        $pdf = Save-It (New-Page | Add-VellumPdfText 'Right' -X 90 -Y 50 -Align Right) 'align'
        $x = [double][regex]::Match((Get-PdfContentText $pdf), '1 0 0 1 ([\d.]+) 50 Tm').Groups[1].Value
        $x | Should -Be ([math]::Round(90 - $width, 3)) -Because 'PDF content keeps five decimals; the width is rounded to four'
    }

    It 'takes pipeline input and refuses several lines' {
        @('a', 'bb') | Measure-VellumPdfText | ForEach-Object Width | Should -HaveCount 2
        { Measure-VellumPdfText "a`nb" } | Should -Throw '*single line*'
    }
}

Describe 'Grey colours' {
    It 'writes DeviceGray fill and stroke for shapes and paths' {
        $pdf = Save-It (New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillGray 0.5 -StrokeGray 0.2 |
                Add-VellumPdfPath 'M 0 0 L 9 9' -StrokeGray 0.8 | Add-VellumPdfPath 'M 0 0 L 9 0 L 9 9 Z' -FillGray 1) 'gray'
        $c = Get-PdfContentText $pdf
        $c | Should -Match '(?m)^0\.5 g$'
        $c | Should -Match '(?m)^0\.2 G$'
        $c | Should -Match '(?m)^0\.8 G$'
        $c | Should -Match '(?m)^1 g$'
    }

    It 'refuses to mix a grey with another colour model, and a fill on a line' {
        { New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillGray 0.5 -FillColor red } | Should -Throw '*not several*'
        { New-Page | Add-VellumPdfPath 'M 0 0 L 1 1' -StrokeGray 0.5 -StrokeCmyk 0, 0, 0, 1 } | Should -Throw '*not several*'
        { New-Page | Add-VellumPdfShape Line -X 0 -Y 0 -X2 5 -Y2 5 -FillGray 0.5 } | Should -Throw '*a Line has no fill*'
        { New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillGray 1.5 } | Should -Throw
    }

    It 'passes the PDF/A-2b preflight' {
        $pdf = Join-Path $TestDrive 'gray-a2b.pdf'
        New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage |
            Add-VellumPdfShape Rectangle -X 10 -Y 10 -Width 50 -Height 50 -FillGray 0.4 -StrokeGray 0 | Save-VellumPdfDocument -Path $pdf -Validate | Out-Null
        (Test-VellumPdfConformance -Path $pdf -Profile PdfA2b).IsCompliant | Should -BeTrue
    }
}

Describe 'Get-VellumPdfInfo -IncludeSignatureContents' {
    It 'returns the CMS bytes, which verify against the signed byte ranges' {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Info Test', $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $cert = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))
        try {
            $pdf = Join-Path $TestDrive 'signed-info.pdf'
            New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Signed' | Set-VellumPdfSignature -Certificate $cert | Save-VellumPdfDocument -Path $pdf | Out-Null
            $plain = Get-VellumPdfInfo -Path $pdf
            $plain.Signatures[0].PSObject.Properties.Name | Should -Not -Contain 'Contents'
            $info = Get-VellumPdfInfo -Path $pdf -IncludeSignatureContents
            $signature = $info.Signatures[0]
            $signature.Contents.Length | Should -Be $signature.ContentsLength
            $bytes = [System.IO.File]::ReadAllBytes($pdf)
            $a, $b, $c, $d = $signature.ByteRange
            $signed = [byte[]]::new($b + $d)
            [Array]::Copy($bytes, $a, $signed, 0, $b)
            [Array]::Copy($bytes, $c, $signed, $b, $d)
            $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new([System.Security.Cryptography.Pkcs.ContentInfo]::new($signed), $true)
            $cms.Decode($signature.Contents)
            { $cms.CheckSignature($true) } | Should -Not -Throw
        }
        finally { $cert.Dispose(); $rsa.Dispose() }
    }
}
