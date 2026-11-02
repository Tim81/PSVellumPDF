#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    function script:Get-PdfText([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::Latin1) }
    function script:Get-Utf16Pattern([string]$Text) {
        '\xFE\xFF' + (($Text.ToCharArray() | ForEach-Object { '\x00' + [regex]::Escape([string]$_) }) -join '')
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfBarcode symbologies' {
    It 'saves a valid PDF for <Type>' -ForEach @(
        @{ Type = 'QrCode'; Content = 'https://example.com' }
        @{ Type = 'MicroQrCode'; Content = 'MQR1' }
        @{ Type = 'DataMatrix'; Content = 'HELLO' }
        @{ Type = 'Aztec'; Content = 'Aztec text' }
        @{ Type = 'Pdf417'; Content = 'PDF417 text' }
        @{ Type = 'Code128'; Content = 'ABC-123' }
        @{ Type = 'Code39'; Content = 'CODE39' }
        @{ Type = 'Ean13'; Content = '5901234123457' }
        @{ Type = 'Ean8'; Content = '96385074' }
        @{ Type = 'UpcA'; Content = '036000291452' }
        @{ Type = 'UpcE'; Content = '01234565' }
        @{ Type = 'Itf14'; Content = '12345678901231' }
    ) {
        $out = Join-Path $TestDrive "$Type.pdf"
        $doc = New-VellumPdfDocument
        $result = $doc | Add-VellumPdfBarcode -Type $Type -Content $Content
        [object]::ReferenceEquals($result, $doc) | Should -BeTrue
        $result | Save-VellumPdfDocument -Path $out | Out-Null
        (Get-Item $out).Length | Should -BeGreaterThan 400
    }

    It 'encodes binary content with -Bytes for QrCode only' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfBarcode -Type QrCode -Bytes ([byte[]](1, 2, 3, 255)) } | Should -Not -Throw
            { $doc | Add-VellumPdfBarcode -Type Aztec -Bytes ([byte[]](1, 2)) } | Should -Throw '*-Bytes is supported for -Type QrCode*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfBarcode options' {
    It 'applies type-specific options without error' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Add-VellumPdfBarcode QrCode 'x' -ErrorCorrection H -QrVersion 5 -QrMask 2 -TextEncoding Utf8 -ModuleSize 2 | Out-Null
            $doc | Add-VellumPdfBarcode DataMatrix 'x' -Shape Rectangular -ModuleSize 2 | Out-Null
            $doc | Add-VellumPdfBarcode Aztec 'x' -AztecFormat Compact -AztecErrorCorrectionPercent 30 -ModuleSize 2 | Out-Null
            $doc | Add-VellumPdfBarcode Pdf417 'x' -Columns 4 -ErrorCorrectionLevel 3 -Compact -ModuleSize 1 | Out-Null
            $doc | Add-VellumPdfBarcode Code39 'ABC' -CheckDigit -WideNarrowRatio 3 -BarHeight 30 -TextSize 8 -TextFont Courier | Out-Null
            $doc | Add-VellumPdfBarcode Ean13 '5901234123457' -AddOn '12' | Out-Null
            $doc | Add-VellumPdfBarcode Itf14 '12345678901231' -BearerBars None | Out-Null
            $doc | Add-VellumPdfBarcode Code128 'ABC' -Foreground navy -Background '#eeeeee' -NoQuietZone -Alignment Right `
                -MarginTop 4 -MarginBottom 4 -MarginLeft 3 -MarginRight 3 | Out-Null
        }
        finally { $doc.Dispose() }
    }

    It 'rejects options that belong to another symbology' -ForEach @(
        @{ Params = @{ Type = 'Code128'; Content = 'A'; ErrorCorrection = 'H' }; Match = '*-ErrorCorrection does not apply to -Type Code128*' }
        @{ Params = @{ Type = 'QrCode'; Content = 'A'; BearerBars = 'Frame' }; Match = '*-BearerBars does not apply*' }
        @{ Params = @{ Type = 'QrCode'; Content = 'A'; BarHeight = 20 }; Match = '*only applies to linear*' }
        @{ Params = @{ Type = 'Ean13'; Content = '5901234123457'; Shape = 'Square' }; Match = '*-Shape does not apply*' }
        @{ Params = @{ Type = 'Aztec'; Content = 'A'; SplitInto = 2 }; Match = '*-SplitInto applies to QrCode*' }
        @{ Params = @{ Type = 'Pdf417'; Content = 'A'; FileId = 5 }; Match = $null }
    ) {
        $doc = New-VellumPdfDocument
        try {
            if ($Match) { { $doc | Add-VellumPdfBarcode @Params } | Should -Throw $Match }
            else { { $doc | Add-VellumPdfBarcode @Params } | Should -Not -Throw }
        }
        finally { $doc.Dispose() }
    }

    It 'refuses -ModuleSize together with -TargetWidth, and -AltText with -Decorative' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfBarcode QrCode 'x' -ModuleSize 2 -TargetWidth 50 } | Should -Throw '*cannot be combined*'
            { $doc | Add-VellumPdfBarcode QrCode 'x' -AltText 'a' -Decorative } | Should -Throw '*cannot be combined*'
        }
        finally { $doc.Dispose() }
    }

    It 'fails at the call site for content the symbology cannot encode' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfBarcode Ean13 'not-digits' } | Should -Throw 'Add-VellumPdfBarcode:*'
            { $doc | Add-VellumPdfBarcode QrCode 'x' -ModuleSize 1000 } | Should -Throw '*content area is only*'
        }
        finally { $doc.Dispose() }
    }

    It 'writes the alternate text of a tagged symbol, and a default naming the symbology' {
        $a = Join-Path $TestDrive 'alt.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfBarcode QrCode 'https://example.com' -ModuleSize 2 -AltText 'Product page' |
            Add-VellumPdfBarcode Code128 'ABC' |
            Save-VellumPdfDocument -Path $a | Out-Null
        $t = Get-PdfText $a
        $t | Should -Match (Get-Utf16Pattern 'Product page')
        $t | Should -Match (Get-Utf16Pattern 'Code 128 barcode: ABC')
    }

    It 'splits content into Structured Append QR symbols and Macro PDF417 segments' {
        $one = Join-Path $TestDrive 'one.pdf'
        $three = Join-Path $TestDrive 'three.pdf'
        New-VellumPdfDocument | Add-VellumPdfBarcode QrCode 'abcdefghijkl' -ModuleSize 2 |
            Save-VellumPdfDocument -Path $one | Out-Null
        New-VellumPdfDocument | Add-VellumPdfBarcode QrCode 'abcdefghijkl' -SplitInto 3 -ModuleSize 2 |
            Save-VellumPdfDocument -Path $three | Out-Null
        (Get-Item $three).Length | Should -BeGreaterThan (Get-Item $one).Length

        $doc = New-VellumPdfDocument
        try { { $doc | Add-VellumPdfBarcode Pdf417 'abcdefghijkl' -SplitInto 2 -FileId 7 -ModuleSize 1 } | Should -Not -Throw }
        finally { $doc.Dispose() }
    }

    It 'adds a caption paragraph under the symbol' {
        $with = Join-Path $TestDrive 'cap.pdf'
        $without = Join-Path $TestDrive 'nocap.pdf'
        New-VellumPdfDocument | Add-VellumPdfBarcode QrCode 'x' -ModuleSize 2 -Caption 'Scan me' |
            Save-VellumPdfDocument -Path $with | Out-Null
        New-VellumPdfDocument | Add-VellumPdfBarcode QrCode 'x' -ModuleSize 2 |
            Save-VellumPdfDocument -Path $without | Out-Null
        (Get-Item $with).Length | Should -BeGreaterThan (Get-Item $without).Length
    }

    It 'adds the space deferred by a previous -MarginBottom above the symbol' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Add-VellumPdfParagraph -Text 'x' -MarginBottom 30 | Out-Null
            $doc.PSVellumPendingSpace | Should -Be 30
            $doc | Add-VellumPdfBarcode QrCode 'x' -ModuleSize 2 | Out-Null
            $doc.PSVellumPendingSpace | Should -Be 0
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfBarcode in PDF/A documents' {
    It 'turns the human-readable line off by default and refuses -ShowText / -TextFont' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        try {
            { $doc | Add-VellumPdfBarcode Ean13 '5901234123457' } | Should -Not -Throw
            { $doc | Add-VellumPdfBarcode Ean13 '5901234123457' -ShowText $true } | Should -Throw '*PDF/A forbids*'
            { $doc | Add-VellumPdfBarcode Ean13 '5901234123457' -TextFont Courier } | Should -Throw '*PDF/A forbids*'
        }
        finally { $doc.Dispose() }
    }

    It 'prints a caption in the embedded font instead' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $out = Join-Path $TestDrive 'pdfa.pdf'
        $doc | Add-VellumPdfBarcode Ean13 '5901234123457' -Caption '5901234123457' -FontHandle $handle |
            Save-VellumPdfDocument -Path $out | Out-Null
        Get-PdfText $out | Should -Match '/FontFile2'
    }

    It 'requires -Caption when a font handle is given' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        try { { $doc | Add-VellumPdfBarcode QrCode 'x' -FontHandle $handle } | Should -Throw '*only used for -Caption*' }
        finally { $doc.Dispose() }
    }
}

Describe 'PDF417 shape options and Macro PDF417 metadata' {
    It 'row height changes the symbol height, and both options are accepted when drawing' {
        $base = [VellumPdf.Barcodes.Pdf417Barcode]::new('x' * 40); $base.ModuleSize = 1
        $tall = [VellumPdf.Barcodes.Pdf417Barcode]::new('x' * 40); $tall.ModuleSize = 1; $tall.RowHeight = 8
        $tall.Measure().Height | Should -BeGreaterThan $base.Measure().Height

        $viaCmdlet = New-VellumPdfDocument | Add-VellumPdfBarcode Pdf417 ('x' * 40) -ModuleSize 1 -RowHeight 8 -PreferredAspectRatio 5
        $viaCmdlet | Should -BeOfType ([VellumPdf.Layout.Document])
        $viaCmdlet.Dispose()
        $page = New-VellumPdfPageDocument | Add-VellumPdfPage
        { $page | Add-VellumPdfPageBarcode Pdf417 ('x' * 40) -X 10 -Y 10 -ModuleSize 1 -RowHeight 8 -PreferredAspectRatio 5 } | Should -Not -Throw
        $page.Dispose()
    }

    It 'accepts Macro PDF417 metadata with -SplitInto and refuses it without' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfBarcode Pdf417 'abcdefghijkl' -SplitInto 2 -FileId 7 -ModuleSize 1 `
                    -MacroFileName 'doc.txt' -MacroSender 'me' -MacroAddressee 'you' -MacroTimestamp ([DateTimeOffset]'2026-01-01T00:00:00Z') `
                    -MacroFileSize 12 -MacroChecksum 1234 } | Should -Not -Throw
            { $doc | Add-VellumPdfBarcode Pdf417 'abc' -MacroFileName 'x' } | Should -Throw '*need -SplitInto*'
            { $doc | Add-VellumPdfBarcode QrCode 'abc' -SplitInto 2 -MacroSender 's' } | Should -Throw '*does not apply to -Type QrCode*'
        }
        finally { $doc.Dispose() }
    }

    It 'the Macro metadata reaches the symbols (the set differs from one without metadata)' {
        $with = Join-Path $TestDrive 'macro1.pdf'
        $without = Join-Path $TestDrive 'macro0.pdf'
        New-VellumPdfDocument | Add-VellumPdfBarcode Pdf417 'abcdefghijkl' -SplitInto 2 -FileId 7 -ModuleSize 1 -MacroFileName 'a-long-file-name.txt' |
            Save-VellumPdfDocument -Path $with | Out-Null
        New-VellumPdfDocument | Add-VellumPdfBarcode Pdf417 'abcdefghijkl' -SplitInto 2 -FileId 7 -ModuleSize 1 |
            Save-VellumPdfDocument -Path $without | Out-Null
        (Get-Item $with).Length | Should -Not -Be (Get-Item $without).Length
    }
}

Describe 'Get-VellumPdfBarcodeMatrix' {
    It 'returns the module grid of a QR code' {
        $m = Get-VellumPdfBarcodeMatrix QrCode 'hello' -ErrorCorrection H
        $m.PSObject.TypeNames | Should -Contain 'PSVellumPDF.BarcodeMatrix'
        $m.Width | Should -Be 21
        $m.Height | Should -Be 21
        $m.Rows.Count | Should -Be 21
        $m.Rows[0].Substring(0, 7) | Should -Be '#######'      # finder pattern
        $m.IsDark(0, 0) | Should -BeTrue
        $m.IsDark(7, 0) | Should -BeFalse                       # separator
    }

    It 'handles every 2-D symbology and the same options as the drawing cmdlet' {
        foreach ($t in 'MicroQrCode', 'DataMatrix', 'Aztec', 'Pdf417') {
            $m = Get-VellumPdfBarcodeMatrix $t 'HELLO'
            $m.Width | Should -BeGreaterThan 5
            $m.Rows.Count | Should -Be $m.Height
        }
        (Get-VellumPdfBarcodeMatrix DataMatrix 'HELLO' -Shape Rectangular).Width | Should -BeGreaterThan (Get-VellumPdfBarcodeMatrix DataMatrix 'HELLO' -Shape Rectangular).Height
        { Get-VellumPdfBarcodeMatrix QrCode 'x' -Bytes ([byte[]](1, 2)) } | Should -Throw
    }

    It 'reports problems with its own name' {
        { Get-VellumPdfBarcodeMatrix QrCode ('y' * 500) -QrVersion 1 -ErrorCorrection H } | Should -Throw 'Get-VellumPdfBarcodeMatrix:*'
    }
}
