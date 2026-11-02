<#
    Signing with a key you cannot export: a cloud KMS or an HSM.

    The signing key never leaves the service. VellumPdf hashes the signed CMS
    attributes and hands that digest to an IExternalSigner, which asks the service to
    sign it. Only the public certificate is needed locally.

    Why a compiled class and not a script block: VellumPdf calls the signer
    asynchronously on thread-pool threads, and a PowerShell script block cannot run
    there (it needs a runspace). A small C# class compiled with Add-Type has no such
    limit and is also where your KMS SDK or HTTPS call goes. For the same reason a
    document with drawings (Add-VellumPdfDrawing) cannot use -ExternalSigner.

    This example stands in for the KMS with a local ECDSA key so that it runs
    anywhere; look for the "KMS CALL" comment to see what to replace. KMS services
    return an ECDSA signature either as raw r||s (AWS KMS RAW, Azure Key Vault, Google
    Cloud KMS for P1363) or as DER. CMS needs DER, so convert raw output with
    EcdsaSignatureConverter.RawToDer, as below. RSA services return the final
    signature and need no conversion.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/09-kms-signing.ps1
#>
#requires -Version 7.6
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'kms-signed.pdf')
)

Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

if (-not ('PSVellumPDF.Examples.KmsSigner' -as [type])) {
    $lib = Join-Path $PSScriptRoot '..' 'lib'
    $runtimeDir = [System.IO.Path]::GetDirectoryName([object].Assembly.Location)
    $references = @(
        (Join-Path $lib 'VellumPdf.Signing.dll')
        [System.Security.Cryptography.ECDsa].Assembly.Location
        [System.Security.Cryptography.X509Certificates.X509Certificate2].Assembly.Location
        (Join-Path $runtimeDir 'System.Runtime.dll')
        (Join-Path $runtimeDir 'netstandard.dll')
    ) | Select-Object -Unique

    Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using VellumPdf.Signing;

namespace PSVellumPDF.Examples
{
    // Signs the digest through a "KMS". Here the KMS is a local ECDSA P-256 key.
    public sealed class KmsSigner : IExternalSigner
    {
        private readonly ECDsa _standInForKms;
        public int Calls;

        public KmsSigner(ECDsa standInForKms) { _standInForKms = standInForKms; }

        // Must match the hash the KMS key signs with.
        public HashAlgorithmName HashAlgorithm => HashAlgorithmName.SHA256;

        public Task<byte[]> SignAsync(ReadOnlyMemory<byte> signedAttributesDigest, CancellationToken cancellationToken = default)
        {
            Calls++;
            // KMS CALL: replace the next line with the service call, e.g. an HTTPS request that
            // sends 'signedAttributesDigest' as the pre-hashed digest and returns the signature.
            byte[] raw = _standInForKms.SignHash(signedAttributesDigest.ToArray());   // raw r||s

            // CMS wants a DER-encoded ECDSA signature.
            return Task.FromResult(EcdsaSignatureConverter.RawToDer(raw));
        }
    }
}
'@
}

$ecdsa = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
try {
    # In production: the certificate that belongs to the KMS key, exported without a private key,
    #   $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new('./signer.cer')
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF KMS Example', $ecdsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $selfSigned = $req.CreateSelfSigned([DateTimeOffset]::Now, [DateTimeOffset]::Now.AddYears(1))
    $publicCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $selfSigned.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    $selfSigned.Dispose()

    $signer = [PSVellumPDF.Examples.KmsSigner]::new($ecdsa)

    New-VellumPdfDocument |
        Add-VellumPdfHeading -Text 'Signed through a KMS' -Level 1 |
        Add-VellumPdfParagraph -Text 'The private key never left the key service; only the digest was sent for signing.' |
        Set-VellumPdfSignature -Certificate $publicCert -ExternalSigner $signer -Reason 'Approved' -Location 'Amsterdam' |
        Save-VellumPdfDocument -Path $OutputPath -Force

    $publicCert.Dispose()
    Write-Output "Wrote $OutputPath (signer called $($signer.Calls) time)"
}
finally {
    $ecdsa.Dispose()
}
