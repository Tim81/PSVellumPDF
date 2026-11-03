---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Get-VellumPdfInfo
---

# Get-VellumPdfInfo

## SYNOPSIS

Reads structural information from an existing PDF: pages, encryption, signatures, diagnostics.

## SYNTAX

### Path (Default)

```
Get-VellumPdfInfo [-Path] <string[]> [-Password <securestring>] [-AllowReconstruction]
 [-IncludeSignatureContents] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

### LiteralPath

```
Get-VellumPdfInfo -LiteralPath <string[]> [-Password <securestring>] [-AllowReconstruction]
 [-IncludeSignatureContents] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

### Bytes

```
Get-VellumPdfInfo -Bytes <byte[]> [-Password <securestring>] [-AllowReconstruction]
 [-IncludeSignatureContents] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

## DESCRIPTION

EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package:
its API and reach may change between releases.

Opens a PDF (any PDF, not only ones this module wrote) and reports its page
count and page boxes, whether and how it is encrypted, the digital
signatures it contains, which PDF/A and PDF/UA profiles it claims, and any
problems the reader noticed.
It never modifies the file.

Signatures are listed with what the reader exposes: the sub-filter, the
claimed signing time and the signed byte range.
Catalog reports whether the
document has a language, structure tree (tagged), XMP metadata, outline, form,
output intents and named destinations.
The reader does not verify
a signature, so this does not tell you whether one is valid.

Several files can be given (or piped); they are opened one at a time.
A failure for
one file (not found, unreadable, malformed, wrong password, ...) is a non-terminating
error with that file as TargetObject and the next file is still processed; use
-ErrorAction Stop to stop at the first one.
Invalid parameters terminate.

## EXAMPLES

### EXAMPLE 1

Get-VellumPdfInfo ./report.pdf | Select-Object PageCount, IsEncrypted, ClaimedProfiles

### EXAMPLE 2

(Get-VellumPdfInfo ./contract.pdf).Signatures

## PARAMETERS

### -AllowReconstruction

Try to recover a damaged file (missing or broken cross-reference table) by
scanning for objects.
The result then has WasReconstructed = $true.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### -Bytes

The PDF as a byte array.

```yaml
Type: System.Byte[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Bytes
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -IncludeSignatureContents

Add the raw CMS signature bytes (Contents) to every signature object, so that a script can verify
it, for example with [System.Security.Cryptography.Pkcs.SignedCms] over the ranges in ByteRange.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### -LiteralPath

The PDF file(s), taken literally.
Aliases PSPath and FullName, so objects with either property
(FileInfo, Select-Object FullName) bind by name.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
- FullName
ParameterSets:
- Name: LiteralPath
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MaxDecodedStreamBytes

Refuse to decode any stream larger than this many bytes (1 MiB to 512 MiB, the
default ceiling).
Lower it for untrusted files.

```yaml
Type: System.Int64
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

### -MaxDiagnostics

Stop collecting reader diagnostics after this many (1 to 1000).

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

### -MaxFormXObjectDepth

Deepest nesting of form XObjects followed while reading content (1 to 32).

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

### -Password

Password for an encrypted PDF (a SecureString).
An empty user password is
tried automatically.

```yaml
Type: System.Security.SecureString
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

### -Path

The PDF file(s).
Accepts wildcards.
Piped strings bind here, and so do piped objects with a Path property;
piped FileInfo objects (Get-ChildItem) bind to -LiteralPath through their PSPath, so names containing [ ] work.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ReconstructionBudgetMultiplier

How many times the file size reconstruction may scan (1 to 8); used with
-AllowReconstruction.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]


## OUTPUTS

### PSVellumPDF.PdfInfo


## NOTES

## RELATED LINKS


