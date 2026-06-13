---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfHeader
---

# Set-VellumPdfHeader

## SYNOPSIS

Sets a running header band on a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Set-VellumPdfHeader [-Document] <Document> [-Template] <string> [[-Font] <string>]
 [[-FontSize] <double>] [[-Alignment] <string>] [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.SetHeader(template, style, alignment).
The header band
appears at the top of every page.
The document flows through the pipeline
for chaining.

Template tokens:
  {page}  - replaced with the current page number (e.g.
2)
  {pages} - replaced with the total page count   (e.g.
9)

Example template: 'Page {page} of {pages}'

## EXAMPLES

### EXAMPLE 1

$doc | Set-VellumPdfHeader -Template 'Page {page} of {pages}'

### EXAMPLE 2

$doc | Set-VellumPdfHeader -Template 'Confidential - Page {page} of {pages}' `
       -Font Helvetica -FontSize 9 -Alignment Right

## PARAMETERS

### -Alignment

Horizontal alignment of the header text.
Accepts Left, Center, Right,
or Justify.
Defaults to Center.

```yaml
Type: System.String
DefaultValue: Center
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

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the header is configured, enabling chaining.

```yaml
Type: VellumPdf.Layout.Document
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Font

A base-14 font name for the header text.
When omitted the document
default font is used.

```yaml
Type: System.String
DefaultValue: ''
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

### -FontSize

Font size in points for the header text, between 1 and 1000.
When
omitted the document default size is used.

```yaml
Type: System.Double
DefaultValue: 0
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

### -Template

The header text template.
Use {page} for the current page number and
{pages} for the total page count (e.g.
'Page {page} of {pages}').
Mandatory.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
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


