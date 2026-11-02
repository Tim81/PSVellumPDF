---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Get-VellumPdfText
---

# Get-VellumPdfText

## SYNOPSIS

Extracts the text of an existing PDF.

## SYNTAX

### Path (Default)

```
Get-VellumPdfText [-Path] <string[]> [-Page <int[]>] [-PerPage] [-Password <securestring>]
 [-AllowReconstruction] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

### LiteralPath

```
Get-VellumPdfText -LiteralPath <string[]> [-Page <int[]>] [-PerPage] [-Password <securestring>]
 [-AllowReconstruction] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

### Bytes

```
Get-VellumPdfText -Bytes <byte[]> [-Page <int[]>] [-PerPage] [-Password <securestring>]
 [-AllowReconstruction] [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>]
 [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>] [<CommonParameters>]
```

## DESCRIPTION

EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

Returns the text of the whole document as one string, or of the pages given
with -Page.
Limits of the current reader: only simple (single-byte) fonts
are decoded, so text set in composite/CID fonts such as many embedded
TrueType subsets is not extracted; no spaces are inserted between text
runs that the PDF positions apart; there is no OCR for scanned pages.
Diagnostics about text it could not decode are written as warnings.

## EXAMPLES

### EXAMPLE 1

Get-VellumPdfText ./report.pdf -Page 1

### EXAMPLE 2

Get-VellumPdfText ./report.pdf -PerPage | Where-Object Text -match 'invoice'

## PARAMETERS

### -AllowReconstruction

Try to recover a damaged file.

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

### -LiteralPath

The PDF file(s), taken literally.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
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

### -Page

1-based page numbers to extract.
Default: all pages.

```yaml
Type: System.Int32[]
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

### -Password

Password for an encrypted PDF (a SecureString).

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
Piped strings bind here; piped FileInfo objects (Get-ChildItem) bind to -LiteralPath through their PSPath, so names containing [ ] work.

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
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PerPage

Return one object per page (Page, Text) instead of a single string.

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

### System.String


### PSVellumPDF.PdfPageText


## NOTES

## RELATED LINKS


