function Set-VellumPdfSignature {
    <#
    .SYNOPSIS
        Stages a PAdES digital signature to be applied when the document is saved.
    .DESCRIPTION
        Builds a VellumPdf.Signing.PdfSignatureSettings from the supplied
        certificate and metadata and stages it on the document. The signature is
        applied by Save-VellumPdfDocument, which signs the document while writing
        the file (VellumPdf signs at serialization time via
        SigningExtensions.Sign; a signature cannot be added to an already-written
        document through this module).

        The signature is a PAdES baseline signature (SubFilter
        ETSI.CAdES.detached). Supplying -TimestampUrl adds an RFC-3161 timestamp
        from a Time-Stamping Authority, upgrading the signature from PAdES B-B to
        PAdES B-T so the signing time is independently attested rather than
        claimed by the signer's clock. PDF/A conformance and signing compose: a
        PDF/A-2b document can be signed. Encryption and signing cannot be
        combined - the library rejects the combination at save time, and this
        cmdlet (and Protect-VellumPdfDocument) fail fast with a clear error
        instead.

        Calling Set-VellumPdfSignature again before saving replaces the staged
        signature settings, consistent with Set-* semantics.

        CERTIFICATE: any [X509Certificate2] with a private key works - from
        Get-PfxCertificate, the cert: drive (Cert:\CurrentUser\My\<thumbprint>),
        or X509CertificateLoader/X509Certificate2 .NET APIs. Long-term validation
        (LTV: embedded OCSP/CRL) is not yet provided by the library and is out of
        scope here.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the signature settings are staged, enabling
        chaining.
    .PARAMETER Certificate
        The signing certificate. Must include a private key (HasPrivateKey).
        Typical sources: Get-PfxCertificate -FilePath ./signer.pfx, or
        Get-Item Cert:\CurrentUser\My\<thumbprint>.
    .PARAMETER Reason
        Optional reason for signing, recorded in the signature dictionary
        (/Reason) and shown by PDF viewers (e.g. 'Approved', 'I am the author').
    .PARAMETER Location
        Optional physical or logical location of signing, recorded as /Location.
    .PARAMETER ContactInfo
        Optional contact information for the signer (e.g. an email address),
        recorded as /ContactInfo.
    .PARAMETER SignerName
        Optional display name of the signer, recorded as /Name. When omitted,
        viewers typically fall back to the certificate subject.
    .PARAMETER SigningTime
        Optional claimed signing time recorded in the signature. When omitted the
        library uses the current time at save. A -TimestampUrl timestamp attests
        the time independently of this value.
    .PARAMETER TimestampUrl
        Optional RFC-3161 Time-Stamping Authority (TSA) URL. When supplied, the
        signature is timestamped over HTTP at save time, producing a PAdES B-T
        signature whose signing time a verifier can trust without relying on the
        signer's clock. Must be an http or https URL. The TSA is contacted during
        Save-VellumPdfDocument, so saving requires network access to the TSA.
    .PARAMETER TimestampTimeout
        Optional timeout for the TSA HTTP request, as a TimeSpan. When omitted the
        underlying HttpClient default applies. Only meaningful with -TimestampUrl.
    .PARAMETER TimestampRequestCertificate
        Whether to ask the TSA to embed its signing certificate in the timestamp
        token. Defaults to $true, which is what most verifiers need to validate
        the timestamp offline. Set to $false only for a TSA that rejects the
        request. Only meaningful with -TimestampUrl.
    .EXAMPLE
        $cert = Get-PfxCertificate -FilePath ./signer.pfx
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Signed content.' |
            Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' |
            Save-VellumPdfDocument -Path ./signed.pdf
    .EXAMPLE
        # Sign a PDF/A-2b archival document with a certificate from the store
        $cert = Get-Item Cert:\CurrentUser\My\1234567890ABCDEF1234567890ABCDEF12345678
        New-VellumPdfDocument -Conformance PdfA2b |
            Set-VellumPdfDocumentInfo -Title 'Contract' -Author 'Acme' |
            Add-VellumPdfParagraph -Text 'Terms.' -FontHandle $font |
            Set-VellumPdfSignature -Certificate $cert -Location 'Amsterdam' `
                -ContactInfo 'legal@acme.example' |
            Save-VellumPdfDocument -Path ./contract.pdf
    .EXAMPLE
        # PAdES B-T: add an RFC-3161 timestamp from a TSA (needs network at save)
        $cert = Get-PfxCertificate -FilePath ./signer.pfx
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Timestamped content.' |
            Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' `
                -TimestampUrl 'http://timestamp.digicert.com' |
            Save-VellumPdfDocument -Path ./signed-bt.pdf
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [string]$Reason,

        [string]$Location,

        [string]$ContactInfo,

        [string]$SignerName,

        [System.Nullable[System.DateTimeOffset]]$SigningTime,

        [uri]$TimestampUrl,

        [System.Nullable[timespan]]$TimestampTimeout,

        [bool]$TimestampRequestCertificate = $true
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Set-VellumPdfSignature'

        # The library rejects Encrypt() + Sign() at save time; fail fast here
        # with the same constraint so the error points at the right cmdlet.
        if ($Document.PSObject.Properties['PSVellumProtected']) {
            throw ('Set-VellumPdfSignature: encryption and digital signatures cannot be combined. ' +
                'Remove the Protect-VellumPdfDocument call to sign this document.')
        }

        if (-not $Certificate.HasPrivateKey) {
            throw ('Set-VellumPdfSignature: the certificate does not include a private key. ' +
                'Signing requires the private key; load the certificate from a PFX ' +
                '(Get-PfxCertificate) or a store entry that has the key.')
        }

        $settings = [VellumPdf.Signing.PdfSignatureSettings]::new()
        $settings.Certificate = $Certificate
        if ($PSBoundParameters.ContainsKey('Reason'))      { $settings.Reason      = $Reason }
        if ($PSBoundParameters.ContainsKey('Location'))    { $settings.Location    = $Location }
        if ($PSBoundParameters.ContainsKey('ContactInfo')) { $settings.ContactInfo = $ContactInfo }
        if ($PSBoundParameters.ContainsKey('SignerName'))  { $settings.SignerName  = $SignerName }
        if ($PSBoundParameters.ContainsKey('SigningTime')) { $settings.SigningTime = $SigningTime }

        # Validate the timestamp parameters BEFORE mutating any document state
        # below, so a bad -TimestampUrl on a re-stage leaves the previously
        # staged signature (and its HttpClient) intact.
        if ($PSBoundParameters.ContainsKey('TimestampUrl')) {
            if (-not $TimestampUrl.IsAbsoluteUri -or $TimestampUrl.Scheme -notin @('http', 'https')) {
                throw ("Set-VellumPdfSignature: -TimestampUrl must be an absolute http or https URL; " +
                    "got '$TimestampUrl'.")
            }
        }
        elseif ($PSBoundParameters.ContainsKey('TimestampTimeout') -or
                $PSBoundParameters.ContainsKey('TimestampRequestCertificate')) {
            throw ('Set-VellumPdfSignature: -TimestampTimeout and ' +
                '-TimestampRequestCertificate require -TimestampUrl.')
        }

        # Dispose any HttpClient stashed by a previous timestamp staging on this
        # document before replacing the staged signature, so re-staging does not
        # orphan a live HttpClient.
        $clientProp = $Document.PSObject.Properties['PSVellumTimestampHttpClient']
        if ($clientProp -and $clientProp.Value) {
            $clientProp.Value.Dispose()
            $clientProp.Value = $null
        }

        if ($PSBoundParameters.ContainsKey('TimestampUrl')) {
            # The HttpTimestampClient holds this HttpClient and is invoked later
            # by Save-VellumPdfDocument, so it must outlive this cmdlet. It is
            # stashed on the document and disposed when the document is (see
            # Save-VellumPdfDocument), or replaced by the next staging above.
            #
            # -TimestampUrl is user-supplied, so harden the client: a TSA does
            # not legitimately redirect, and following one would let a hostile
            # URL bounce the save-time request at an internal host (SSRF). Disable
            # auto-redirect and bound the request so a black-hole TSA cannot stall
            # Save indefinitely.
            $handler = [System.Net.Http.SocketsHttpHandler]::new()
            $handler.AllowAutoRedirect = $false
            $httpClient = [System.Net.Http.HttpClient]::new($handler, $true)
            if ($PSBoundParameters.ContainsKey('TimestampTimeout')) {
                $httpClient.Timeout = $TimestampTimeout
            }
            $settings.TimestampClient = [VellumPdf.Signing.HttpTimestampClient]::new(
                $TimestampUrl, $httpClient, $TimestampRequestCertificate, $TimestampTimeout)
            if ($clientProp) {
                $clientProp.Value = $httpClient
            }
            else {
                $Document.PSObject.Properties.Add(
                    [psnoteproperty]::new('PSVellumTimestampHttpClient', $httpClient))
            }
        }

        # Stage for Save-VellumPdfDocument; Set-* semantics allow replacing a
        # previously staged signature.
        $existing = $Document.PSObject.Properties['PSVellumSignature']
        if ($existing) {
            $existing.Value = $settings
        }
        else {
            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumSignature', $settings))
        }
        $Document
    }
}
