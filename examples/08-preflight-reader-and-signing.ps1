<#
    Check, inspect and sign PDFs:
      * Test-VellumPdfConformance   in-process PDF/A and PDF/UA preflight
      * Get-VellumPdfInfo / -Text   read an existing PDF (experimental Reader)
      * Set-VellumPdfSignature      PAdES levels: B-B here; B-T/B-LT/B-LTA need a
                                    timestamp authority (-TimestampUrl) and, for
                                    B-LT/B-LTA, network access to OCSP/CRL servers.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/08-preflight-reader-and-signing.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$pdf = Join-Path $PSScriptRoot 'inspect-me.pdf'
$ttf = Join-Path $PSScriptRoot '..' 'tests' 'assets' 'DejaVuSans.ttf'

# A throwaway self-signed certificate; production code loads one with
# Get-PfxCertificate or from the cert: drive.
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=PSVellumPDF Example', $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(30))

    $doc = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
    $font = Register-VellumPdfFont -Document $doc -Path $ttf
    $doc |
        Set-VellumPdfDocumentInfo -Title 'Signed archive copy' |
        Add-VellumPdfHeading -Text 'Signed archive copy' -FontHandle $font |
        Add-VellumPdfParagraph -Text 'Signed with a PAdES baseline signature.' -FontHandle $font |
        Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' -Location 'Amsterdam' |
        Save-VellumPdfDocument -Path $pdf -Validate | Out-Null     # preflight runs before the file is written

    '--- Preflight'
    Test-VellumPdfConformance -Path $pdf | Format-Table Profile, IsCompliant, ErrorCount -AutoSize

    '--- Structure'
    $info = Get-VellumPdfInfo -Path $pdf
    "{0} page(s), encrypted: {1}, claims: {2}" -f $info.PageCount, $info.IsEncrypted, ($info.ClaimedProfiles -join ', ')
    $info.Signatures | Format-Table SubFilter, SigningTime, ContentsLength -AutoSize

    '--- Text'
    Get-VellumPdfText -Path $pdf
}
finally {
    $rsa.Dispose()
}
