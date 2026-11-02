#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Save-VellumPdfDocument single-use documents' {
    It 'refuses a second save of a document kept open' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'once'
        try {
            $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'a.pdf') -KeepOpen | Out-Null
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'b.pdf') -KeepOpen } |
                Should -Throw '*already saved*'
            Test-Path (Join-Path $TestDrive 'b.pdf') | Should -BeFalse
        }
        finally { $doc.Dispose() }
    }

    It 'marks a document unusable after a failed save' {
        $doc = New-VellumPdfDocument   # no content: the engine refuses to save a page-less document
        try {
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'c.pdf') -KeepOpen } |
                Should -Throw '*failed to render*'
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'c.pdf') -KeepOpen } |
                Should -Throw '*previous save*failed*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Save-VellumPdfDocument engine diagnostics' {
    It 'reports characters the base-14 fonts cannot encode once, after saving' {
        $cjk = -join ([int[]](0x65E5, 0x672C, 0x8A9E) | ForEach-Object { [char]$_ })
        $doc = New-VellumPdfDocument
        $doc | Add-VellumPdfParagraph -Text $cjk -WarningAction SilentlyContinue | Out-Null
        $file = $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'cjk.pdf') -WarningVariable wv -WarningAction SilentlyContinue
        @($wv | Where-Object Message -Like '*written as ''?''*').Count | Should -Be 1
        $file.TextEncodingWarnings.Count | Should -Be 3
        ($file.TextEncodingWarnings.CodePoint | Sort-Object) -join ',' | Should -Be '26085,26412,35486'
    }

    It 'does not report Windows-1252 typographic characters' {
        $text = -join ([int[]](0x20AC, 0x2022, 0x2014, 0x201C) | ForEach-Object { [char]$_ })
        $file = New-VellumPdfDocument | Add-VellumPdfParagraph -Text $text |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'wa.pdf') -WarningVariable wv
        @($wv).Count | Should -Be 0
        @($file.TextEncodingWarnings).Count | Should -Be 0
        @($file.BandTruncations).Count | Should -Be 0
    }

    It 'warns when a footer is too wide for the page and was truncated' {
        $footer = ('W' * 400)
        $file = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'body' |
            Set-VellumPdfFooter -Template $footer |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'band.pdf') -WarningVariable wv -WarningAction SilentlyContinue
        @($wv | Where-Object Message -Like '*footer text on page 1*truncated*').Count | Should -Be 1
        $file.BandTruncations[0].Band | Should -Be 'Footer'
        $file.BandTruncations[0].DroppedCharacters | Should -BeGreaterThan 0
    }
}

Describe 'Save-VellumPdfDocument -PassThru and -Force' {
    It '-PassThru returns the live document and keeps it open' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        $out = Join-Path $TestDrive 'pt.pdf'
        $result = $doc | Save-VellumPdfDocument -Path $out -PassThru
        try {
            $result | Should -BeOfType ([VellumPdf.Layout.Document])
            [object]::ReferenceEquals($result, $doc) | Should -BeTrue
            Test-Path $out | Should -BeTrue
            { $doc | Add-VellumPdfParagraph -Text 'still open' | Out-Null } | Should -Not -Throw
        }
        finally { $doc.Dispose() }
    }

    It '-Force creates a missing parent directory; without it saving fails' {
        $dir = Join-Path $TestDrive 'new' 'nested'
        $path = Join-Path $dir 'f.pdf'
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            { $doc | Save-VellumPdfDocument -Path $path -KeepOpen } | Should -Throw '*directory not found*'
            $doc | Save-VellumPdfDocument -Path $path -Force | Out-Null
        }
        catch { $doc.Dispose(); throw }
        Test-Path $path | Should -BeTrue
    }
}

Describe 'Save-VellumPdfDocument in-memory output' {
    It '-AsByteArray returns the PDF bytes as one byte[]' {
        $bytes = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'mem' | Save-VellumPdfDocument -AsByteArray
        $bytes.GetType().FullName | Should -Be 'System.Byte[]'
        [System.Text.Encoding]::ASCII.GetString($bytes[0..4]) | Should -Be '%PDF-'
        [System.Text.Encoding]::ASCII.GetString($bytes[-6..-1]) | Should -Match '%%EOF'
    }

    It '-Stream writes the PDF to a stream, which stays open' {
        $ms = [System.IO.MemoryStream]::new()
        try {
            $result = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'mem' | Save-VellumPdfDocument -Stream $ms
            $result | Should -BeNullOrEmpty
            $ms.CanWrite | Should -BeTrue
            $ms.Length | Should -BeGreaterThan 300
            [System.Text.Encoding]::ASCII.GetString($ms.ToArray()[0..4]) | Should -Be '%PDF-'
        }
        finally { $ms.Dispose() }
    }

    It 'rejects a read-only stream' {
        $ro = [System.IO.MemoryStream]::new([byte[]]@(1), $false)
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try { { $doc | Save-VellumPdfDocument -Stream $ro -KeepOpen } | Should -Throw '*writable stream*' }
        finally { $doc.Dispose(); $ro.Dispose() }
    }

    It 'reports the same diagnostics as a file save' {
        $cjk = -join ([int[]](0x65E5, 0x672C) | ForEach-Object { [char]$_ })
        $doc = New-VellumPdfDocument
        $doc | Add-VellumPdfParagraph -Text $cjk -WarningAction SilentlyContinue | Out-Null
        $null = $doc | Save-VellumPdfDocument -AsByteArray -WarningVariable wv -WarningAction SilentlyContinue
        @($wv | Where-Object Message -Like '*written as ''?''*').Count | Should -Be 1
    }

    It 'a failed render leaves the stream untouched' {
        $ms = [System.IO.MemoryStream]::new()
        $doc = New-VellumPdfDocument   # no content
        try {
            { $doc | Save-VellumPdfDocument -Stream $ms -KeepOpen } | Should -Throw '*failed to render*'
            $ms.Length | Should -Be 0
        }
        finally { $doc.Dispose(); $ms.Dispose() }
    }
}

Describe 'Save-VellumPdfDocument -Validate' {
    BeforeAll { $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf' }

    It 'writes a compliant PDF/A document' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language en
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $out = Join-Path $TestDrive 'valid.pdf'
        $doc | Add-VellumPdfParagraph -Text 'ok' -FontHandle $h | Save-VellumPdfDocument -Path $out -Validate | Out-Null
        Test-Path $out | Should -BeTrue
    }

    It 'refuses a non-compliant document and writes nothing, in every output mode' {
        $out = Join-Path $TestDrive 'invalid.pdf'
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language en | Add-VellumPdfParagraph -Text 'base-14 text'
        { $doc | Save-VellumPdfDocument -Path $out -Validate } | Should -Throw '*not PdfA2b compliant*font-embedding*'
        Test-Path $out | Should -BeFalse

        $ms = [System.IO.MemoryStream]::new()
        $doc2 = New-VellumPdfDocument -Conformance PdfA2b -Language en | Add-VellumPdfParagraph -Text 'base-14 text'
        { $doc2 | Save-VellumPdfDocument -Stream $ms -Validate } | Should -Throw '*nothing was written*'
        $ms.Length | Should -Be 0
        $ms.Dispose()
    }

    It 'needs a conformance level and refuses encrypted documents' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try { { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'n.pdf') -Validate } | Should -Throw '*needs a document created with*' }
        finally { $doc.Dispose() }

        $enc = New-VellumPdfDocument -Language en | Add-VellumPdfParagraph -Text 'x'
        $enc.Conformance = [VellumPdf.Document.PdfConformance]::PdfUA1
        $enc | Protect-VellumPdfDocument -UserPassword (ConvertTo-SecureString 'p' -AsPlainText -Force) -Permission Extract | Out-Null
        try { { $enc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'e.pdf') -Validate } | Should -Throw '*cannot read an encrypted PDF*' }
        finally { $enc.Dispose() }
    }
}
