#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Tests build SecureStrings from known plaintext; suppress the rule that flags it in production code.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'

    function script:New-PdfADoc {
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language en
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc | Add-VellumPdfParagraph -Text 'Archive' -FontHandle $handle | Out-Null
        [pscustomobject]@{ Doc = $doc; Handle = $handle }
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Test-VellumPdfConformance' {
    It 'passes a PDF/A-2b document with an embedded font and reads the claim from the file' {
        $ctx = New-PdfADoc; $doc = $ctx.Doc
        $file = $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'ok.pdf')
        $r = $file | Test-VellumPdfConformance
        $r.Profile | Should -Be 'PdfA2b'
        $r.IsCompliant | Should -BeTrue
        $r.ErrorCount | Should -Be 0
        $r.PSObject.TypeNames | Should -Contain 'PSVellumPDF.PreflightResult'
    }

    It 'reports the finding for a base-14 (non-embedded) font under PDF/A' {
        $path = Join-Path $TestDrive 'bad.pdf'
        New-VellumPdfDocument -Conformance PdfA2b -Language en | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path $path | Out-Null
        $r = Test-VellumPdfConformance -Path $path
        $r.IsCompliant | Should -BeFalse
        $finding = $r.Assertions | Where-Object { $_.Severity -eq 'Error' } | Select-Object -First 1
        $finding.RuleId | Should -BeLike '*font-embedding'
        $finding.Message | Should -BeLike '*not embedded*'
        Test-VellumPdfConformance -Path $path -Quiet | Should -BeFalse
    }

    It 'validates against an explicit profile, a byte array, and -LiteralPath' {
        $path = Join-Path $TestDrive 'plain.pdf'
        New-VellumPdfDocument -Tagged -Language en | Add-VellumPdfParagraph -Text 'x' | Save-VellumPdfDocument -Path $path | Out-Null
        { Test-VellumPdfConformance -Path $path } | Should -Throw '*does not claim*'
        (Test-VellumPdfConformance -Path $path -Profile PdfUA1).Profile | Should -Be 'PdfUA1'
        (Test-VellumPdfConformance -LiteralPath $path -Profile PdfA2b).Path | Should -Be $path
        $bytes = [System.IO.File]::ReadAllBytes($path)
        (Test-VellumPdfConformance -Bytes $bytes -Profile PdfUA1).Path | Should -Be '<bytes>'
    }

    It 'emits one result per requested profile' {
        $ctx = New-PdfADoc
        $path = (Join-Path $TestDrive 'two.pdf')
        $ctx.Doc | Save-VellumPdfDocument -Path $path | Out-Null
        $r = @(Test-VellumPdfConformance -Path $path -Profile PdfA2b, PdfA2u)
        $r.Profile | Should -Be @('PdfA2b', 'PdfA2u')
    }

    It 'throws clear errors for a missing file, junk bytes and wildcard misses' {
        { Test-VellumPdfConformance -LiteralPath (Join-Path $TestDrive 'nope.pdf') -Profile PdfA2b } | Should -Throw '*file not found*'
        { Test-VellumPdfConformance -Path (Join-Path $TestDrive 'nomatch*.pdf') -Profile PdfA2b } | Should -Throw
        { Test-VellumPdfConformance -Bytes ([byte[]](1, 2, 3)) -Profile PdfA2b } | Should -Throw '*not a well-formed PDF*'
    }

    It 'asks for a password for an encrypted PDF and opens it with one' {
        $path = Join-Path $TestDrive 'enc.pdf'
        $pw = ConvertTo-SecureString 'sekret' -AsPlainText -Force
        New-VellumPdfDocument -Tagged -Language en | Add-VellumPdfParagraph -Text 'x' |
            Protect-VellumPdfDocument -UserPassword $pw -OwnerPassword (ConvertTo-SecureString 'owner' -AsPlainText -Force) |
            Save-VellumPdfDocument -Path $path | Out-Null
        { Test-VellumPdfConformance -Path $path -Profile PdfUA1 } | Should -Throw '*needs a password*'
        { Test-VellumPdfConformance -Path $path -Profile PdfUA1 -Password $pw } | Should -Not -Throw
    }
}

Describe 'Module output against the preflight' {
    It 'a QR code, pie chart and drawing keep a PDF/A-2b document compliant' {
        $ctx = New-PdfADoc; $doc = $ctx.Doc
        $doc | Add-VellumPdfBarcode QrCode 'https://example.com' -ModuleSize 2 -AltText 'Example' |
            Add-VellumPdfPieChart -Slice @(@{ Value = 1; Label = 'a' }, @{ Value = 2; Label = 'b' }) |
            Add-VellumPdfDrawing -Height 20 -ScriptBlock { param($canvas, $box) $canvas.Rectangle($box.X, $box.Y, 10, 10).Fill() | Out-Null } |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'mix.pdf') | Out-Null
        (Test-VellumPdfConformance -Path (Join-Path $TestDrive 'mix.pdf') -Profile PdfA2b).IsCompliant | Should -BeTrue
    }

    It 'PROOF: the human-readable line of a 1-D barcode (base-14 font) breaks PDF/A' {
        $ctx = New-PdfADoc; $doc = $ctx.Doc
        $ean = [VellumPdf.Barcodes.EanBarcode]::new([VellumPdf.Barcodes.EanSymbology]::Ean13, '5901234123457')
        $ean.ShowText = $true
        $doc | Add-VellumPdfElement -Renderer ([VellumPdf.Barcodes.BarcodeRenderer]::new($ean)) |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'ean-text.pdf') | Out-Null
        $r = Test-VellumPdfConformance -Path (Join-Path $TestDrive 'ean-text.pdf') -Profile PdfA2b
        $r.IsCompliant | Should -BeFalse
        ($r.Assertions | Where-Object RuleId -Like '*font-embedding').Count | Should -BeGreaterThan 0
    }

    It 'the cmdlet default (no human-readable line) keeps a 1-D barcode compliant under PDF/A' {
        $ctx = New-PdfADoc; $doc = $ctx.Doc; $handle = $ctx.Handle
        $doc | Add-VellumPdfBarcode Ean13 '5901234123457' -Caption '5901234123457' -FontHandle $handle |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'ean-ok.pdf') | Out-Null
        $r = Test-VellumPdfConformance -Path (Join-Path $TestDrive 'ean-ok.pdf') -Profile PdfA2b
        ($r.Assertions | Where-Object Severity -EQ 'Error' | ForEach-Object { "$($_.RuleId): $($_.Message)" }) | Should -BeNullOrEmpty
        $r.IsCompliant | Should -BeTrue
    }

    It 'a PDF/UA-1 document with a title, embedded font and every element type passes' {
        $path = Join-Path $TestDrive 'ua.pdf'
        $doc = New-VellumPdfDocument -Conformance PdfUA1 -Language en-US
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc | Set-VellumPdfDocumentInfo -Title 'Accessible report' |
            Add-VellumPdfHeading -Text 'Report' -FontHandle $h |
            Add-VellumPdfParagraph -Text 'Body text.' -FontHandle $h |
            Add-VellumPdfList -Item 'one', 'two' -FontHandle $h |
            Add-VellumPdfTable -Header 'A', 'B' -Row @(, @('1', '2')) -FontHandle $h |
            Add-VellumPdfPieChart -Slice @(@{ Value = 1; Label = 'a' }) -AltText 'One slice' |
            Add-VellumPdfBarcode QrCode 'x' -ModuleSize 2 |
            Save-VellumPdfDocument -Path $path | Out-Null
        $r = Test-VellumPdfConformance -Path $path -Profile PdfUA1
        ($r.Assertions | Where-Object Severity -EQ 'Error' | ForEach-Object { "$($_.RuleId): $($_.Message)" }) | Should -BeNullOrEmpty
        $r.IsCompliant | Should -BeTrue
    }

    It 'PROOF: PDF/UA-1 also needs a document title and embedded fonts' {
        $path = Join-Path $TestDrive 'ua-bad.pdf'
        New-VellumPdfDocument -Conformance PdfUA1 -Language en | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path $path | Out-Null
        $ids = (Test-VellumPdfConformance -Path $path -Profile PdfUA1).Assertions | Where-Object Severity -EQ 'Error' | ForEach-Object RuleId
        $ids | Should -Contain 'ISO14289-1:7.1-title'
        $ids | Should -Contain 'ISO14289-1:7.21.4.1-1'
    }
}
