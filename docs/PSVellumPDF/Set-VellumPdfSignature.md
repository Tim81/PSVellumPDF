---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfSignature
---

# Set-VellumPdfSignature

## SYNOPSIS

Stages a PAdES digital signature to be applied when the document is saved.

## SYNTAX

### __AllParameterSets

```
Set-VellumPdfSignature [-Certificate] <X509Certificate2> -Document <Object> [-Reason <string>]
 [-Location <string>] [-ContactInfo <string>] [-SignerName <string>] [-SigningTime <DateTimeOffset>]
 [-TimestampUrl <uri>] [-TimestampTimeout <timespan>] [-TimestampRequestCertificate <bool>]
 [-Level <string>] [-TimestampClient <ITimestampClient>] [-RevocationClient <IRevocationClient>]
 [-RevocationTimeout <timespan>] [-SignaturePage <int>] [-SubFilter <string>]
 [-EstimatedSignatureSize <int>] [-ExternalPrivateKey <AsymmetricAlgorithm>]
 [-ExternalSigner <IExternalSigner>] [<CommonParameters>]
```

## DESCRIPTION

Builds a VellumPdf.Signing.PdfSignatureSettings from the supplied
certificate and metadata and stages it on the document.
The signature is
applied by Save-VellumPdfDocument, which signs the document while writing
the file (VellumPdf signs at serialization time via
SigningExtensions.Sign; a signature cannot be added to an already-written
document through this module).

The signature is a PAdES baseline signature (SubFilter
ETSI.CAdES.detached).
Supplying -TimestampUrl adds an RFC-3161 timestamp
from a Time-Stamping Authority, upgrading the signature from PAdES B-B to
PAdES B-T so the signing time is independently attested rather than
claimed by the signer's clock.
PDF/A conformance and signing compose: a
PDF/A-2b document can be signed.
Encryption and signing cannot be
combined - the library rejects the combination at save time, and this
cmdlet (and Protect-VellumPdfDocument) fail fast with a clear error
instead.

Calling Set-VellumPdfSignature again before saving replaces the staged
signature settings, consistent with Set-* semantics.

LEVELS: -Level selects the PAdES baseline level.
B-B (default without a
timestamp) and B-T (default with one) are described above.
B-LT also embeds
the certificate chain and the OCSP/CRL evidence for it in a /DSS dictionary
so the signature stays verifiable after the certificates expire; B-LTA adds
a final document timestamp so the evidence itself is protected.
B-LT/B-LTA
need a timestamp and fetch revocation data over the network at save time
(from the OCSP/CRL addresses in the certificate chain), unless you pass
your own -RevocationClient.
They reserve 32 KB for the signature; raise
-EstimatedSignatureSize if a long chain does not fit.

CERTIFICATE: any [X509Certificate2] with a private key works - from
Get-PfxCertificate, the cert: drive (Cert:\CurrentUser\My\<thumbprint>),
or X509CertificateLoader/X509Certificate2 .NET APIs.
When the key lives
elsewhere, pass the public certificate and either -ExternalPrivateKey (a
key object you can use in-process, such as a CNG or PKCS#11 key) or
-ExternalSigner (a remote service such as a cloud KMS or HSM).
An external
signer is asynchronous: implement IExternalSigner in a compiled type
(Add-Type) and do not combine it with Add-VellumPdfDrawing.

## EXAMPLES

### EXAMPLE 1

# Long-term validation with a timestamp
$doc | Set-VellumPdfSignature -Certificate $cert -TimestampUrl https://tsa.example.com -Level B-LT

### EXAMPLE 2

$cert = Get-PfxCertificate -FilePath ./signer.pfx
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Signed content.' |
    Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' |
    Save-VellumPdfDocument -Path ./signed.pdf

### EXAMPLE 3

# Sign a PDF/A-2b archival document with a certificate from the store
$cert = Get-Item Cert:\CurrentUser\My\1234567890ABCDEF1234567890ABCDEF12345678
New-VellumPdfDocument -Conformance PdfA2b |
    Set-VellumPdfDocumentInfo -Title 'Contract' -Author 'Acme' |
    Add-VellumPdfParagraph -Text 'Terms.' -FontHandle $font |
    Set-VellumPdfSignature -Certificate $cert -Location 'Amsterdam' `
        -ContactInfo 'legal@acme.example' |
    Save-VellumPdfDocument -Path ./contract.pdf

### EXAMPLE 4

# PAdES B-T: add an RFC-3161 timestamp from a TSA (needs network at save)
$cert = Get-PfxCertificate -FilePath ./signer.pfx
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Timestamped content.' |
    Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' `
        -TimestampUrl 'http://timestamp.digicert.com' |
    Save-VellumPdfDocument -Path ./signed-bt.pdf

## PARAMETERS

### -Certificate

The signing certificate.
Must include a private key (HasPrivateKey) unless
-ExternalPrivateKey or -ExternalSigner is given.
Typical sources: Get-PfxCertificate -FilePath ./signer.pfx, or
Get-Item Cert:\CurrentUser\My\<thumbprint>.

```yaml
Type: System.Security.Cryptography.X509Certificates.X509Certificate2
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ContactInfo

Optional contact information for the signer (e.g.
an email address),
recorded as /ContactInfo.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the signature settings are staged, enabling
chaining.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EstimatedSignatureSize

Bytes reserved for the signature (1024..4194304).
Default 8192, or 32768
for B-LT/B-LTA.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ExternalPrivateKey

A private key object (AsymmetricAlgorithm) that signs in-process while
-Certificate carries only the public part.

```yaml
Type: System.Security.Cryptography.AsymmetricAlgorithm
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ExternalSigner

A VellumPdf.Signing.IExternalSigner that signs the digest remotely
(cloud KMS, HSM).
Runs asynchronously.

```yaml
Type: VellumPdf.Signing.IExternalSigner
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Level

PAdES level: B-B, B-T, B-LT or B-LTA (see above).
Default: B-T when a
timestamp is configured, otherwise B-B.
B-T and above require -TimestampUrl
or -TimestampClient.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Location

Optional physical or logical location of signing, recorded as /Location.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Reason

Optional reason for signing, recorded in the signature dictionary
(/Reason) and shown by PDF viewers (e.g.
'Approved', 'I am the author').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RevocationClient

A custom OCSP/CRL source (VellumPdf.Signing.IRevocationClient) for B-LT/B-LTA.
Default: the built-in HttpRevocationClient, which follows at most three redirects.

```yaml
Type: VellumPdf.Signing.IRevocationClient
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RevocationTimeout

Timeout of the built-in revocation client.
B-LT/B-LTA only.

```yaml
Type: System.Nullable`1[System.TimeSpan]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SignaturePage

The 1-based page that carries the invisible signature widget.
Default 1.
A
page past the end of the document makes the save fail.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SignerName

Optional display name of the signer, recorded as /Name.
When omitted,
viewers typically fall back to the certificate subject.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SigningTime

Optional claimed signing time recorded in the signature.
When omitted the
library uses the current time at save.
A -TimestampUrl timestamp attests
the time independently of this value.

```yaml
Type: System.Nullable`1[System.DateTimeOffset]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SubFilter

Pades (default) writes ETSI.CAdES.detached, the PAdES profile.
Pkcs7 writes
the legacy adbe.pkcs7.detached, which makes no ETSI claim and keeps a CMS
signing-time attribute that PAdES omits.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimestampClient

A custom RFC 3161 client (VellumPdf.Signing.ITimestampClient) instead of
-TimestampUrl, for example one that talks to an internal TSA or a test double.

```yaml
Type: VellumPdf.Signing.ITimestampClient
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimestampRequestCertificate

Whether to ask the TSA to embed its signing certificate in the timestamp
token.
Defaults to $true, which is what most verifiers need to validate
the timestamp offline.
Set to $false only for a TSA that rejects the
request.
Only meaningful with -TimestampUrl.

```yaml
Type: System.Boolean
DefaultValue: True
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimestampTimeout

Optional timeout for the TSA HTTP request, as a TimeSpan.
When omitted the
underlying HttpClient default applies.
Only meaningful with -TimestampUrl.

```yaml
Type: System.Nullable`1[System.TimeSpan]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TimestampUrl

Optional RFC-3161 Time-Stamping Authority (TSA) URL.
When supplied, the
signature is timestamped over HTTP at save time, producing a PAdES B-T
signature whose signing time a verifier can trust without relying on the
signer's clock.
Must be an http or https URL.
The TSA is contacted during
Save-VellumPdfDocument, so saving requires network access to the TSA.

```yaml
Type: System.Uri
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


