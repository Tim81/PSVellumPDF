<#
    PAdES digital signing: sign a PDF (here with a self-signed certificate
    created in-memory; in real scripts use Get-PfxCertificate or a cert: drive
    entry backed by your organisation's signing certificate).

    Run from the repo root after ./build.ps1 Restore:
        ./examples/04-digital-signing.ps1
    The signature panel of any PDF viewer shows the signer, reason and location
    (the self-signed chain is, of course, untrusted).
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'signed.pdf'

# Demo only: a throwaway self-signed certificate. Production signing uses a
# certificate from a CA, e.g.:
#   $cert = Get-PfxCertificate -FilePath ./signer.pfx
#   $cert = Get-Item Cert:\CurrentUser\My\<thumbprint>
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Example Signer', $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $cert = $req.CreateSelfSigned([DateTimeOffset]::Now, [DateTimeOffset]::Now.AddYears(1))

    New-VellumPdfDocument |
        Add-VellumPdfHeading -Text 'Signed Agreement' -Level 1 |
        Add-VellumPdfParagraph -Text 'This document carries a PAdES baseline digital signature applied at save time.' |
        Set-VellumPdfSignature -Certificate $cert -Reason 'Agreement approved' `
            -Location 'Amsterdam' -ContactInfo 'signer@example.com' |
        Save-VellumPdfDocument -Path $out

    $cert.Dispose()
}
finally {
    $rsa.Dispose()
}

Write-Output "Wrote $out (signed with a self-signed demo certificate)"
