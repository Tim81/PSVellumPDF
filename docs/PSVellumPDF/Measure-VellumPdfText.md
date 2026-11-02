---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Measure-VellumPdfText
---

# Measure-VellumPdfText

## SYNOPSIS

Measures the width of a line of text in a PDF font.

## SYNTAX

### __AllParameterSets

```
Measure-VellumPdfText [-Text] <string> [-FontSize <double>] [-Font <string>]
 [-FontHandle <EmbeddedFontHandle>] [-CharSpacing <double>] [-WordSpacing <double>]
 [-HorizontalScale <double>] [<CommonParameters>]
```

## DESCRIPTION

Returns how wide the text is in points when drawn in a base-14 font (-Font) or an embedded
TrueType font (-FontHandle from Register-VellumPdfFont), using the same metrics the drawing
cmdlets use for alignment and wrapping.
Use it to size a box, to centre something by hand or
to check that a label fits before placing it.
-CharSpacing, -WordSpacing and
-HorizontalScale are added the way Add-VellumPdfText applies them.

The result also lists characters the font cannot show: UnencodableCharacters for a base-14 font
(outside Windows-1252, drawn as a question mark) and MissingGlyphs for an embedded font (drawn
as an empty box).
The text must be a single line.

## EXAMPLES

### EXAMPLE 1

Measure-VellumPdfText 'Invoice 2026-001' -FontSize 18 -Font HelveticaBold | Select-Object -ExpandProperty Width

### EXAMPLE 2

$width = (Measure-VellumPdfText $label -FontSize 10).Width
$doc | Add-VellumPdfText $label -X (300 - $width / 2) -Y 700 -FontSize 10

## PARAMETERS

### -CharSpacing

Extra space after every character, in points.

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

### -Font

A base-14 font name (default Helvetica).

```yaml
Type: System.String
DefaultValue: Helvetica
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

An embedded TrueType font from Register-VellumPdfFont.
Overrides -Font.

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

Size in points (default 12).

```yaml
Type: System.Double
DefaultValue: 12
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

### -HorizontalScale

Horizontal scaling in percent (100 is normal).

```yaml
Type: System.Double
DefaultValue: 100
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

The text to measure.
A single line; accepts pipeline input.

```yaml
Type: System.String
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

### -WordSpacing

Extra space after every space character, in points.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String


## OUTPUTS

### PSVellumPDF.TextMeasurement with Text


### PSVellumPDF.TextMeasurement


## NOTES

## RELATED LINKS


