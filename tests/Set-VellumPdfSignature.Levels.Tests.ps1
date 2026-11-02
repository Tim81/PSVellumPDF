#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# PAdES levels, placement and external keys, using in-process test doubles for the
# timestamp authority, revocation source and external signer (no network).

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Level Tests', $script:rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $script:cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))
    # The timestamp authority's own certificate: .NET only decodes a token whose signer
    # certificate carries a critical id-kp-timeStamping extended key usage.
    $tsaKey = [System.Security.Cryptography.RSA]::Create(2048)
    $tsaReq = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Test TSA', $tsaKey,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $ekuOids = [System.Security.Cryptography.OidCollection]::new()
    [void]$ekuOids.Add([System.Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.8'))
    $tsaReq.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuOids, $true))
    $tsaReq.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new('DigitalSignature', $true))
    $script:tsaCert = $tsaReq.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))
    $script:pubOnly = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $script:cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

    $lib = Join-Path (Split-Path $PSScriptRoot -Parent) 'lib'
    $refs = @(
        (Join-Path $lib 'VellumPdf.Signing.dll')
        [System.Security.Cryptography.Pkcs.SignedCms].Assembly.Location
        [System.Security.Cryptography.X509Certificates.X509Certificate2].Assembly.Location
        [System.Formats.Asn1.AsnWriter].Assembly.Location
        [System.Numerics.BigInteger].Assembly.Location
        (Join-Path ([System.IO.Path]::GetDirectoryName([object].Assembly.Location)) 'System.Runtime.dll')
        (Join-Path ([System.IO.Path]::GetDirectoryName([object].Assembly.Location)) 'netstandard.dll')
    ) | Select-Object -Unique
    if (-not ('PSVellumPDF.Tests.MockTsa' -as [type])) {
        Add-Type -ReferencedAssemblies $refs -TypeDefinition @'
using System;
using System.Formats.Asn1;
using System.Security.Cryptography;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using VellumPdf.Signing;

namespace PSVellumPDF.Tests
{
    // A timestamp authority that builds a structurally valid RFC 3161 token (not trusted).
    public sealed class MockTsa : ITimestampClient
    {
        private readonly X509Certificate2 _cert;
        public int Calls;
        public MockTsa(X509Certificate2 cert) { _cert = cert; }

        public byte[] GetTimestampToken(ReadOnlySpan<byte> messageDigest, HashAlgorithmName hashAlgorithm)
        {
            Calls++;
            var tst = new AsnWriter(AsnEncodingRules.DER);
            using (tst.PushSequence())
            {
                tst.WriteInteger(1);
                tst.WriteObjectIdentifier("1.2.3.4.1");
                using (tst.PushSequence())
                {
                    using (tst.PushSequence()) { tst.WriteObjectIdentifier("2.16.840.1.101.3.4.2.1"); tst.WriteNull(); }
                    tst.WriteOctetString(messageDigest);
                }
                tst.WriteInteger(Calls);
                tst.WriteGeneralizedTime(DateTimeOffset.UtcNow, true);
            }
            var cms = new SignedCms(new ContentInfo(new Oid("1.2.840.113549.1.9.16.1.4"), tst.Encode()));
            var signer = new CmsSigner(SubjectIdentifierType.IssuerAndSerialNumber, _cert)
            {
                DigestAlgorithm = new Oid("2.16.840.1.101.3.4.2.1"),
                IncludeOption = X509IncludeOption.EndCertOnly,
            };
            var ess = new AsnWriter(AsnEncodingRules.DER);
            using (ess.PushSequence()) using (ess.PushSequence()) using (ess.PushSequence())
                ess.WriteOctetString(SHA256.HashData(_cert.RawData));
            signer.SignedAttributes.Add(new AsnEncodedData(new Oid("1.2.840.113549.1.9.16.2.47"), ess.Encode()));
            cms.ComputeSignature(signer);
            return cms.Encode();
        }
    }

    public sealed class MockRevocation : IRevocationClient
    {
        public int Calls;
        public RevocationData GetRevocationData(X509Certificate2 certificate, X509Certificate2 issuer)
        {
            Calls++;
            return new RevocationData { Crl = new byte[] { 0x30, 0x03, 0x02, 0x01, 0x01 } };
        }
    }

    // Signs the digest of the CMS signed attributes with a local RSA key, like a KMS would.
    public sealed class MockExternalSigner : IExternalSigner
    {
        private readonly RSA _rsa;
        public int Calls;
        public MockExternalSigner(RSA rsa) { _rsa = rsa; }
        public HashAlgorithmName HashAlgorithm => HashAlgorithmName.SHA256;
        public Task<byte[]> SignAsync(ReadOnlyMemory<byte> signedAttributesDigest, CancellationToken cancellationToken = default)
        {
            Calls++;
            return Task.FromResult(_rsa.SignHash(signedAttributesDigest.ToArray(), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1));
        }
    }
}
'@
    }
    function script:New-SignedDoc([hashtable]$Sign, [string]$Name, [int]$Pages = 1) {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Signed content'
        for ($i = 1; $i -lt $Pages; $i++) { $doc = $doc | Add-VellumPdfParagraph -Text ('x' * 10) -MarginTop 700 }
        $doc | Set-VellumPdfSignature @Sign | Out-Null
        $path = Join-Path $TestDrive "$Name.pdf"
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        $path
    }
}

AfterAll {
    foreach ($d in $script:cert, $script:pubOnly, $script:rsa, $script:tsaCert) { if ($d) { $d.Dispose() } }
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Set-VellumPdfSignature PAdES levels' {
    It 'defaults to B-B, and to B-T once a timestamp client is given' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            $doc | Set-VellumPdfSignature -Certificate $script:cert | Out-Null
            $doc.PSVellumSignature.Level | Should -Be 'B_B'
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient ([PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)) | Out-Null
            $doc.PSVellumSignature.Level | Should -Be 'B_T'
        }
        finally { $doc.Dispose() }
    }

    It 'embeds a timestamp token for B-T (the TSA is called once)' {
        $tsa = [PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)
        $path = New-SignedDoc @{ Certificate = $script:cert; TimestampClient = $tsa } 'bt'
        $tsa.Calls | Should -Be 1
        (Get-PdfText $path) | Should -Match '/ByteRange'
    }

    It 'produces B-LT: writes a /DSS (a self-signed chain has no issuer, so nothing is looked up)' {
        $tsa = [PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)
        $rev = [PSVellumPDF.Tests.MockRevocation]::new()
        $path = New-SignedDoc @{ Certificate = $script:cert; TimestampClient = $tsa; RevocationClient = $rev; Level = 'B-LT' } 'blt'
        $tsa.Calls | Should -Be 1
        $rev.Calls | Should -Be 0   # revocation is fetched per certificate that HAS an issuer in the chain
        Get-PdfText $path | Should -Match '/DSS'
    }

    It 'produces B-LTA: adds a document timestamp after the DSS' {
        $tsa = [PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)
        $rev = [PSVellumPDF.Tests.MockRevocation]::new()
        $path = New-SignedDoc @{ Certificate = $script:cert; TimestampClient = $tsa; RevocationClient = $rev; Level = 'B-LTA' } 'blta'
        $tsa.Calls | Should -Be 2   # the signature timestamp and the archive (document) timestamp
        Get-PdfText $path | Should -Match '/DocTimeStamp'
    }

    It 'raises the reserved signature size for B-LT/B-LTA unless told otherwise' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            $tsa = [PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -Level B-LT | Out-Null
            $doc.PSVellumSignature.EstimatedSignatureSizeBytes | Should -Be 32768
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -Level B-LT -EstimatedSignatureSize 50000 | Out-Null
            $doc.PSVellumSignature.EstimatedSignatureSizeBytes | Should -Be 50000
            $doc.PSVellumSignature.RevocationClient | Should -BeOfType ([VellumPdf.Signing.HttpRevocationClient])
            # Per-signature client with a capped redirect budget, disposed with the document.
            $doc.PSVellumRevocationHttpClient | Should -BeOfType ([System.Net.Http.HttpClient])
            $client = $doc.PSVellumRevocationHttpClient
            $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -Level B-LT | Out-Null
            [object]::ReferenceEquals($doc.PSVellumRevocationHttpClient, $client) | Should -BeFalse   # re-staging replaced (and disposed) it
        }
        finally { $doc.Dispose() }
    }

    It 'validates level, timestamp and revocation parameter combinations' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        $tsa = [PSVellumPDF.Tests.MockTsa]::new($script:tsaCert)
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:cert -Level B-T } | Should -Throw '*needs a signature timestamp*'
            { $doc | Set-VellumPdfSignature -Certificate $script:cert -Level B-B -TimestampClient $tsa } | Should -Throw '*carries no timestamp*'
            { $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -TimestampUrl 'https://tsa.example' } | Should -Throw '*cannot be combined*'
            { $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -RevocationTimeout ([timespan]::FromSeconds(5)) } | Should -Throw '*B-LT or B-LTA only*'
            { $doc | Set-VellumPdfSignature -Certificate $script:cert -TimestampClient $tsa -Level B-LT `
                    -RevocationClient ([PSVellumPDF.Tests.MockRevocation]::new()) -RevocationTimeout ([timespan]::FromSeconds(5)) } | Should -Throw '*cannot be combined*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Set-VellumPdfSignature placement and algorithm options' {
    It 'maps -SignaturePage (1-based) and -SubFilter' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            $doc | Set-VellumPdfSignature -Certificate $script:cert -SignaturePage 2 -SubFilter Pkcs7 | Out-Null
            $doc.PSVellumSignature.SignaturePage | Should -Be 1
            $doc.PSVellumSignature.SubFilter | Should -Be 'adbe.pkcs7.detached'
            $doc | Set-VellumPdfSignature -Certificate $script:cert -SubFilter Pades | Out-Null
            $doc.PSVellumSignature.SubFilter | Should -Be 'ETSI.CAdES.detached'
        }
        finally { $doc.Dispose() }
    }

    It 'writes the legacy sub-filter when asked' {
        $path = New-SignedDoc @{ Certificate = $script:cert; SubFilter = 'Pkcs7' } 'pkcs7'
        Get-PdfText $path | Should -Match 'adbe\.pkcs7\.detached'
    }

    It 'fails with a hint when the signature page is past the end of the document' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        $doc | Set-VellumPdfSignature -Certificate $script:cert -SignaturePage 5 | Out-Null
        try {
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'page.pdf') -KeepOpen } | Should -Throw '*-SignaturePage 5 must not exceed*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Set-VellumPdfSignature external keys' {
    It 'signs with -ExternalPrivateKey and a public-only certificate' {
        $path = New-SignedDoc @{ Certificate = $script:pubOnly; ExternalPrivateKey = $script:rsa } 'extkey'
        Get-PdfText $path | Should -Match '/ByteRange'
    }

    It 'signs asynchronously with an -ExternalSigner' {
        $signer = [PSVellumPDF.Tests.MockExternalSigner]::new($script:rsa)
        $path = New-SignedDoc @{ Certificate = $script:pubOnly; ExternalSigner = $signer } 'extsigner'
        $signer.Calls | Should -Be 1
        Get-PdfText $path | Should -Match '/ByteRange'
    }

    It 'still demands a private key when no external key is supplied' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try { { $doc | Set-VellumPdfSignature -Certificate $script:pubOnly } | Should -Throw '*does not include a private key*-ExternalPrivateKey*' }
        finally { $doc.Dispose() }
    }

    It 'rejects both external options together, and an external signer with drawings (either order)' {
        $signer = [PSVellumPDF.Tests.MockExternalSigner]::new($script:rsa)
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
        try {
            { $doc | Set-VellumPdfSignature -Certificate $script:pubOnly -ExternalPrivateKey $script:rsa -ExternalSigner $signer } | Should -Throw '*cannot be combined*'
            $doc | Set-VellumPdfSignature -Certificate $script:pubOnly -ExternalSigner $signer | Out-Null
            { $doc | Add-VellumPdfDrawing -Height 10 -ScriptBlock { } } | Should -Throw '*-ExternalSigner*cannot run drawing*'
        }
        finally { $doc.Dispose() }

        $doc2 = New-VellumPdfDocument | Add-VellumPdfDrawing -Height 10 -ScriptBlock { }
        try { { $doc2 | Set-VellumPdfSignature -Certificate $script:pubOnly -ExternalSigner $signer } | Should -Throw '*cannot run the*script blocks*' }
        finally { $doc2.Dispose() }
    }
}
