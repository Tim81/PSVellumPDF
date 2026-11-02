#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Regression tests for the flow-document review fixes: list recursion guard, case-insensitive PAdES level,
# embedded fonts in conformant flow documents, non-finite numbers, drawing capture and balance, form-field
# selection spelling, table row shapes and spans, and output-intent handling.

param()

BeforeAll {
    $script:manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $script:manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    $script:photo = Join-Path $PSScriptRoot 'assets' 'photo.jpg'
    $script:gray = Join-Path $PSScriptRoot 'assets' 'gray16.png'
    $script:srgbBytes = [VellumPdf.Document.IccProfiles]::Srgb
    function script:New-Page { param([string]$Conformance = 'PdfA2b') New-VellumPdfPageDocument -Conformance $Conformance | Add-VellumPdfPage }
    function script:Get-IccFile { param([string]$Name, [scriptblock]$Patch)
        $bytes = [byte[]]$script:srgbBytes.Clone()
        if ($Patch) { & $Patch $bytes }
        $path = Join-Path $TestDrive $Name
        [System.IO.File]::WriteAllBytes($path, $bytes)
        $path
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfList refuses cyclic and over-deep items before recursing into a crash' {
    It 'reports the depth error with -FontHandle instead of overflowing the stack (child process)' {
        $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source ?? (Get-Process -Id $PID).Path
        $script = @"
Import-Module '$($script:manifest)'
`$d = New-VellumPdfDocument
`$h = Register-VellumPdfFont -Document `$d -Path '$($script:fontPath)'
`$a = @{ Text = 'a' }
`$a.Children = @(`$a)
try { `$d | Add-VellumPdfList -Item `$a -FontHandle `$h | Out-Null; 'NO ERROR' } catch { Write-Output "CAUGHT: `$(`$_.Exception.Message)" }
"@
        $output = & $pwsh -NoProfile -Command $script 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'CAUGHT: Add-VellumPdfList: nested -Item exceeds the maximum depth'
    }

    It 'still reports the depth error without a font handle' {
        $a = @{ Text = 'a' }
        $a.Children = @($a)
        { New-VellumPdfDocument | Add-VellumPdfList -Item $a } | Should -Throw '*maximum depth*'
    }
}

Describe 'Set-VellumPdfSignature -Level is case-insensitive' {
    BeforeAll {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Level Case', $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $script:caseCert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))
        $script:caseRsa = $rsa
    }
    AfterAll { $script:caseCert.Dispose(); $script:caseRsa.Dispose() }

    It 'accepts <Level> (ValidateSet is case-insensitive)' -ForEach @(
        @{ Level = 'b-b'; Expected = 'B_B'; Timestamp = $false }
        @{ Level = 'b-t'; Expected = 'B_T'; Timestamp = $true }
        @{ Level = 'b-lt'; Expected = 'B_LT'; Timestamp = $true }
        @{ Level = 'B-lta'; Expected = 'B_LTA'; Timestamp = $true }
    ) {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            $args2 = @{ Certificate = $script:caseCert; Level = $Level }
            if ($Timestamp) { $args2['TimestampUrl'] = 'http://localhost:9/tsa' }
            $doc | Set-VellumPdfSignature @args2 | Out-Null
            $doc.PSVellumSignature.Level.ToString() | Should -Be $Expected
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Conformant flow documents embed Liberation substitutes for base-14 fonts' {
    It 'passes <Profile> preflight for the plain paragraph + heading document' -ForEach @(
        @{ Profile = 'PdfA2b' }, @{ Profile = 'PdfUA1' }
    ) {
        $path = Join-Path $TestDrive "basic-$Profile.pdf"
        New-VellumPdfDocument -Conformance $Profile -Language en | Set-VellumPdfDocumentInfo -Title 'T' |
            Add-VellumPdfParagraph -Text 'Hello' | Add-VellumPdfHeading -Text 'Head' -Level 1 |
            Save-VellumPdfDocument -Path $path | Out-Null
        $check = Test-VellumPdfConformance -Path $path -Profile $Profile
        $check.Errors | Should -BeNullOrEmpty
        $check.IsCompliant | Should -BeTrue
        $text = Get-PdfText $path
        $text | Should -Match '/BaseFont\s*/[A-Z]{6}\+LiberationSans-Bold'
        $text | Should -Not -Match '/BaseFont\s*/Helvetica'
    }

    It 'covers every flow element and the matching bold, italic and family variants' {
        $path = Join-Path $TestDrive 'all-elements.pdf'
        $run = New-VellumPdfTextRun -Text 'bold ' -Font HelveticaBold
        $plain = New-VellumPdfTextRun -Text 'plain '
        $sized = New-VellumPdfTextRun -Text 'sized' -FontSize 20 -Color red
        New-VellumPdfDocument -Conformance PdfA2b -Language en -DefaultFont TimesRoman |
            Set-VellumPdfDocumentInfo -Title 'T' |
            Set-VellumPdfHeader -Template 'Head {page}' | Set-VellumPdfFooter -Template 'Foot' -Font CourierOblique |
            Add-VellumPdfParagraph -Text 'default' | Add-VellumPdfParagraph -Text 'cb' -Font CourierBold |
            Add-VellumPdfParagraph -Text 'size only' -FontSize 20 | Add-VellumPdfParagraph -Run $run, $plain, $sized |
            Add-VellumPdfHeading -Text 'H' -Level 2 -Font TimesBoldItalic |
            Add-VellumPdfTable -Header 'A', 'B' -Row @(, @('1', @{ Text = 'x'; Font = 'TimesItalic' })) -Font Courier |
            Add-VellumPdfList -Item 'a', @{ Text = 'b'; Children = @('c'); Font = 'HelveticaOblique' } -Style OrderedDecimal |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Test-VellumPdfConformance -Path $path -Profile PdfA2b).IsCompliant | Should -BeTrue
        $text = Get-PdfText $path
        foreach ($face in 'LiberationSerif', 'LiberationSerif-BoldItalic', 'LiberationSerif-Italic', 'LiberationMono',
            'LiberationMono-Bold', 'LiberationMono-Italic', 'LiberationSans-Bold', 'LiberationSans-Italic') {
            $text | Should -Match "/BaseFont\s*/[A-Z]{6}\+$([regex]::Escape($face))\b" -Because $face
        }
    }

    It 'does not change the layout: line breaks match the plain base-14 document' {
        $long = (1..60 | ForEach-Object { "word$_ lorem ipsum, dolor Sit AMET" }) -join ' '
        $lines = foreach ($c in 'None', 'PdfA2b') {
            $p = Join-Path $TestDrive "wrap-$c.pdf"
            New-VellumPdfDocument -Conformance $c | Add-VellumPdfParagraph -Text $long -Alignment Justify |
                Add-VellumPdfParagraph -Text $long -Font TimesItalic | Save-VellumPdfDocument -Path $p | Out-Null
            , @((& pdftotext -layout $p - 2>$null) -replace '\s+', ' ')
        }
        $lines[1] | Should -Be $lines[0]
    } -Skip:(-not (Get-Command pdftotext -ErrorAction SilentlyContinue))

    It 'keeps plain base-14 fonts, and embeds nothing, without -Conformance' {
        $path = Join-Path $TestDrive 'plain.pdf'
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Hello' -Font CourierBold | Save-VellumPdfDocument -Path $path | Out-Null
        $text = Get-PdfText $path
        $text | Should -Match '/BaseFont\s*/Courier-Bold'
        $text | Should -Not -Match 'Liberation'
        $text | Should -Not -Match '/FontFile'
    }

    It 'does not write an empty link annotation for a colour-only text run' {
        $path = Join-Path $TestDrive 'run-link.pdf'
        New-VellumPdfDocument | Add-VellumPdfParagraph -Run (New-VellumPdfTextRun -Text 'a' -Color red) |
            Save-VellumPdfDocument -Path $path | Out-Null
        Get-PdfText $path | Should -Not -Match '/Subtype\s*/Link'
    }

    It 'refuses Symbol in a conformant document and points to -FontHandle' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language en
        try { { $doc | Add-VellumPdfParagraph -Text 'x' -Font Symbol } | Should -Throw '*no embeddable substitute*-FontHandle*' }
        finally { $doc.Dispose() }
    }

    It 'leaves the caller''s text run untouched (reusable in another document)' {
        $run = New-VellumPdfTextRun -Text 'r' -Font HelveticaBold
        New-VellumPdfDocument -Conformance PdfA2b | Add-VellumPdfParagraph -Run $run | Out-Null
        $run.Style.FontRef.IsEmbedded | Should -BeFalse
    }
}

Describe 'Non-finite numbers are refused up front' {
    It 'rejects NaN in a colour for <Name>' -ForEach @(
        @{ Name = 'Add-VellumPdfShape -FillColor'; Run = { New-Page 'None' | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor 'NaN', 0, 0 } }
        @{ Name = 'Add-VellumPdfText -Color'; Run = { New-Page 'None' | Add-VellumPdfText 'a' -X 1 -Y 1 -Color 0, 'NaN', 0 } }
        @{ Name = 'Add-VellumPdfTable -HeaderBackground'; Run = { New-VellumPdfDocument | Add-VellumPdfTable -Header 'a' -Row @(, @('x')) -HeaderBackground ([double]::NaN), 0, 0 } }
        @{ Name = 'an Infinity component'; Run = { New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'a' -Color ([double]::PositiveInfinity), 0, 0 } }
    ) {
        { & $Run } | Should -Throw '*finite*'
    }

    It 'rejects a non-finite <What> in <Name>' -ForEach @(
        @{ Name = 'a table rich cell'; What = 'FontSize'; Run = { New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; FontSize = [double]::NaN })) } }
        @{ Name = 'a table rich cell'; What = 'Leading'; Run = { New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @(@{ Text = 'x'; Leading = [double]::PositiveInfinity })) } }
        @{ Name = 'a list item'; What = 'FontSize'; Run = { New-VellumPdfDocument | Add-VellumPdfList -Item @{ Text = 'x'; FontSize = [double]::NaN } } }
        @{ Name = 'a list item'; What = 'Leading'; Run = { New-VellumPdfDocument | Add-VellumPdfList -Item @{ Text = 'x'; Leading = [double]::NaN } } }
    ) {
        { & $Run } | Should -Throw "*$What must be between*"
    }
}

Describe 'Add-VellumPdfDrawing' {
    It 'draws with the loop variable''s value at the time of the call' {
        $script:drawn = [System.Collections.Generic.List[int]]::new()
        $doc = New-VellumPdfDocument
        foreach ($i in 1..3) { $doc = $doc | Add-VellumPdfDrawing -Height 20 { $script:drawn.Add($i) } }
        $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'loop.pdf') | Out-Null
        $script:drawn | Should -Be 1, 2, 3
    }

    It 'keeps a function''s locals alive until the save' {
        $script:drawn = [System.Collections.Generic.List[int]]::new()
        function script:Build-Local { $local = 42; New-VellumPdfDocument | Add-VellumPdfDrawing -Height 20 { $script:drawn.Add($local) } }
        Build-Local | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'local.pdf') | Out-Null
        $script:drawn | Should -Be 42
    }

    It 'still passes (canvas, box, ctx) and keeps $script: assignments visible' {
        $script:info = $null
        $script:marker = 'before'
        New-VellumPdfDocument | Add-VellumPdfDrawing -Height 20 { param($canvas, $box, $ctx) $script:info = "$($canvas.GetType().Name) $($box.Height) $($ctx.GetType().Name)"; $script:marker = 'after' } |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'args.pdf') | Out-Null
        $script:info | Should -Be 'PdfCanvas 20 DrawContext'
        $script:marker | Should -Be 'after'
    }

    It 'fails the save naming Add-VellumPdfDrawing when the block <Case>' -ForEach @(
        @{ Case = 'leaves a SaveState open'; Block = { param($c) $c.SaveState() | Out-Null } }
        @{ Case = 'restores more often than it saves'; Block = { param($c) $c.RestoreState() | Out-Null } }
        @{ Case = 'saves and restores unevenly in the middle'; Block = { param($c) $c.SaveState().RestoreState().RestoreState().SaveState() | Out-Null } }
    ) {
        $doc = New-VellumPdfDocument | Add-VellumPdfDrawing -Height 20 $Block
        try { { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'unbalanced.pdf') } | Should -Throw '*Add-VellumPdfDrawing: the script block saved and restored*' }
        finally { try { $doc.Dispose() } catch { Write-Verbose "disposed: $_" } }
    }

    It 'accepts a balanced block with nested SaveState/RestoreState' {
        $path = Join-Path $TestDrive 'balanced.pdf'
        New-VellumPdfDocument | Add-VellumPdfDrawing -Height 20 { param($c, $b) $c.SaveState().Rectangle($b.X, $b.Y, 5, 5).Fill().RestoreState() | Out-Null } |
            Save-VellumPdfDocument -Path $path | Out-Null
        Test-Path $path | Should -BeTrue
    }
}

Describe 'Add-VellumPdfFormField -Selected writes the option''s own spelling' {
    BeforeAll {
        function script:Get-FieldText([scriptblock]$Build, [string]$Name) {
            $doc = & $Build
            $path = Join-Path $TestDrive "$Name.pdf"
            $doc | Save-VellumPdfDocument -Path $path | Out-Null
            $plain = Join-Path $TestDrive "$Name-qdf.pdf"
            & qpdf --qdf --object-streams=disable $path $plain 2>&1 | Out-Null
            Get-PdfText $plain
        }
    }

    It 'stores the choice entry as spelled in -Option' {
        $text = Get-FieldText { New-Page 'None' | Add-VellumPdfFormField Choice -Name c -X 72 -Y 700 -Width 100 -Height 20 -Option 'Apple', 'Pear' -Selected 'apple' } 'choice'
        $text | Should -Match '/V \(Apple\)'
    } -Skip:(-not (Get-Command qpdf -ErrorAction SilentlyContinue))

    It 'switches the matching radio button on' {
        $text = Get-FieldText {
            New-Page 'None' | Add-VellumPdfFormField Radio -Name r -Selected 'large' -RadioOption @(
                @{ X = 72; Y = 600; Width = 14; Height = 14; ExportValue = 'Small' },
                @{ X = 72; Y = 580; Width = 14; Height = 14; ExportValue = 'Large' })
        } 'radio'
        $text | Should -Match '/V /Large'
        $text | Should -Match '/AS /Large'
    } -Skip:(-not (Get-Command qpdf -ErrorAction SilentlyContinue))

    It 'prefers an exact-case match and refuses an ambiguous one' {
        $doc = New-Page 'None'
        { $doc | Add-VellumPdfFormField Choice -Name c1 -X 1 -Y 1 -Width 50 -Height 20 -Option 'Apple', 'APPLE' -Selected 'APPLE' } | Should -Not -Throw
        { $doc | Add-VellumPdfFormField Choice -Name c2 -X 1 -Y 1 -Width 50 -Height 20 -Option 'Apple', 'APPLE' -Selected 'apple' } | Should -Throw '*differ only in case*'
        { $doc | Add-VellumPdfFormField Choice -Name c3 -X 1 -Y 1 -Width 50 -Height 20 -Option 'Apple' -Selected 'pear' } | Should -Throw '*not one of*'
    }
}

Describe 'Add-VellumPdfTable row shapes' {
    It 'refuses a plain multi-key hashtable row and names the alternatives' {
        { New-VellumPdfDocument | Add-VellumPdfTable -Row @(@{ Name = 'a'; Age = 3; City = 'x' }) } | Should -Throw '*[[]ordered]@{*'
    }

    It 'keeps the column order of [ordered] dictionaries and pscustomobjects' {
        foreach ($rows in @(
                @([ordered]@{ Name = 'a'; Age = 3; City = 'x' }),
                @([pscustomobject]@{ Name = 'a'; Age = 3; City = 'x' }))) {
            $path = Join-Path $TestDrive 'ordered.pdf'
            New-VellumPdfDocument | Add-VellumPdfTable -Row $rows | Save-VellumPdfDocument -Path $path | Out-Null
            ((& pdftotext -layout $path - 2>$null | Out-String) -replace '\s+', ' ') | Should -Match 'Name Age City a 3 x'
        }
    } -Skip:(-not (Get-Command pdftotext -ErrorAction SilentlyContinue))

    It 'accepts a single-key hashtable row' {
        { New-VellumPdfDocument | Add-VellumPdfTable -Row @(@{ Name = 'a' }) } | Should -Not -Throw
    }

    It 'draws a header-only table for an empty -Row' {
        $path = Join-Path $TestDrive 'header-only.pdf'
        New-VellumPdfDocument | Add-VellumPdfTable -Header 'Alpha', 'Beta' -Row @() | Save-VellumPdfDocument -Path $path | Out-Null
        (Get-VellumPdfText -Path $path) | Should -Match 'Alpha'
        { New-VellumPdfDocument | Add-VellumPdfTable -Header 'A' -Row $null } | Should -Not -Throw
    }

    It 'refuses an empty -Row without -Header' {
        { New-VellumPdfDocument | Add-VellumPdfTable -Row @() } | Should -Throw '*-Row is empty*-Header*'
    }

    It 'validates <Key> before laying out the grid' -ForEach @(
        @{ Key = 'ColSpan'; Cell = @{ Text = 'a'; ColSpan = 'two' }; Shown = 'two' }
        @{ Key = 'RowSpan'; Cell = @{ Text = 'a'; RowSpan = 0 }; Shown = '0' }
        @{ Key = 'ColSpan'; Cell = @{ Text = 'a'; ColSpan = 1.5 }; Shown = '1.5' }
    ) {
        { New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @($Cell, 'b')) } |
            Should -Throw "*rich-cell $Key must be a whole number from 1 to 1000; got '$Shown'*"
        { New-VellumPdfDocument | Add-VellumPdfTable -Header @($Cell) -Row @(, @('b')) } |
            Should -Throw "*rich-cell $Key must be a whole number*"
    }
}

Describe 'Output intents' {
    It 'warns once when RGB colour is drawn with a CMYK output intent' {
        $doc = New-Page | Set-VellumPdfOutputIntent -Cmyk
        $null = $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor red -WarningVariable w1 -WarningAction SilentlyContinue
        $w1 | Should -Match 'output intent is CMYK'
        $null = $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor blue -WarningVariable w2 -WarningAction SilentlyContinue
        $w2 | Should -BeNullOrEmpty
    }

    It 'warns for an RGB image but not for a grey one, and not without a CMYK intent' {
        $cmyk = New-Page | Set-VellumPdfOutputIntent -Cmyk
        $null = $cmyk | Add-VellumPdfPageImage -Path $script:gray -X 1 -Y 1 -Width 20 -WarningVariable wGray -WarningAction SilentlyContinue
        $wGray | Should -BeNullOrEmpty
        $null = $cmyk | Add-VellumPdfPageImage -Path $script:photo -X 1 -Y 1 -Width 20 -WarningVariable wRgb -WarningAction SilentlyContinue
        $wRgb | Should -Match 'RGB image'
        $plain = New-Page
        $null = $plain | Add-VellumPdfPageImage -Path $script:photo -X 1 -Y 1 -Width 20 -WarningVariable wNone -WarningAction SilentlyContinue
        $wNone | Should -BeNullOrEmpty
    }

    It 'warns for RGB colour in a flow document with a CMYK intent' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b | Set-VellumPdfOutputIntent -Cmyk
        $null = $doc | Add-VellumPdfParagraph -Text 'x' -Color red -WarningVariable w -WarningAction SilentlyContinue
        $w | Should -Match 'output intent is CMYK'
    }

    It 'forgets the CMYK intent when a later RGB profile replaces it' {
        $srgb = Get-IccFile 'srgb.icc'
        $doc = New-Page | Set-VellumPdfOutputIntent -Cmyk
        $doc.PSObject.Properties['PSVellumCmykIntent'] | Should -Not -BeNullOrEmpty
        $doc | Set-VellumPdfOutputIntent -IccProfilePath $srgb -OutputConditionIdentifier 'sRGB' | Out-Null
        $doc.PSObject.Properties['PSVellumCmykIntent'] | Should -BeNullOrEmpty
        $null = $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillCmyk 0, 1, 1, 0 -WarningVariable w -WarningAction SilentlyContinue
        $w | Should -Match 'CMYK output intent'
        $null = $doc | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillColor red -WarningVariable w2 -WarningAction SilentlyContinue
        $w2 | Should -BeNullOrEmpty
    }

    It 'refuses an output intent profile with device class <Class>' -ForEach @(
        @{ Class = 'abst' }, @{ Class = 'link' }, @{ Class = 'nmcl' }
    ) {
        $path = Get-IccFile "class-$Class.icc" { param($b) [System.Text.Encoding]::ASCII.GetBytes($Class).CopyTo($b, 12) }
        { New-Page | Set-VellumPdfOutputIntent -IccProfilePath $path -OutputConditionIdentifier 'x' } | Should -Throw "*device class '$Class'*"
    }

    It 'refuses an output intent profile of ICC version 5' {
        $path = Get-IccFile 'v5.icc' { param($b) $b[8] = 5 }
        { New-Page | Set-VellumPdfOutputIntent -IccProfilePath $path -OutputConditionIdentifier 'x' } | Should -Throw '*version 5*'
    }

    It 'accepts the built-in sRGB profile unchanged' {
        { New-Page | Set-VellumPdfOutputIntent -IccProfilePath (Get-IccFile 'ok.icc') -OutputConditionIdentifier 'sRGB' } | Should -Not -Throw
    }

    It 'keeps the looser rules for ICC colour spaces (a non-output-intent use)' {
        $path = Get-IccFile 'abst-space.icc' { param($b) [System.Text.Encoding]::ASCII.GetBytes('abst').CopyTo($b, 12) }
        { New-Page 'None' | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -IccProfilePath $path -FillIcc 0.2, 0.4, 0.6 } | Should -Not -Throw
    }
}

Describe 'RGB under a CMYK output intent warns in page-document cmdlets too' {
    BeforeAll {
        function script:New-CmykIntentPage {
            New-VellumPdfPageDocument -Conformance PdfA2b -Language en | Add-VellumPdfPage | Set-VellumPdfOutputIntent -Cmyk
        }
    }
    It '<Name> warns once' -ForEach @(
        @{ Name = 'Add-VellumPdfText'; Draw = { param($d) $d | Add-VellumPdfText 'x' -X 50 -Y 700 -Color red } }
        @{ Name = 'Add-VellumPdfTextBox'; Draw = { param($d) $d | Add-VellumPdfTextBox 'x y' -X 50 -Y 700 -Width 200 -Color red } }
        @{ Name = 'Add-VellumPdfPageList'; Draw = { param($d) $d | Add-VellumPdfPageList -X 50 -Y 700 -Width 200 -Item 'a' -Color red } }
        @{ Name = 'Add-VellumPdfPageTable'; Draw = { param($d) $d | Add-VellumPdfPageTable -X 50 -Y 700 -Width 200 -Row @(, @('a', 'b')) -HeaderBackground '#eeeeee' -Header 'h1', 'h2' } }
        @{ Name = 'Set-VellumPdfPageBand'; Draw = { param($d) $d | Set-VellumPdfPageBand -Position Footer -Template 'p {page}' -Color red } }
        @{ Name = 'Add-VellumPdfPageBarcode'; Draw = { param($d) $d | Add-VellumPdfPageBarcode -Type QrCode -Content 'hi' -X 50 -Y 500 -AltText 'q' -Foreground navy } }
    ) {
        $doc = New-CmykIntentPage
        $warnings = @(& $Draw $doc 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -BeLike "$Name*output intent is CMYK*"
    }
}
