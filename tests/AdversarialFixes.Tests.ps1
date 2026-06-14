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
                Should -Throw '*only http, https, and mailto*'
            { New-VellumPdfTextRun -Text 'link' -LinkUri $uri } |
                Should -Throw '*only http, https, and mailto*'
        }
    }

    It 'rejects any non-allowlisted scheme, including relative and scheme-relative URIs' {
        # Allowlist semantics: only http/https/mailto pass. Everything else is
        # rejected, so an unanticipated protocol handler can never reach the PDF.
        foreach ($uri in 'ftp://host/f', 'tel:+15551234', 'ms-msdt:/id', '//evil.example/x', '/relative/path') {
            { $script:doc | Add-VellumPdfParagraph -Text 'link' -LinkUri $uri } |
                Should -Throw '*only http, https, and mailto*'
            { New-VellumPdfTextRun -Text 'link' -LinkUri $uri } |
                Should -Throw '*only http, https, and mailto*'
        }
    }

    It 'rejects blocked schemes smuggled past with embedded whitespace/control chars' {
        # Lenient readers strip this noise before dispatching the scheme, so the
        # scheme must be read from a normalised copy (not just trimmed leading).
        $tab  = "java`tscript:alert(1)"                       # tab inside keyword
        $ctrl = [char]0x01 + 'javascript:alert(1)'            # leading control byte
        $nbsp = 'java' + [char]0x00A0 + 'script:alert(1)'     # no-break space inside keyword
        foreach ($uri in $tab, $ctrl, $nbsp) {
            { $script:doc | Add-VellumPdfParagraph -Text 'link' -LinkUri $uri } |
                Should -Throw '*only http, https, and mailto*'
            { New-VellumPdfTextRun -Text 'link' -LinkUri $uri } |
                Should -Throw '*only http, https, and mailto*'
        }
    }

    It 'does not false-positive on a safe URL that merely contains a blocked keyword in its path' {
        $out = Join-Path $TestDrive 'kw-in-path.pdf'
        { $script:doc |
            Add-VellumPdfParagraph -Text 'ok' -LinkUri 'https://example.com/javascript:guide' |
            Save-VellumPdfDocument -Path $out } | Should -Not -Throw
        $script:doc = $null
        (Get-Item $out).Length | Should -BeGreaterThan 0
    }

    It 'treats a whitespace-only -LinkUri as no link (no /URI in output)' {
        $out = Join-Path $TestDrive 'ws-link.pdf'
        $script:doc | Add-VellumPdfParagraph -Text 'no link' -LinkUri '   ' |
            Save-VellumPdfDocument -Path $out
        $script:doc = $null
        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($out))
        $raw | Should -Not -Match '/URI'
    }

    It 'stores the link with embedded whitespace/control characters stripped' {
        $out = Join-Path $TestDrive 'clean-link.pdf'
        # Tab between the slash and the path; the stored /URI must not contain it.
        $script:doc |
            Add-VellumPdfParagraph -Text 'ok' -LinkUri "https://example.com/`tpath" |
            Save-VellumPdfDocument -Path $out
        $script:doc = $null
        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($out))
        $raw | Should -Match 'example\.com/path'
        $raw | Should -Not -Match "example\.com/`tpath"
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

    It 'reports a signing failure as a signing failure, not a render failure' {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        try {
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                'CN=Save Test', $rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))
            $doc = New-VellumPdfDocument |
                Add-VellumPdfParagraph -Text 'x' |
                Set-VellumPdfSignature -Certificate $cert
            $cert.Dispose()   # break signing after staging
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'sign-fail.pdf') } |
                Should -Throw '*failed to sign*'
        }
        finally { $rsa.Dispose() }
    }
}

Describe 'Save-VellumPdfDocument failure and -WhatIf hardening' {
    It 'preserves a pre-existing good file when a later save fails (no truncation)' {
        $path = Join-Path $TestDrive 'preserve.pdf'
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'good' |
            Save-VellumPdfDocument -Path $path | Out-Null
        $originalLen = (Get-Item $path).Length
        $originalLen | Should -BeGreaterThan 0

        $bad = New-VellumPdfDocument -Margin 10000 | Add-VellumPdfParagraph -Text 'cannot fit'
        { $bad | Save-VellumPdfDocument -Path $path } | Should -Throw

        # The original file is intact, not a 0-byte truncation.
        (Get-Item $path).Length | Should -Be $originalLen
        # And no temp artifact is left beside it.
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp').Count | Should -Be 0
    }

    It 'leaves no 0-byte artifact when a save to a new path fails' {
        $path = Join-Path $TestDrive 'never-created.pdf'
        $bad = New-VellumPdfDocument -Margin 10000 | Add-VellumPdfParagraph -Text 'cannot fit'
        { $bad | Save-VellumPdfDocument -Path $path } | Should -Throw
        Test-Path -LiteralPath $path | Should -BeFalse
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp').Count | Should -Be 0
    }

    It 'a successful save leaves no temp file behind' {
        $path = Join-Path $TestDrive 'clean.pdf'
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path $path | Out-Null
        (Get-Item $path).Length | Should -BeGreaterThan 0
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp').Count | Should -Be 0
    }

    It '-WhatIf to a nonexistent directory leaves the document open and writes nothing' {
        $dir  = Join-Path $TestDrive 'no-such-dir'
        $path = Join-Path $dir 'f.pdf'
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            { $doc | Save-VellumPdfDocument -Path $path -WhatIf } | Should -Not -Throw
            # Document must still be usable (not disposed by the dry run).
            $doc.PSObject.Properties['PSVellumDisposed'] | Should -BeNullOrEmpty
            { $doc | Add-VellumPdfParagraph -Text 'more' | Out-Null } | Should -Not -Throw
            Test-Path -LiteralPath $dir | Should -BeFalse
        }
        finally { $doc.Dispose() }
    }

    It 'reports a clear error (and leaves no temp) when -Path cannot be written, e.g. a directory' {
        $dirPath = Join-Path $TestDrive 'target-is-a-dir'
        New-Item -ItemType Directory -Path $dirPath | Out-Null
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        { $doc | Save-VellumPdfDocument -Path $dirPath } |
            Should -Throw '*could not write it to*'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.tmp' -Recurse).Count | Should -Be 0
    }

    It 'still disposes the document when a real (non-WhatIf) save hits a missing directory' {
        # Preserves the documented non-WhatIf contract: a save attempt - even one
        # that fails the directory pre-check - is terminal and disposes the doc.
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'missing-dir' 'x.pdf') } |
            Should -Throw '*directory not found*'
        { $doc.Save((Join-Path $TestDrive 'after.pdf')) } | Should -Throw
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
