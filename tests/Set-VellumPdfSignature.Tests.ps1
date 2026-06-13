#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Tests must construct SecureString objects from known plaintext; suppress the
# PSScriptAnalyzer rule that flags ConvertTo-SecureString -AsPlainText in production code.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    # Self-signed signing certificate created in-memory with pure .NET so the
    # suite runs identically on Windows, Linux, and macOS (no cert store, no
    # New-SelfSignedCertificate, no openssl).
    $script:rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Tests', $script:rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $script:cert = $req.CreateSelfSigned(
        [DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))

    # Public-only sibling of the same certificate (no private key).
    $script:pubOnlyCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $script:cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

    # Extracts the CMS (PKCS#7) blob from the /Contents hex string of a signed
    # PDF and returns exactly the DER-encoded bytes (the hex string is padded
    # with zeros to the reserved placeholder size, so the DER outer length
    # header is used to find the true end).
    function script:Get-SignatureCmsBlob([byte[]]$PdfBytes) {
        $text = [System.Text.Encoding]::Latin1.GetString($PdfBytes)
        # VellumPdf 1.5.x emits a placeholder comment between /Contents and the
        # hex string (e.g. "/Contents %VELLUM_SIG_CONTENTS_...<hex>"); skip an
        # optional PDF comment line before the angle-bracketed hex.
        $m = [regex]::Match($text, '/Contents\s*(?:%[^\r\n]*\r?\n\s*)?<([0-9A-Fa-f]+)>')
        if (-not $m.Success) { throw 'No /Contents hex string found in PDF.' }
        $padded = [System.Convert]::FromHexString($m.Groups[1].Value)
        # DER TLV: tag, then short- or long-form length.
        $lenByte = $padded[1]
        if ($lenByte -band 0x80) {
            $numLenBytes = $lenByte -band 0x7F
            $len = 0
            for ($i = 0; $i -lt $numLenBytes; $i++) { $len = ($len * 256) + $padded[2 + $i] }
            $total = 2 + $numLenBytes + $len
        }
        else {
            $total = 2 + $lenByte
        }
        return $padded[0..($total - 1)]
    }
}

AfterAll {
    if ($script:cert) { $script:cert.Dispose() }
    if ($script:pubOnlyCert) { $script:pubOnlyCert.Dispose() }
    if ($script:rsa) { $script:rsa.Dispose() }
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfSignature' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "sign-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        (Get-Module PSVellumPDF).ExportedFunctions.Keys | Should -Contain 'Set-VellumPdfSignature'
    }

    It 'returns the document instance for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Chain test.'
        $result = $doc | Set-VellumPdfSignature -Certificate $script:cert
        [object]::ReferenceEquals($doc, $result) | Should -BeTrue
        $doc.Dispose()
    }

    It 'signed save produces a valid PDF containing /ByteRange, /Sig and the PAdES SubFilter' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Signed document.' |
            Set-VellumPdfSignature -Certificate $script:cert -Reason 'Approval' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $header = [System.Text.Encoding]::ASCII.GetString($bytes[0..4])
        $header | Should -Be '%PDF-'

        $content = [System.Text.Encoding]::Latin1.GetString($bytes)
        $content | Should -Match '/ByteRange'
        $content | Should -Match '/Type\s*/Sig'
        $content | Should -Match '/SubFilter\s*/ETSI\.CAdES\.detached'
    }

    It 'unsigned control file does NOT contain /ByteRange or /Sig' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Plain document.' |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Not -Match '/ByteRange'
        $content | Should -Not -Match '/Type\s*/Sig'
    }

    It 'embedded signature is a valid CMS blob whose signature verifies against the certificate' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Cryptographically verified.' |
            Set-VellumPdfSignature -Certificate $script:cert |
            Save-VellumPdfDocument -Path $script:outPath

        $pdfBytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $cmsBytes = Get-SignatureCmsBlob $pdfBytes

        # PAdES signatures are detached: the signed content is the file outside
        # the /Contents hex hole, described by /ByteRange [o1 l1 o2 l2].
        $text = [System.Text.Encoding]::Latin1.GetString($pdfBytes)
        $br = [regex]::Match($text, '/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]')
        $br.Success | Should -BeTrue
        $o1 = [int]$br.Groups[1].Value; $l1 = [int]$br.Groups[2].Value
        $o2 = [int]$br.Groups[3].Value; $l2 = [int]$br.Groups[4].Value
        $signedContent = [byte[]]::new($l1 + $l2)
        [System.Array]::Copy($pdfBytes, $o1, $signedContent, 0, $l1)
        [System.Array]::Copy($pdfBytes, $o2, $signedContent, $l1, $l2)

        $contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new($signedContent)
        $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
        $cms.Decode($cmsBytes)

        # Verifies both the signer signature and the messageDigest attribute
        # against the actual document bytes (verifySignatureOnly - the chain is
        # self-signed by construction).
        { $cms.CheckSignature($true) } | Should -Not -Throw
        $cms.SignerInfos.Count | Should -Be 1
        $cms.SignerInfos[0].Certificate.Subject | Should -Be 'CN=PSVellumPDF Tests'
    }

    It 'records Reason, Location, ContactInfo and SignerName in the signature dictionary' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Metadata test.' |
            Set-VellumPdfSignature -Certificate $script:cert -Reason 'UNIQREASON77' `
                -Location 'UNIQLOCATION77' -ContactInfo 'UNIQCONTACT77' -SignerName 'UNIQSIGNER77' |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Match 'UNIQREASON77'
        $content | Should -Match 'UNIQLOCATION77'
        $content | Should -Match 'UNIQCONTACT77'
        $content | Should -Match 'UNIQSIGNER77'
    }

    It 'signs a PDF/A-2b conformant document (PAdES and PDF/A compose)' {
        $fontPath = Join-Path $PSScriptRoot 'assets/DejaVuSans.ttf'
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $font = Register-VellumPdfFont -Document $doc -Path $fontPath
        $doc |
            Set-VellumPdfDocumentInfo -Title 'Signed archival' -Author 'Tests' |
            Add-VellumPdfParagraph -Text 'Archival signed content.' -FontHandle $font |
            Set-VellumPdfSignature -Certificate $script:cert |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Match '/ByteRange'
        $content | Should -Match 'pdfaid'   # XMP PDF/A identification survives signing
    }

    It 'calling Set-VellumPdfSignature again replaces the staged settings (last wins)' {
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Replace test.' |
            Set-VellumPdfSignature -Certificate $script:cert -Reason 'FIRSTREASON88' |
            Set-VellumPdfSignature -Certificate $script:cert -Reason 'SECONDREASON99' |
            Save-VellumPdfDocument -Path $script:outPath

        $content = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $content | Should -Match 'SECONDREASON99'
        $content | Should -Not -Match 'FIRSTREASON88'
    }

    It 'throws when the certificate has no private key' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'No key.'
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:pubOnlyCert } |
                Should -Throw '*does not include a private key*'
        }
        finally { $doc.Dispose() }
    }

    It 'throws when the document is already protected with encryption' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Encrypted.' |
            Protect-VellumPdfDocument -UserPassword $pw
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:cert } |
                Should -Throw '*encryption and digital signatures cannot be combined*'
        }
        finally { $doc.Dispose() }
    }

    It 'Protect-VellumPdfDocument throws when a signature is already staged' {
        $pw = ConvertTo-SecureString 'testpw' -AsPlainText -Force
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Signed first.' |
            Set-VellumPdfSignature -Certificate $script:cert
        try {
            { $doc | Protect-VellumPdfDocument -UserPassword $pw } |
                Should -Throw '*encryption and digital signatures cannot be combined*'
        }
        finally { $doc.Dispose() }
    }

    It 'throws a clear error when used on an already-saved (disposed) document' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Stale.'
        $doc | Save-VellumPdfDocument -Path $script:outPath
        { $doc | Set-VellumPdfSignature -Certificate $script:cert } |
            Should -Throw '*disposed*'
    }

    It 'Save -WhatIf with a staged signature writes nothing and leaves the document open' {
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'WhatIf.' |
            Set-VellumPdfSignature -Certificate $script:cert
        try {
            $doc | Save-VellumPdfDocument -Path $script:outPath -WhatIf
            Test-Path $script:outPath | Should -BeFalse
            # Still usable: a real save afterwards succeeds and is signed.
            $doc | Save-VellumPdfDocument -Path $script:outPath
            $content = [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath))
            $content | Should -Match '/ByteRange'
        }
        finally {
            if (-not $doc.PSObject.Properties['PSVellumDisposed']) { $doc.Dispose() }
        }
    }
}

Describe 'Set-VellumPdfSignature RFC-3161 timestamp (PAdES B-T)' {
    # These exercise staging and the fail-fast guards only. Saving with a real
    # -TimestampUrl contacts the TSA over the network, so the B-T round trip is
    # not unit-tested offline; constructing the HttpTimestampClient does not
    # itself make a request.
    It 'stages a TimestampClient on the signature settings when -TimestampUrl is given' {
        $doc = New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Timestamped.' |
            Set-VellumPdfSignature -Certificate $script:cert `
                -TimestampUrl 'http://timestamp.example/tsa'
        try {
            $settings = $doc.PSObject.Properties['PSVellumSignature'].Value
            $settings.TimestampClient | Should -Not -BeNullOrEmpty
            $settings.TimestampClient | Should -BeOfType ([VellumPdf.Signing.HttpTimestampClient])
        }
        finally { $doc.Dispose() }
    }

    It 'rejects a -TimestampUrl whose scheme is not http or https' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Bad scheme.'
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:cert `
                    -TimestampUrl 'ftp://timestamp.example/tsa' } |
                Should -Throw '*http or https*'
        }
        finally { $doc.Dispose() }
    }

    It 'requires -TimestampUrl when -TimestampTimeout is given without it' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'No url.'
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:cert `
                    -TimestampTimeout ([timespan]::FromSeconds(10)) } |
                Should -Throw '*require -TimestampUrl*'
        }
        finally { $doc.Dispose() }
    }

    It 'requires -TimestampUrl when -TimestampRequestCertificate is given without it' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'No url.'
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:cert `
                    -TimestampRequestCertificate $false } |
                Should -Throw '*require -TimestampUrl*'
        }
        finally { $doc.Dispose() }
    }

    It 'replaces (does not orphan) the stashed HttpClient when re-staged with a new -TimestampUrl' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Re-stage.'
        try {
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampUrl 'http://tsa-a.example/t' | Out-Null
            $first = $doc.PSObject.Properties['PSVellumTimestampHttpClient'].Value
            $first | Should -Not -BeNullOrEmpty
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampUrl 'http://tsa-b.example/t' | Out-Null
            $second = $doc.PSObject.Properties['PSVellumTimestampHttpClient'].Value
            $second | Should -Not -BeNullOrEmpty
            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            # The replaced client is disposed: a send on it now throws.
            { $first.CancelPendingRequests() } | Should -Throw
        }
        finally { $doc.Dispose() }
    }

    It 'clears the stashed HttpClient when re-staged without -TimestampUrl' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Drop ts.'
        try {
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampUrl 'http://tsa.example/t' | Out-Null
            $doc.PSObject.Properties['PSVellumTimestampHttpClient'].Value | Should -Not -BeNullOrEmpty
            $doc | Set-VellumPdfSignature -Certificate $script:cert | Out-Null
            $doc.PSObject.Properties['PSVellumTimestampHttpClient'].Value | Should -BeNullOrEmpty
            $doc.PSObject.Properties['PSVellumSignature'].Value.TimestampClient | Should -BeNullOrEmpty
        }
        finally { $doc.Dispose() }
    }

    It 'a TSA failure at save reports a timestamp-authority hint and leaves no file' {
        # Loopback discard port: connection is refused fast and deterministically,
        # with no external network dependency.
        $out = Join-Path $TestDrive "tsafail-$([guid]::NewGuid()).pdf"
        { New-VellumPdfDocument |
                Add-VellumPdfParagraph -Text 'TSA down.' |
                Set-VellumPdfSignature -Certificate $script:cert `
                    -TimestampUrl 'http://127.0.0.1:9/tsa' -TimestampTimeout ([timespan]::FromSeconds(5)) |
                Save-VellumPdfDocument -Path $out } |
            Should -Throw '*timestamp authority*'
        Test-Path $out | Should -BeFalse
    }
}
