---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
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
 [-FontHandle <EmbeddedFontHandle>] [-Color <double[]>] [-LinkUri <string>] [-Leading <double>]
 [<CommonParameters>]
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
-Leading sets the extra vertical spacing between lines for this run, in
points.
When omitted the document-level leading is used.

## EXAMPLES

### EXAMPLE 1

$run1 = New-VellumPdfTextRun -Text 'Normal text '
$run2 = New-VellumPdfTextRun -Text 'Red text ' -Color 1,0,0
$run3 = New-VellumPdfTextRun -Text 'Click me' -LinkUri 'https://example.com'
$doc | Add-VellumPdfParagraph -Run $run1, $run2, $run3

## PARAMETERS

### -Color

Text colour as three doubles representing Red, Green, and Blue channels,
each in the 0.0..1.0 range (e.g.
1,0,0 for pure red).
Exactly three
values must be supplied.

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

A base-14 font name applied to this run only.
When omitted the run
inherits the document default font.
Mutually exclusive with -FontHandle.

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

An EmbeddedFontHandle returned by Register-VellumPdfFont for the same
document.
When supplied, the run uses the embedded TrueType font instead
of a base-14 font, and the base-14 encoding warning is suppressed.
Handles are document-scoped; passing a handle from a different document
is rejected by the content cmdlet.

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

Font size in points for this run, between 1 and 1000.
When omitted the
run inherits the document default size.

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

### -Leading

Extra vertical line spacing in points added below each line of this run.
When omitted the document-level leading applies.

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

Makes this run a clickable external hyperlink in the rendered PDF.
javascript, vbscript, data, and file URI schemes are rejected; a
whitespace-only value is treated as no link.

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

The string content of this text run.
Mandatory and positional (position 0).

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


## NOTES

## RELATED LINKS


