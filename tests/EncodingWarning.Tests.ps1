#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    # Czech text with characters above U+00FF (r-caron, s-caron, z-caron)
    # built from codepoints so this test file stays ASCII-only.
    $script:nonLatin = 'P' + [char]0x0159 + 'ili' + [char]0x0161 + ' ' + [char]0x017E + 'lut' + [char]0x00FD
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Base-14 encoding warnings (silent Unicode data loss)' {
    BeforeEach {
        $script:doc = New-VellumPdfDocument
    }

    AfterEach {
        if ($script:doc) { try { $script:doc.Dispose() } catch { Write-Verbose "noop: $_" } }
    }

    It 'warns when a paragraph contains non-Latin-1 text and no -FontHandle' {
        $script:doc | Add-VellumPdfParagraph -Text $script:nonLatin -WarningVariable wv -WarningAction SilentlyContinue | Out-Null
        @($wv).Count | Should -BeGreaterThan 0
        $wv[0].Message | Should -Match 'base-14'
        $wv[0].Message | Should -Match 'Register-VellumPdfFont'
    }

    It 'warns for headings, list items, table cells, header/footer templates, and text runs' {
        $script:doc | Add-VellumPdfHeading -Text $script:nonLatin -WarningVariable w1 -WarningAction SilentlyContinue | Out-Null
        $script:doc | Add-VellumPdfList -Item 'ok', $script:nonLatin -WarningVariable w2 -WarningAction SilentlyContinue | Out-Null
        $script:doc | Add-VellumPdfTable -Row @(,@($script:nonLatin)) -WarningVariable w3 -WarningAction SilentlyContinue | Out-Null
        $script:doc | Set-VellumPdfHeader -Template $script:nonLatin -WarningVariable w4 -WarningAction SilentlyContinue | Out-Null
        $script:doc | Set-VellumPdfFooter -Template $script:nonLatin -WarningVariable w5 -WarningAction SilentlyContinue | Out-Null
        New-VellumPdfTextRun -Text $script:nonLatin -WarningVariable w6 -WarningAction SilentlyContinue | Out-Null

        foreach ($w in @($w1, $w2, $w3, $w4, $w5, $w6)) {
            @($w).Count | Should -BeGreaterThan 0
        }
    }

    It 'does NOT warn when an embedded font handle is supplied' {
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath
        $script:doc | Add-VellumPdfParagraph -Text $script:nonLatin -FontHandle $handle -WarningVariable wv | Out-Null
        @($wv).Count | Should -Be 0
        New-VellumPdfTextRun -Text $script:nonLatin -FontHandle $handle -WarningVariable wv2 | Out-Null
        @($wv2).Count | Should -Be 0
    }

    It 'does NOT warn for ASCII or Latin-1 text (accents, tabs, newlines)' {
        # Note: the euro sign (U+20AC) is intentionally NOT here - it is above
        # U+00FF and would (correctly) warn.
        $latin1Only = 'caf' + [char]0x00E9 + ' nai' + [char]0x00EF + "ve`tnewline:`n."
        $script:doc | Add-VellumPdfParagraph -Text $latin1Only -WarningVariable wv | Out-Null
        @($wv).Count | Should -Be 0
    }

    It 'still produces a PDF after warning (warning, not error)' {
        $out = Join-Path $TestDrive 'warned.pdf'
        $script:doc | Add-VellumPdfParagraph -Text $script:nonLatin -WarningAction SilentlyContinue |
            Save-VellumPdfDocument -Path $out
        $script:doc = $null
        [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($out)[0..4]) | Should -Be '%PDF-'
    }
}
