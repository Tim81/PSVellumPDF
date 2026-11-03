#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Header/footer colour, embedded font and height' {
    It 'sets band height and colour on a RunningBand' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Set-VellumPdfHeader -Template 'H {page}' -Color '#ff0000' -Height 40 | Out-Null
            $doc | Set-VellumPdfFooter -Template 'F' -Height 25 | Out-Null
            $doc.Header.Height | Should -Be 40
            $doc.Header.Style.Color.R | Should -Be 1
            $doc.Footer.Height | Should -Be 25
        }
        finally { $doc.Dispose() }
    }

    It 'leaves Height unset (engine default) when not requested' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Set-VellumPdfFooter -Template 'F' | Out-Null
            $doc.Footer.Height | Should -BeNullOrEmpty
        }
        finally { $doc.Dispose() }
    }

    It 'uses an embedded font under PDF/A without an encoding warning' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $out = Join-Path $TestDrive 'band.pdf'
        $czech = 'Str' + [char]0x00E1 + 'nka ' + [char]0x0159 + ' {page}/{pages}'
        $doc | Add-VellumPdfParagraph -Text 'body' -FontHandle $handle |
            Set-VellumPdfFooter -Template $czech -FontHandle $handle -WarningVariable wv |
            Save-VellumPdfDocument -Path $out | Out-Null
        @($wv).Count | Should -Be 0
        [System.IO.File]::ReadAllText($out, [System.Text.Encoding]::Latin1) | Should -Match '/FontFile2'
    }

    It 'rejects a non-positive height and a foreign font handle' {
        $doc = New-VellumPdfDocument
        $other = New-VellumPdfDocument
        try {
            { $doc | Set-VellumPdfHeader -Template 'x' -Height 0 } | Should -Throw
            $foreign = Register-VellumPdfFont -Document $other -Path $script:fontPath
            { $doc | Set-VellumPdfHeader -Template 'x' -FontHandle $foreign } | Should -Throw '*DIFFERENT document*'
        }
        finally { $doc.Dispose(); $other.Dispose() }
    }
}
