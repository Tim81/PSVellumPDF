---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfLineSeparator
---

# Add-VellumPdfLineSeparator

## SYNOPSIS

Adds a horizontal line separator to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfLineSeparator [-Document] <Document> [[-LineWidth] <double>] [[-Color] <Object>]
 [[-MarginTop] <double>] [[-MarginBottom] <double>] [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(LineSeparator).
Constructs a LineSeparator element with
an optional line width, RGB colour, and top/bottom margins, then adds it to
the document.

-Color accepts a three-element array of [double] values in the 0.0..1.0
range (R, G, B).

-MarginTop and -MarginBottom apply spacing above and below the separator
without affecting the left/right margins already set on the element.

The document flows through the pipeline for chaining with other
Add-VellumPdf* functions.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Above the line.' |
    Add-VellumPdfLineSeparator |
    Add-VellumPdfParagraph -Text 'Below the line.' |
    Save-VellumPdfDocument -Path ./report.pdf

### EXAMPLE 2

$doc | Add-VellumPdfLineSeparator -LineWidth 2.0 -Color 0.2,0.4,0.8 `
       -MarginTop 10 -MarginBottom 10

## PARAMETERS

### -Color

Line colour, given as an R,G,B triple in 0..1 (e.g.
0,0,0 for black), a
hex string ('#3366cc' or '#36c'), or a colour name.
When omitted the
library default colour is used.

```yaml
Type: System.Object
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

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the separator is added, enabling chaining.

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

### -LineWidth

Thickness of the horizontal rule in points, between 0.1 and 50.
When
omitted the VellumPdf library default line width is used.

```yaml
Type: System.Double
DefaultValue: 0
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

### -MarginBottom

Extra spacing in points below the separator element.
Does not affect
the left/right page margins.

```yaml
Type: System.Double
DefaultValue: 0
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

### -MarginTop

Extra spacing in points above the separator element.
Does not affect
the left/right page margins.

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


