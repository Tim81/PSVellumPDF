---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: New-VellumPdfDocument
---

# New-VellumPdfDocument

## SYNOPSIS

Creates a new VellumPdf layout document.

## SYNTAX

### __AllParameterSets

```
New-VellumPdfDocument [[-Conformance] <string>] [[-PageSize] <string>] [[-DefaultFont] <string>]
 [[-DefaultFontSize] <double>] [[-Language] <string>] [[-Margin] <double>] [[-MarginTop] <double>]
 [[-MarginRight] <double>] [[-MarginBottom] <double>] [[-MarginLeft] <double>] [-Tagged]
 [<CommonParameters>]
```

## DESCRIPTION

Returns a live VellumPdf.Layout.Document.
Pipe it through the Add-VellumPdf*
functions and finish with Save-VellumPdfDocument, which disposes it.

The document is IDisposable.
If you do not call Save-VellumPdfDocument,
dispose it yourself with $doc.Dispose().

Page margins can be set uniformly with -Margin, or per-side with
-MarginTop, -MarginRight, -MarginBottom, -MarginLeft.
 When any per-side
parameter is supplied, the uniform -Margin value (if given) is used as
the baseline for the unspecified sides; otherwise the library defaults
are kept for unspecified sides.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument -Conformance PdfA2b |
    Add-VellumPdfHeading -Text 'Report' |
    Add-VellumPdfParagraph -Text 'Body text.' |
    Save-VellumPdfDocument -Path ./report.pdf

### EXAMPLE 2

New-VellumPdfDocument -Margin 30

### EXAMPLE 3

New-VellumPdfDocument -Margin 30 -MarginLeft 50

## PARAMETERS

### -Conformance

{{ Fill Conformance Description }}

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -DefaultFont

{{ Fill DefaultFont Description }}

```yaml
Type: System.String
DefaultValue: Helvetica
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -DefaultFontSize

{{ Fill DefaultFontSize Description }}

```yaml
Type: System.Double
DefaultValue: 11
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Language

BCP 47 language tag written as the PDF /Lang entry (e.g.
'en-US').
Relevant for tagged PDF and PDF/A accessibility.
Requires VellumPdf 1.1+.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Margin

{{ Fill Margin Description }}

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginBottom

{{ Fill MarginBottom Description }}

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 8
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginLeft

{{ Fill MarginLeft Description }}

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 9
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginRight

{{ Fill MarginRight Description }}

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 7
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginTop

{{ Fill MarginTop Description }}

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PageSize

{{ Fill PageSize Description }}

```yaml
Type: System.String
DefaultValue: A4
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Tagged

{{ Fill Tagged Description }}

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

## OUTPUTS

### VellumPdf.Layout.Document

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

