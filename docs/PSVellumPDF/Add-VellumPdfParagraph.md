---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-11-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfParagraph
---

# Add-VellumPdfParagraph

## SYNOPSIS

Adds a paragraph of text to a VellumPdf document.

## SYNTAX

### Text (Default)

```
Add-VellumPdfParagraph [-Text] <string> -Document <Document> [-Font <string>] [-FontSize <double>]
 [-FontHandle <EmbeddedFontHandle>] [-Color <double[]>] [-LinkUri <string>] [-Leading <double>]
 [-Alignment <string>] [-MarginTop <double>] [-MarginBottom <double>] [<CommonParameters>]
```

### Runs

```
Add-VellumPdfParagraph [-Run] <TextRun[]> -Document <Document> [-Alignment <string>]
 [-MarginTop <double>] [-MarginBottom <double>] [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(Paragraph).
When no -Font/-FontSize/-Alignment override
is supplied the document's default font (set by New-VellumPdfDocument) is
used.
The document flows through the pipeline for chaining.

Use the 'Text' parameter set for a single-style paragraph.
 Use the 'Runs'
parameter set with the output of New-VellumPdfTextRun to compose a
mixed-style paragraph (multiple fonts, colours, or hyperlinks in one
paragraph).

-Leading (Text set only) sets the extra vertical spacing between lines,
in points.

-MarginTop and -MarginBottom apply spacing above and below the paragraph
without affecting the left/right margins already set on the element.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfParagraph -Text 'The quick brown fox.' -Alignment Justify

### EXAMPLE 2

$doc | Add-VellumPdfParagraph -Text 'Red heading.' -Color 1,0,0

### EXAMPLE 3

$run1 = New-VellumPdfTextRun -Text 'Normal '
$run2 = New-VellumPdfTextRun -Text 'Bold' -Font HelveticaBold
$doc | Add-VellumPdfParagraph -Run $run1, $run2

## PARAMETERS

### -Alignment

Horizontal alignment of the paragraph text.
Accepts Left, Center, Right,
or Justify.
Defaults to Left.
Applies to both parameter sets.

```yaml
Type: System.String
DefaultValue: Left
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

### -Color

Text colour as three doubles representing Red, Green, and Blue channels,
each in the 0.0..1.0 range (e.g.
1,0,0 for pure red).
Exactly three
values must be supplied.
Valid only in the 'Text' parameter set.

```yaml
Type: System.Double[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the paragraph is added, enabling chaining.

```yaml
Type: VellumPdf.Layout.Document
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

### -Font

A base-14 font name for the paragraph text.
When omitted the document
default font is used.
Valid only in the 'Text' parameter set.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

An EmbeddedFontHandle returned by Register-VellumPdfFont for this
document.
When supplied the paragraph uses the embedded TrueType font and
the base-14 encoding warning is suppressed.
Handles from a different
document are rejected.
Valid only in the 'Text' parameter set.

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

Font size in points for the paragraph, between 1 and 1000.
When omitted
the document default size is used.
Valid only in the 'Text' parameter set.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

Extra vertical line spacing in points added below each line.
When omitted
the document-level leading applies.
Valid only in the 'Text' parameter set.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

Makes the entire paragraph a clickable external hyperlink.
javascript,
vbscript, data, and file URI schemes are rejected; a whitespace-only
value is treated as no link.
Valid only in the 'Text' parameter set.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginBottom

Extra spacing in points below the paragraph element.
Does not affect the
left/right page margins.
Applies to both parameter sets.

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

### -MarginTop

Extra spacing in points above the paragraph element.
Does not affect the
left/right page margins.
Applies to both parameter sets.

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

### -Run

An array of TextRun objects produced by New-VellumPdfTextRun that
compose a mixed-style paragraph.
Used in the 'Runs' parameter set.
Mandatory and positional (position 0).

```yaml
Type: VellumPdf.Layout.Elements.TextRun[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Runs
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Text

The string content of the paragraph.
Used in the 'Text' parameter set
for a single-style paragraph.
Mandatory and positional (position 0).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Text
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

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


