---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: New-VellumPdfTextRun
---

# New-VellumPdfTextRun

## SYNOPSIS

Creates a styled text run for use in a mixed-style paragraph.

## SYNTAX

### __AllParameterSets

```
New-VellumPdfTextRun [-Text] <string> [-Font <string>] [-FontSize <double>]
 [-FontHandle <EmbeddedFontHandle>] [-Color <double[]>] [-LinkUri <string>] [<CommonParameters>]
```

## DESCRIPTION

Returns a VellumPdf.Layout.Elements.TextRun that can be passed to
Add-VellumPdfParagraph via its -Run parameter.
 Multiple runs compose
into a single paragraph, each with its own font, size, colour, or
hyperlink.

Every run carries at least an empty TextStyle so that the VellumPdf
renderer can fall back to the document's default font.
 When no styling
parameters are supplied the run inherits the document default.

-Color accepts three doubles (R, G, B) in the 0.0..1.0 range.
-LinkUri makes the run a clickable external hyperlink in the PDF.

## EXAMPLES

### EXAMPLE 1

$run1 = New-VellumPdfTextRun -Text 'Normal text '
$run2 = New-VellumPdfTextRun -Text 'Red text ' -Color 1,0,0
$run3 = New-VellumPdfTextRun -Text 'Click me' -LinkUri 'https://example.com'
$doc | Add-VellumPdfParagraph -Run $run1, $run2, $run3

## PARAMETERS

### -Color

{{ Fill Color Description }}

```yaml
Type: System.Double[]
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

### -Font

{{ Fill Font Description }}

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

### -FontHandle

{{ Fill FontHandle Description }}

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
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

### -FontSize

{{ Fill FontSize Description }}

```yaml
Type: System.Double
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

### -LinkUri

{{ Fill LinkUri Description }}

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

### -Text

{{ Fill Text Description }}

```yaml
Type: System.String
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### VellumPdf.Layout.Elements.TextRun

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

