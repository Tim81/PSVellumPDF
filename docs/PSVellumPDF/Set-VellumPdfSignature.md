---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-11-2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfSignature
---

# Set-VellumPdfSignature

## SYNOPSIS

Stages a PAdES digital signature to be applied when the document is saved.

## SYNTAX

### __AllParameterSets

```
Set-VellumPdfSignature [-Certificate] <X509Certificate2> -Document <Document> [-Reason <string>]
 [-Location <string>] [-ContactInfo <string>] [-SignerName <string>] [-SigningTime <DateTimeOffset>]
 [<CommonParameters>]
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
PDF/A conformance and signing compose: a PDF/A-2b
document can be signed.
Encryption and signing cannot be combined - the
library rejects the combination at save time, and this cmdlet (and
Protect-VellumPdfDocument) fail fast with a clear error instead.

Calling Set-VellumPdfSignature again before saving replaces the staged
signature settings, consistent with Set-* semantics.

CERTIFICATE: any [X509Certificate2] with a private key works - from
Get-PfxCertificate, the cert: drive (Cert:\CurrentUser\My\<thumbprint>),
or X509CertificateLoader/X509Certificate2 .NET APIs.
Long-term validation
(LTV: embedded OCSP/CRL) is not yet provided by the library and is out of
scope here.

## EXAMPLES

### EXAMPLE 1

$cert = Get-PfxCertificate -FilePath ./signer.pfx
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Signed content.' |
    Set-VellumPdfSignature -Certificate $cert -Reason 'Approved' |
    Save-VellumPdfDocument -Path ./signed.pdf

### EXAMPLE 2

# Sign a PDF/A-2b archival document with a certificate from the store
$cert = Get-Item Cert:\CurrentUser\My\1234567890ABCDEF1234567890ABCDEF12345678
New-VellumPdfDocument -Conformance PdfA2b |
    Set-VellumPdfDocumentInfo -Title 'Contract' -Author 'Acme' |
    Add-VellumPdfParagraph -Text 'Terms.' -FontHandle $font |
    Set-VellumPdfSignature -Certificate $cert -Location 'Amsterdam' `
        -ContactInfo 'legal@acme.example' |
    Save-VellumPdfDocument -Path ./contract.pdf

## PARAMETERS

### -Certificate

The signing certificate.
Must include a private key (HasPrivateKey).
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
Type: VellumPdf.Layout.Document
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


