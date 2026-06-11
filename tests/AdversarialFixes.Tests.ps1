#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Tests must construct SecureString objects from known plaintext; suppress the
# PSScriptAnalyzer rule that flags ConvertTo-SecureString -AsPlainText in production code.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Cross-document font handles' {
    It 'rejects a handle registered on a different document' {
        $docA = New-VellumPdfDocument
        $docB = New-VellumPdfDocument
        try {
            $handle = Register-VellumPdfFont -Document $docA -Path $script:fontPath
            { $docB | Add-VellumPdfParagraph -Text 'x' -FontHandle $handle } |
                Should -Throw '*DIFFERENT document*'
            { $docB | Add-VellumPdfHeading -Text 'x' -FontHandle $handle } |
                Should -Throw '*DIFFERENT document*'
        }
        finally { $docA.Dispose(); $docB.Dispose() }
    }

    It 'still accepts the handle on its own document' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $out = Join-Path $TestDrive 'own-doc.pdf'
        $doc | Add-VellumPdfParagraph -Text 'fine' -FontHandle $handle |
            Save-VellumPdfDocument -Path $out
        (Get-Item $out).Length | Should -BeGreaterThan 0
    }
}

Describe 'LinkUri hygiene' {
    BeforeEach { $script:doc = New-VellumPdfDocument }
    AfterEach { if ($script:doc) { try { $script:doc.Dispose() } catch { Write-Verbose "noop: $_" } } }

    It 'rejects javascript:, vbscript:, data: and file: schemes' {
        foreach ($uri in 'javascript:alert(1)', 'VBScript:x', 'data:text/html,x', 'file:///C:/Windows') {
            { $script:doc | Add-VellumPdfParagraph -Text 'link' -LinkUri $uri } |
                Should -Throw '*blocked scheme*'
            { New-VellumPdfTextRun -Text 'link' -LinkUri $uri } |
                Should -Throw '*blocked scheme*'
        }
    }

    It 'treats a whitespace-only -LinkUri as no link (no /URI in output)' {
        $out = Join-Path $TestDrive 'ws-link.pdf'
        $script:doc | Add-VellumPdfParagraph -Text 'no link' -LinkUri '   ' |
            Save-VellumPdfDocument -Path $out
        $script:doc = $null
        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($out))
        $raw | Should -Not -Match '/URI'
    }

    It 'still allows https and mailto links' {
        $out = Join-Path $TestDrive 'ok-link.pdf'
        $run = New-VellumPdfTextRun -Text 'mail' -LinkUri 'mailto:someone@example.com'
        $script:doc |
            Add-VellumPdfParagraph -Text 'site' -LinkUri 'https://example.com' |
            Add-VellumPdfParagraph -Run $run |
            Save-VellumPdfDocument -Path $out
        $script:doc = $null
        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($out))
        $raw | Should -Match 'example\.com'
    }
}

Describe 'Stale (disposed) document guard' {
    It 'rejects further cmdlet calls after Save disposed the document' {
        $doc = New-VellumPdfDocument
        $doc | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path (Join-Path $TestDrive 'first.pdf') | Out-Null

        { $doc | Add-VellumPdfParagraph -Text 'stale' } | Should -Throw '*already saved and disposed*'
        { $doc | Set-VellumPdfDocumentInfo -Title 't' } | Should -Throw '*already saved and disposed*'
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'second.pdf') } |
            Should -Throw '*already saved and disposed*'
    }

    It 'does not flag a document saved with -KeepOpen' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'keep.pdf') -KeepOpen | Out-Null
        { $doc | Add-VellumPdfParagraph -Text 'more' | Out-Null } | Should -Not -Throw
        $doc.Dispose()
    }
}

Describe 'Double protection guard' {
    It 'rejects a second Protect-VellumPdfDocument call' {
        $doc = New-VellumPdfDocument
        try {
            $pw = ConvertTo-SecureString 'pw1' -AsPlainText -Force
            $doc | Protect-VellumPdfDocument -UserPassword $pw | Out-Null
            { $doc | Protect-VellumPdfDocument -UserPassword $pw } |
                Should -Throw '*already protected*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Table column-width validation' {
    BeforeEach { $script:doc = New-VellumPdfDocument }
    AfterEach { if ($script:doc) { try { $script:doc.Dispose() } catch { Write-Verbose "noop: $_" } } }

    It 'rejects negative and zero column widths' {
        { $script:doc | Add-VellumPdfTable -Row @(,@('a','b')) -ColumnWidth @(-5.0, 100.0) } | Should -Throw
        { $script:doc | Add-VellumPdfTable -Row @(,@('a','b')) -ColumnWidth @(0.0, 100.0) } | Should -Throw
    }

    It 'warns when the width count does not match the column count' {
        $script:doc | Add-VellumPdfTable -Row @(,@('a','b')) -ColumnWidth @(100.0, 100.0, 100.0) `
            -WarningVariable wv -WarningAction SilentlyContinue | Out-Null
        @($wv).Count | Should -BeGreaterThan 0
        $wv[0].Message | Should -Match 'column'
    }
}

Describe 'Error message quality' {
    It 'includes the file path when an image fails to load' {
        $doc = New-VellumPdfDocument
        try {
            $fake = Join-Path $TestDrive 'fake.png'
            [System.IO.File]::WriteAllBytes($fake, [byte[]]@(0xFF, 0xD8, 0xFF, 0xE0))
            { $doc | Add-VellumPdfImage -Path $fake } | Should -Throw "*$fake*"
        }
        finally { $doc.Dispose() }
    }

    It 'wraps render failures from Save with a remediation hint' {
        $doc = New-VellumPdfDocument -Margin 10000 | Add-VellumPdfParagraph -Text 'cannot fit'
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'overflow.pdf') } |
            Should -Throw '*failed to render*'
    }
}

Describe 'Misc robustness' {
    It 'accepts empty strings inside -Item arrays (blank list entries)' {
        $doc = New-VellumPdfDocument
        $out = Join-Path $TestDrive 'blank-item.pdf'
        { $doc | Add-VellumPdfList -Item @('first', '', 'third') |
            Save-VellumPdfDocument -Path $out } | Should -Not -Throw
        (Get-Item $out).Length | Should -BeGreaterThan 0
    }

    It 'reports the full emoji codepoint (not a surrogate half) in the encoding warning' {
        $doc = New-VellumPdfDocument
        try {
            $emoji = [char]::ConvertFromUtf32(0x1F600)
            $doc | Add-VellumPdfParagraph -Text "smile $emoji" -WarningVariable wv -WarningAction SilentlyContinue | Out-Null
            @($wv).Count | Should -BeGreaterThan 0
            $wv[0].Message | Should -Match 'U\+1F600'
        }
        finally { $doc.Dispose() }
    }
}
