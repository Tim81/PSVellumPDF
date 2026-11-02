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
