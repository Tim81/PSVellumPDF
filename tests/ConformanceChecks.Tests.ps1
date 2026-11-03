#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Conformance-related input checks: what PDF/UA and PDF/A need from the content the module draws.

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    function script:New-Page([hashtable]$DocParams = @{}) { New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Barcode captions in PDF/UA' {
    It 'leaves the human-readable line off and passes the PDF/UA-1 preflight (page document)' {
        $path = Join-Path $TestDrive 'ua-barcode.pdf'
        New-Page @{ Conformance = 'PdfUA1'; Language = 'en' } | Set-VellumPdfDocumentInfo -Title 'Barcode' |
            Add-VellumPdfPageBarcode Code128 'ABC123' -X 50 -Y 500 -AltText 'Code 128 barcode' |
            Save-VellumPdfDocument -Path $path -Validate | Out-Null
        (Test-VellumPdfConformance -Path $path -Profile PdfUA1).IsCompliant | Should -BeTrue
    }

    It 'leaves the human-readable line off and passes the PDF/UA-1 preflight (flow document)' {
        $path = Join-Path $TestDrive 'ua-barcode-flow.pdf'
        New-VellumPdfDocument -Conformance PdfUA1 -Language en | Set-VellumPdfDocumentInfo -Title 'Barcode' |
            Add-VellumPdfBarcode -Type Code128 -Content 'ABC123' -AltText 'Code 128 barcode' |
            Save-VellumPdfDocument -Path $path -Validate | Out-Null
        (Test-VellumPdfConformance -Path $path -Profile PdfUA1).IsCompliant | Should -BeTrue
    }

    It 'refuses an explicit -ShowText in PDF/UA' {
        { New-Page @{ Conformance = 'PdfUA1'; Language = 'en' } | Add-VellumPdfPageBarcode Code128 'ABC' -X 1 -Y 1 -ShowText $true } |
            Should -Throw '*PDF/A and PDF/UA forbid*'
    }
}

Describe 'CMYK warning is about PDF/A only' {
    It 'warns for PDF/A without a CMYK intent, not for PDF/UA-only or untagged documents' {
        $w = $null
        $null = New-Page @{ Conformance = 'PdfA2b'; Language = 'en' } | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -FillCmyk 0, 0, 0, 1 -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -Match 'CMYK output intent'
        foreach ($level in 'PdfUA1', 'None') {
            $w = $null
            $null = New-Page @{ Conformance = $level; Language = 'en' } | Add-VellumPdfPath 'M 0 0 L 9 9' -StrokeCmyk 0, 1, 1, 0 -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -BeNullOrEmpty
        }
    }
}

Describe 'Characters the font has no glyph for' {
    BeforeAll {
        $script:doc = New-VellumPdfPageDocument -Language en | Add-VellumPdfPage
        $script:font = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath
    }
    AfterAll { $script:doc.Dispose() }

    It 'warns from <Name>, naming the character' -ForEach @(
        @{ Name = 'Add-VellumPdfText'; Run = { $script:doc | Add-VellumPdfText "x $([char]::ConvertFromUtf32(0x1F600))" -X 10 -Y 10 -FontHandle $script:font } }
        @{ Name = 'Add-VellumPdfTextBox'; Run = { $script:doc | Add-VellumPdfTextBox "CJK $([char]0x65E5)" -X 10 -Y 100 -Width 100 -FontHandle $script:font } }
        @{ Name = 'Set-VellumPdfPageBand'; Run = { $script:doc | Set-VellumPdfPageBand Footer "$([char]0x65E5) {page}" -FontHandle $script:font } }
    ) {
        $w = & $Run 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] } | ForEach-Object { $_.Message }
        "$w" | Should -Match 'no glyph for U\+'
        "$w" | Should -Match $Name
    }

    It 'stays quiet when every character is covered' {
        $w = $null
        $null = $script:doc | Add-VellumPdfText "Zażółć gęślą jaźń`t" -X 10 -Y 10 -FontHandle $script:font -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -BeNullOrEmpty
    }

    It 'warns for flow documents that take a font handle' {
        $flow = New-VellumPdfDocument
        try {
            $fh = Register-VellumPdfFont -Document $flow -Path $script:fontPath
            $w = $null
            $null = $flow | Add-VellumPdfParagraph -Text "ok $([char]0x65E5)" -FontHandle $fh -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -Match 'no glyph for U\+65E5'
            $w = $null
            $null = $flow | Add-VellumPdfHeading -Text "H $([char]0x65E5)" -FontHandle $fh -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -Match 'no glyph'
            $w = $null
            $null = $flow | Add-VellumPdfList -Item 'a', "b $([char]0x65E5)" -FontHandle $fh -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -Match 'no glyph'
            $w = $null
            $null = $flow | Add-VellumPdfTable -Row @(, @('a', "$([char]0x65E5)")) -FontHandle $fh -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -Match 'no glyph'
            $w = $null
            $null = New-VellumPdfTextRun -Text "r $([char]0x65E5)" -FontHandle $fh -WarningVariable w -WarningAction SilentlyContinue
            "$w" | Should -Match 'no glyph'
        }
        finally { $flow.Dispose() }
    }

    It 'also catches the PDF/A case that the preflight reports only with -Validate' {
        $a = New-Page @{ Conformance = 'PdfA2b'; Language = 'en' }
        $w = $null
        $null = $a | Add-VellumPdfTextBox "Emoji $([char]::ConvertFromUtf32(0x1F600))" -X 10 -Y 100 -Width 100 -Font TimesRoman -WarningVariable w -WarningAction SilentlyContinue
        "$w" | Should -Match 'no glyph for U\+1F600'
        $a.Dispose()
    }
}

Describe 'Language tags and alternate text' {
    It 'rejects a malformed language tag in <Name>' -ForEach @(
        @{ Name = 'New-VellumPdfDocument'; Run = { New-VellumPdfDocument -Language 'not a language!!' } }
        @{ Name = 'New-VellumPdfPageDocument'; Run = { New-VellumPdfPageDocument -Language 'en_US' } }
        @{ Name = 'Add-VellumPdfText'; Run = { New-Page | Add-VellumPdfText 'x' -X 1 -Y 1 -Language 'also bad!' } }
        @{ Name = 'Add-VellumPdfTextBox'; Run = { New-Page | Add-VellumPdfTextBox 'x' -X 1 -Y 1 -Width 50 -Language '1234' } }
        @{ Name = 'Add-VellumPdfParagraph'; Run = { New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x' -Language 'e n' } }
        @{ Name = 'Add-VellumPdfHeading'; Run = { New-VellumPdfDocument | Add-VellumPdfHeading -Text 'x' -Level 1 -Language 'bad tag' } }
    ) {
        { & $Run } | Should -Throw '*is not a BCP 47 language tag*'
    }

    It 'accepts common tags, and writes the element language to the structure tree' {
        foreach ($tag in 'en', 'en-US', 'nl-NL', 'zh-Hant-TW', 'x-private') {
            { New-Page | Add-VellumPdfText 'x' -X 1 -Y 1 -Language $tag | Out-Null } | Should -Not -Throw
        }
        $ua = Join-Path $TestDrive 'lang.pdf'
        New-Page @{ Conformance = 'PdfUA1'; Language = 'en-US' } | Set-VellumPdfDocumentInfo -Title 'Lang' |
            Add-VellumPdfTextBox 'Bonjour le monde' -X 50 -Y 700 -Width 200 -Language fr-FR |
            Save-VellumPdfDocument -Path $ua | Out-Null
        (Get-PdfText $ua) | Should -Match ('/Lang \(' + (Get-Utf16Pattern 'fr-FR'))
    }

    It 'rejects empty or whitespace alternate text' -ForEach @(
        @{ Name = 'path'; Run = { New-Page | Add-VellumPdfPath 'M 0 0 L 1 1' -AltText '   ' } }
        @{ Name = 'shape'; Run = { New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 5 -Height 5 -AltText ' ' } }
        @{ Name = 'gradient'; Run = { New-Page | Add-VellumPdfGradient -X 0 -Y 0 -Width 5 -Height 5 -StartColor red -EndColor blue -AltText ' ' } }
        @{ Name = 'page barcode'; Run = { New-Page | Add-VellumPdfPageBarcode QrCode 'x' -X 1 -Y 1 -AltText "`t" } }
        @{ Name = 'flow barcode'; Run = { New-VellumPdfDocument | Add-VellumPdfBarcode -Type QrCode -Content 'x' -AltText ' ' } }
    ) {
        { & $Run } | Should -Throw '*AltText must not be empty or whitespace*'
    }

    It 'throws for an empty tagged heading box and draws nothing for other empty boxes' {
        { New-Page @{ Conformance = 'PdfUA1'; Language = 'en' } | Add-VellumPdfTextBox '' -X 1 -Y 100 -Width 50 -Role H1 } | Should -Throw '*would be empty*'
        $path = Join-Path $TestDrive 'emptybox.pdf'
        New-Page @{ Conformance = 'PdfUA1'; Language = 'en' } | Set-VellumPdfDocumentInfo -Title 'E' |
            Add-VellumPdfTextBox '   ' -X 1 -Y 100 -Width 50 | Save-VellumPdfDocument -Path $path -Validate | Out-Null
        (Get-PdfContentText $path) | Should -Not -Match '/P <</MCID'
    }
}

Describe 'Output intent profile checks' {
    It 'reads the component count from the profile, and refuses a mismatch' {
        $cmyk = Join-Path $TestDrive 'cmyk.icc'
        [System.IO.File]::WriteAllBytes($cmyk, [VellumPdf.Document.IccProfiles]::GenericCmyk)
        $doc = New-Page @{ Conformance = 'PdfA2b'; Language = 'en' }
        try {
            { $doc | Set-VellumPdfOutputIntent -IccProfilePath $cmyk -ComponentCount 3 -OutputConditionIdentifier x } | Should -Throw '*does not match the profile*4 colour component*'
            $doc | Set-VellumPdfOutputIntent -IccProfilePath $cmyk -OutputConditionIdentifier 'Generic CMYK' | Out-Null
            $doc.PSVellumCmykIntent | Should -BeTrue
        }
        finally { $doc.Dispose() }
    }
}
