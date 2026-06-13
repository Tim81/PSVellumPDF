#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Tests must construct SecureString objects from known plaintext; suppress the
# PSScriptAnalyzer rule that flags ConvertTo-SecureString -AsPlainText in production code.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Protect-VellumPdfDocument' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "protect-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Protect-VellumPdfDocument'
    }

    It 'returns the document instance for pipeline chaining (passthrough)' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Chain test.'
        $result = $doc | Protect-VellumPdfDocument -UserPassword $pw
        $result | Should -BeOfType 'VellumPdf.Layout.Document'
        # Same object reference
        [object]::ReferenceEquals($doc, $result) | Should -BeTrue
        $doc.Dispose()
    }

    It 'encrypted save produces a valid non-empty PDF whose raw bytes contain /Encrypt' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Encrypted document.' |
            Protect-VellumPdfDocument -UserPassword $pw |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $header = [System.Text.Encoding]::ASCII.GetString($bytes[0..4])
        $header | Should -Be '%PDF-'

        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'unencrypted control file does NOT contain /Encrypt' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Plain document.' |
            Save-VellumPdfDocument -Path $script:outPath

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Not -Match '/Encrypt'
    }

    It 'encrypted file is larger than unencrypted (encryption adds overhead entries)' {
        # NOTE: Content streams use FlateDecode compression in both cases, so the
        # plaintext marker DISTINCTIVEMARKER_XYZ789 is not visible in either file.
        # Instead we verify that the encrypted PDF is structurally different by
        # confirming the /Encrypt dictionary is present only in the encrypted file,
        # and that the encrypted file has additional bytes (crypto metadata, /Encrypt
        # dict, RC4/AES key derivation info). This is a robust structural differentiator.
        $plainPath = Join-Path $TestDrive "control-plain-$([guid]::NewGuid()).pdf"
        $encPath   = Join-Path $TestDrive "control-enc-$([guid]::NewGuid()).pdf"

        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'DISTINCTIVEMARKER_XYZ789' |
            Save-VellumPdfDocument -Path $plainPath

        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'DISTINCTIVEMARKER_XYZ789' |
            Protect-VellumPdfDocument -UserPassword $pw |
            Save-VellumPdfDocument -Path $encPath

        $plainBytes = [System.IO.File]::ReadAllBytes($plainPath)
        $encBytes   = [System.IO.File]::ReadAllBytes($encPath)

        # Unencrypted does not have /Encrypt
        $plainContent = [System.Text.Encoding]::Latin1.GetString($plainBytes)
        $plainContent | Should -Not -Match '/Encrypt'

        # Encrypted has /Encrypt
        $encContent = [System.Text.Encoding]::Latin1.GetString($encBytes)
        $encContent | Should -Match '/Encrypt'

        # Encrypted file is larger due to encryption overhead (key dict, /Encrypt obj)
        $encBytes.Length | Should -BeGreaterThan $plainBytes.Length
    }

    It 'throws when neither -UserPassword nor -OwnerPassword is supplied' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'No pw.'
        try {
            { $doc | Protect-VellumPdfDocument } |
                Should -Throw '*at least one of -UserPassword or -OwnerPassword*'
        }
        finally { $doc.Dispose() }
    }

    It 'throws a clear error for a PDF/A conformant document' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument -Conformance PdfA2b |
            Add-VellumPdfParagraph -Text 'PDF/A test.'
        try {
            { $doc | Protect-VellumPdfDocument -UserPassword $pw } |
                Should -Throw '*PDF/A conformance*does not allow encryption*'
        }
        finally { $doc.Dispose() }
    }

    It 'applies UserPassword and OwnerPassword both when both are supplied' {
        $userPw  = ConvertTo-SecureString 'userpw123'  -AsPlainText -Force
        $ownerPw = ConvertTo-SecureString 'ownerpw456' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Dual-password doc.' |
            Protect-VellumPdfDocument -UserPassword $userPw -OwnerPassword $ownerPw |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'permission flags Print and Copy combine and produce a valid encrypted PDF' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force

        # Verify the combined flags value in-process to assert both bits are set.
        $combined = [VellumPdf.Encryption.PdfPermissions]'Print, Copy'
        ($combined -band [VellumPdf.Encryption.PdfPermissions]::Print) |
            Should -Be ([VellumPdf.Encryption.PdfPermissions]::Print)
        ($combined -band [VellumPdf.Encryption.PdfPermissions]::Copy) |
            Should -Be ([VellumPdf.Encryption.PdfPermissions]::Copy)

        # Behavioural: the pipeline produces a valid /Encrypt-containing PDF
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Permissions test.' |
            Protect-VellumPdfDocument -UserPassword $pw -Permission Print, Copy |
            Save-VellumPdfDocument -Path $script:outPath

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'default permission (All) produces a valid encrypted PDF' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'All permissions.' |
            Protect-VellumPdfDocument -UserPassword $pw |
            Save-VellumPdfDocument -Path $script:outPath

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'owner-only (no UserPassword) produces a valid encrypted PDF' {
        $ownerPw = ConvertTo-SecureString 'ownerpw' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Owner only.' |
            Protect-VellumPdfDocument -OwnerPassword $ownerPw |
            Save-VellumPdfDocument -Path $script:outPath

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'EncryptMetadata switch is accepted without error' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Encrypt metadata too.' |
            Protect-VellumPdfDocument -UserPassword $pw -EncryptMetadata |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/Encrypt'
    }

    It 'warns when an owner password is set with no user password and default permissions' {
        $ownerPw = ConvertTo-SecureString 'ownerpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Owner only, default perms.'
        $doc | Protect-VellumPdfDocument -OwnerPassword $ownerPw -WarningVariable warn -WarningAction SilentlyContinue | Out-Null
        $warn -join "`n" | Should -Match 'nothing is restricted'
        $doc.Dispose()
    }

    It 'does not warn when -Permission is narrowed on an owner-only document' {
        $ownerPw = ConvertTo-SecureString 'ownerpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Owner only, restricted.'
        $doc | Protect-VellumPdfDocument -OwnerPassword $ownerPw -Permission Print -WarningVariable warn -WarningAction SilentlyContinue | Out-Null
        $warn | Should -BeNullOrEmpty
        $doc.Dispose()
    }

    It 'does not warn when a user password is also supplied' {
        $userPw  = ConvertTo-SecureString 'userpw'  -AsPlainText -Force
        $ownerPw = ConvertTo-SecureString 'ownerpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Both passwords.'
        $doc | Protect-VellumPdfDocument -UserPassword $userPw -OwnerPassword $ownerPw -WarningVariable warn -WarningAction SilentlyContinue | Out-Null
        $warn | Should -BeNullOrEmpty
        $doc.Dispose()
    }
}
