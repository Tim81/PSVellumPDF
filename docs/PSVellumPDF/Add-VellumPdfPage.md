---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfPage
---

# Add-VellumPdfPage

## SYNOPSIS

Adds a page to a page-based document.

## SYNTAX

### Default (Default)

```
Add-VellumPdfPage -Document <PdfDocument> [-Rotate <int>] [-Count <int>] [-PassThru]
 [<CommonParameters>]
```

### Named

```
Add-VellumPdfPage -Document <PdfDocument> [-PageSize <string>] [-Rotate <int>] [-Count <int>]
 [-PassThru] [<CommonParameters>]
```

### Custom

```
Add-VellumPdfPage -Document <PdfDocument> -PageWidthMm <double> -PageHeightMm <double>
 [-Rotate <int>] [-Count <int>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

Appends one page (or -Count pages) of the document's default size, or of
-PageSize / -PageWidthMm x -PageHeightMm.
-Rotate turns the page for display
(the content is not re-flowed).
Pages are addressed by their 1-based number
in the other page cmdlets.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfPage -PageSize Letter -Rotate 90

## PARAMETERS

### -Count

Number of identical pages to add (default 1).

```yaml
Type: System.Int32
DefaultValue: 1
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

A document from New-VellumPdfPageDocument.

```yaml
Type: VellumPdf.Document.PdfDocument
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

### -PageHeightMm

Custom height in millimetres (1..5080).

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Custom
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PageSize

A named size for this page (A0-A6, Ledger, Legal, Letter).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Named
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PageWidthMm

Custom width in millimetres (1..5080), with -PageHeightMm.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Custom
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PassThru

Return the new PdfPage object instead of the document.

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

### -Rotate

Display rotation in degrees clockwise: 0, 90, 180 or 270.

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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance)


### VellumPdf.Document.PdfDocument


### VellumPdf.Document.PdfPage


## NOTES

## RELATED LINKS


