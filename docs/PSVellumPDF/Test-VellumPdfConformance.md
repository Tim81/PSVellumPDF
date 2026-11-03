---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Test-VellumPdfConformance
---

# Test-VellumPdfConformance

## SYNOPSIS

Validates a PDF against PDF/A-2 (b/u/a) or PDF/UA-1, in-process.

## SYNTAX

### Path (Default)

```
Test-VellumPdfConformance [-Path] <string[]> [-Profile <string[]>] [-Password <securestring>]
 [-Quiet] [<CommonParameters>]
```

### LiteralPath

```
Test-VellumPdfConformance -LiteralPath <string[]> [-Profile <string[]>] [-Password <securestring>]
 [-Quiet] [<CommonParameters>]
```

### Bytes

```
Test-VellumPdfConformance -Bytes <byte[]> [-Profile <string[]>] [-Password <securestring>] [-Quiet]
 [<CommonParameters>]
```

## DESCRIPTION

Runs VellumPdf's built-in preflight (VellumPdf.Conformance) on an existing
PDF file or byte array - it does not need veraPDF or any external tool and
works on any PDF, not just ones this module wrote.
It returns one result
object per profile with the verdict and every finding (rule id, ISO clause,
severity, message, object).

Without -Profile the PDF's own claim is read (its XMP PDF/A and PDF/UA
identification) and every claimed profile is validated.
A PDF that claims
nothing needs an explicit -Profile.

The preflight covers the checks that can be decided in-process; it is a
fast regression gate, not a replacement for a certified validator when a
formal compliance statement is required.
Known gap: it does not examine
fonts that are used only by form fields or other annotation appearances.

Several files can be given (or piped); they are opened one at a time.
A failure for
one file (not found, unreadable, malformed, wrong password, ...) is a non-terminating
error with that file as TargetObject and the next file is still processed; use
-ErrorAction Stop to stop at the first one.
Invalid parameters terminate.
With -Quiet a file that could
not be checked makes the result $false.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument -Conformance PdfA2b | Add-VellumPdfParagraph -Text 'x' |
    Save-VellumPdfDocument -Path ./a.pdf | Test-VellumPdfConformance

### EXAMPLE 2

Test-VellumPdfConformance ./report.pdf -Profile PdfUA1 |
    ForEach-Object Assertions | Where-Object Severity -eq Error

## PARAMETERS

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

### -LiteralPath

The PDF file(s), taken literally (no wildcards).
Aliases PSPath and FullName, so objects with either
property (FileInfo, Select-Object FullName) bind by name.

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

### -Password

Password of an encrypted PDF (a SecureString).
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
the file returned by Save-VellumPdfDocument (a FileInfo) binds to -LiteralPath, so it can be piped
straight in and names containing [ ] work.

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

### -Profile

PdfA2b, PdfA2u, PdfA2a or PdfUA1.
Default: the profiles the PDF claims.

```yaml
Type: System.String[]
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

### -Quiet

Return only [bool]: $true when every validated profile passes.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]


## OUTPUTS

### PSVellumPDF.PreflightResult (Path


### PSVellumPDF.PreflightResult


### System.Boolean


## NOTES

## RELATED LINKS


