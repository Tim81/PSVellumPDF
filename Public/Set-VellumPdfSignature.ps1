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

        LEVELS: -Level selects the PAdES baseline level. B-B (default without a
        timestamp) and B-T (default with one) are described above. B-LT also embeds
        the certificate chain and the OCSP/CRL evidence for it in a /DSS dictionary
        so the signature stays verifiable after the certificates expire; B-LTA adds
        a final document timestamp so the evidence itself is protected. B-LT/B-LTA
        need a timestamp and fetch revocation data over the network at save time
        (from the OCSP/CRL addresses in the certificate chain), unless you pass
        your own -RevocationClient. They reserve 32 KB for the signature; raise
        -EstimatedSignatureSize if a long chain does not fit.

        CERTIFICATE: any [X509Certificate2] with a private key works - from
        Get-PfxCertificate, the cert: drive (Cert:\CurrentUser\My\<thumbprint>),
        or X509CertificateLoader/X509Certificate2 .NET APIs. When the key lives
        elsewhere, pass the public certificate and either -ExternalPrivateKey (a
        key object you can use in-process, such as a CNG or PKCS#11 key) or
        -ExternalSigner (a remote service such as a cloud KMS or HSM). An external
        signer is asynchronous: implement IExternalSigner in a compiled type
        (Add-Type) and do not combine it with Add-VellumPdfDrawing.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the signature settings are staged, enabling
        chaining.
    .PARAMETER Certificate
        The signing certificate. Must include a private key (HasPrivateKey) unless
        -ExternalPrivateKey or -ExternalSigner is given.
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
    .PARAMETER Level
        PAdES level: B-B, B-T, B-LT or B-LTA (see above). Default: B-T when a
        timestamp is configured, otherwise B-B. B-T and above require -TimestampUrl
        or -TimestampClient.
    .PARAMETER TimestampClient
        A custom RFC 3161 client (VellumPdf.Signing.ITimestampClient) instead of
        -TimestampUrl, for example one that talks to an internal TSA or a test double.
    .PARAMETER RevocationClient
        A custom OCSP/CRL source (VellumPdf.Signing.IRevocationClient) for B-LT/B-LTA.
        Default: the built-in HttpRevocationClient, which follows at most three redirects.
    .PARAMETER RevocationTimeout
        Timeout of the built-in revocation client. B-LT/B-LTA only.
    .PARAMETER SignaturePage
        The 1-based page that carries the invisible signature widget. Default 1. A
        page past the end of the document makes the save fail.
    .PARAMETER SubFilter
        Pades (default) writes ETSI.CAdES.detached, the PAdES profile. Pkcs7 writes
        the legacy adbe.pkcs7.detached, which makes no ETSI claim and keeps a CMS
        signing-time attribute that PAdES omits.
    .PARAMETER EstimatedSignatureSize
        Bytes reserved for the signature (1024..4194304). Default 8192, or 32768
        for B-LT/B-LTA.
    .PARAMETER ExternalPrivateKey
        A private key object (AsymmetricAlgorithm) that signs in-process while
        -Certificate carries only the public part.
    .PARAMETER ExternalSigner
        A VellumPdf.Signing.IExternalSigner that signs the digest remotely
        (cloud KMS, HSM). Runs asynchronously.
    .EXAMPLE
        # Long-term validation with a timestamp
        $doc | Set-VellumPdfSignature -Certificate $cert -TimestampUrl https://tsa.example.com -Level B-LT
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
    [OutputType([VellumPdf.Layout.Document], [VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Document,

        [Parameter(Mandatory, Position = 0)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [string]$Reason,

        [string]$Location,

        [string]$ContactInfo,

        [string]$SignerName,

        [System.Nullable[System.DateTimeOffset]]$SigningTime,

        [uri]$TimestampUrl,

        [System.Nullable[timespan]]$TimestampTimeout,

        [bool]$TimestampRequestCertificate = $true,

        # PAdES level. Default: B-T when a timestamp is configured, otherwise B-B.
        [ValidateSet('B-B', 'B-T', 'B-LT', 'B-LTA')]
        [string]$Level,

        # A custom RFC 3161 client (VellumPdf.Signing.ITimestampClient), instead of -TimestampUrl.
        [VellumPdf.Signing.ITimestampClient]$TimestampClient,

        # A custom OCSP/CRL source (VellumPdf.Signing.IRevocationClient) for B-LT/B-LTA.
        # Default: HttpRevocationClient.
        [VellumPdf.Signing.IRevocationClient]$RevocationClient,

        [System.Nullable[timespan]]$RevocationTimeout,

        # 1-based page that carries the (invisible) signature widget. Default 1.
        [ValidateRange(1, 100000)]
        [int]$SignaturePage,

        # Pades = ETSI.CAdES.detached (default); Pkcs7 = adbe.pkcs7.detached (legacy, no ETSI profile).
        [ValidateSet('Pades', 'Pkcs7')]
        [string]$SubFilter,

        # Size in bytes of the space reserved for the signature (engine default 8192;
        # raised automatically to 32768 for B-LT/B-LTA, which embed chains and revocation data).
        [ValidateRange(1024, 4194304)]
        [int]$EstimatedSignatureSize,

        # Sign with a key that is not in the certificate object (HSM, PKCS#11, CNG key),
        # in-process. -Certificate then only needs its public part.
        [System.Security.Cryptography.AsymmetricAlgorithm]$ExternalPrivateKey,

        # Sign through a remote service (VellumPdf.Signing.IExternalSigner), e.g. a cloud KMS.
        # Its SignAsync runs off the pipeline thread, so it must be a compiled type.
        [VellumPdf.Signing.IExternalSigner]$ExternalSigner
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Set-VellumPdfSignature'

            # The library rejects Encrypt() + Sign() at save time; fail fast here
            # with the same constraint so the error points at the right cmdlet.
            if ($Document.PSObject.Properties['PSVellumProtected']) {
                throw ('Set-VellumPdfSignature: encryption and digital signatures cannot be combined. ' +
                    'Remove the Protect-VellumPdfDocument call to sign this document.')
            }

            if ($ExternalPrivateKey -and $ExternalSigner) {
                throw 'Set-VellumPdfSignature: -ExternalPrivateKey and -ExternalSigner cannot be combined; choose one.'
            }
            if ($ExternalSigner -and $Document.PSObject.Properties['PSVellumHasDrawing']) {
                throw ('Set-VellumPdfSignature: -ExternalSigner signs asynchronously on other threads, which cannot run the ' +
                    'script blocks of Add-VellumPdfDrawing elements already in this document. Use -ExternalPrivateKey, or a certificate with its key.')
            }
            if (-not $Certificate.HasPrivateKey -and -not $ExternalPrivateKey -and -not $ExternalSigner) {
                throw ('Set-VellumPdfSignature: the certificate does not include a private key. ' +
                    'Signing requires the private key; load the certificate from a PFX ' +
                    '(Get-PfxCertificate) or a store entry that has the key, or pass ' +
                    '-ExternalPrivateKey / -ExternalSigner for a key held elsewhere.')
            }

            $settings = [VellumPdf.Signing.PdfSignatureSettings]::new()
            $settings.Certificate = $Certificate
            if ($PSBoundParameters.ContainsKey('Reason'))      { $settings.Reason      = $Reason }
            if ($PSBoundParameters.ContainsKey('Location'))    { $settings.Location    = $Location }
            if ($PSBoundParameters.ContainsKey('ContactInfo')) { $settings.ContactInfo = $ContactInfo }
            if ($PSBoundParameters.ContainsKey('SignerName'))  { $settings.SignerName  = $SignerName }
            if ($PSBoundParameters.ContainsKey('SigningTime')) { $settings.SigningTime = $SigningTime }
            if ($ExternalPrivateKey) { $settings.ExternalPrivateKey = $ExternalPrivateKey }
            if ($ExternalSigner)     { $settings.ExternalSigner = $ExternalSigner }
            if ($PSBoundParameters.ContainsKey('SignaturePage')) { $settings.SignaturePage = $SignaturePage - 1 }
            if ($PSBoundParameters.ContainsKey('SubFilter')) {
                $settings.SubFilter = if ($SubFilter -eq 'Pkcs7') {
                    [VellumPdf.Signing.PdfSignatureSettings]::SubFilterAdbePkcs7Detached
                } else {
                    [VellumPdf.Signing.PdfSignatureSettings]::SubFilterEtsiCAdESDetached
                }
            }

            # Validate the timestamp parameters BEFORE mutating any document state
            # below, so a bad -TimestampUrl on a re-stage leaves the previously
            # staged signature (and its HttpClient) intact.
            if ($TimestampClient -and $PSBoundParameters.ContainsKey('TimestampUrl')) {
                throw 'Set-VellumPdfSignature: -TimestampUrl and -TimestampClient cannot be combined; choose one.'
            }
            $hasTimestamp = $TimestampClient -or $PSBoundParameters.ContainsKey('TimestampUrl')
            $levelName = if ($Level) { $Level.ToUpperInvariant() } elseif ($hasTimestamp) { 'B-T' } else { 'B-B' }
            if ($levelName -ne 'B-B' -and -not $hasTimestamp) {
                throw "Set-VellumPdfSignature: -Level $levelName needs a signature timestamp; add -TimestampUrl (or -TimestampClient)."
            }
            if ($Level -eq 'B-B' -and $hasTimestamp) {
                throw 'Set-VellumPdfSignature: -Level B-B carries no timestamp; drop -TimestampUrl/-TimestampClient or use -Level B-T.'
            }
            if ($RevocationClient -or $PSBoundParameters.ContainsKey('RevocationTimeout')) {
                if ($levelName -notin 'B-LT', 'B-LTA') {
                    throw 'Set-VellumPdfSignature: -RevocationClient/-RevocationTimeout apply to -Level B-LT or B-LTA only.'
                }
            }
            if ($RevocationClient -and $PSBoundParameters.ContainsKey('RevocationTimeout')) {
                throw 'Set-VellumPdfSignature: -RevocationTimeout configures the default client; it cannot be combined with -RevocationClient.'
            }
            $settings.Level = [System.Enum]::Parse([VellumPdf.Signing.PadesLevel], ($levelName -replace '-', '_'), $true)
            if ($PSBoundParameters.ContainsKey('EstimatedSignatureSize')) {
                $settings.EstimatedSignatureSizeBytes = $EstimatedSignatureSize
            }
            elseif ($levelName -in 'B-LT', 'B-LTA') {
                # Long-term levels embed the chain and revocation evidence in the signature.
                $settings.EstimatedSignatureSizeBytes = 32768
            }
            if ($levelName -in 'B-LT', 'B-LTA' -and $RevocationClient) { $settings.RevocationClient = $RevocationClient }
            if ($TimestampClient) { $settings.TimestampClient = $TimestampClient }

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

            # Same for the revocation client's HttpClient from a previous staging.
            $revProp = $Document.PSObject.Properties['PSVellumRevocationHttpClient']
            if ($revProp -and $revProp.Value) {
                $revProp.Value.Dispose()
                $revProp.Value = $null
            }
            if ($levelName -in 'B-LT', 'B-LTA' -and -not $RevocationClient) {
                # The OCSP/CRL addresses come from the signing certificate chain. CRL hosts do
                # legitimately redirect (unlike a timestamp authority), so redirects stay on but
                # are capped, and the client is per signature rather than the engine's process-wide
                # shared one; Save-VellumPdfDocument disposes it with the document. Built here, after
                # all parameter validation, so a rejected call cannot leak it.
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $handler.AllowAutoRedirect = $true
                $handler.MaxAutomaticRedirections = 3
                $revocationHttpClient = [System.Net.Http.HttpClient]::new($handler, $true)
                $timeoutArg = if ($PSBoundParameters.ContainsKey('RevocationTimeout')) { $RevocationTimeout } else { $null }
                $settings.RevocationClient = [VellumPdf.Signing.HttpRevocationClient]::new($revocationHttpClient, $timeoutArg)
                if ($revProp) { $revProp.Value = $revocationHttpClient }
                else { $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumRevocationHttpClient', $revocationHttpClient)) }
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
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Set-VellumPdfSignature'))
        }
    }
}
