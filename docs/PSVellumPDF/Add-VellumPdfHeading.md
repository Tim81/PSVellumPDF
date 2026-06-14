---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-14-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfHeading
---

# Add-VellumPdfHeading

## SYNOPSIS

Adds a heading to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfHeading [-Text] <string> -Document <Document> [-Level <int>] [-Font <string>]
 [-FontSize <double>] [-Alignment <string>] [-BookmarkTitle <string>]
 [-FontHandle <EmbeddedFontHandle>] [-Color <Object>] [-Language <string>] [-MarginTop <double>]
 [-MarginBottom <double>] [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(Heading).
The document flows through the pipeline so
Add-VellumPdf* calls can be chained.
Headings with a BookmarkTitle (or any
heading in a tagged document) become PDF outline/bookmark entries.

-MarginTop and -MarginBottom apply spacing above and below the heading
without affecting the left/right margins already set on the element.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfHeading -Text 'Chapter 1' -Level 1 -FontSize 18

### EXAMPLE 2

# Coloured heading
$doc | Add-VellumPdfHeading -Text 'Warning' -Level 2 -Color '#cc0000'

### EXAMPLE 3

# Heading with BCP-47 language tag
$doc | Add-VellumPdfHeading -Text 'Introduction' -Level 1 -Language 'en-US'

## PARAMETERS

### -Alignment

Horizontal alignment of the heading text.
Accepts Left, Center, Right,
or Justify.
Defaults to Left.

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

### -BookmarkTitle

When supplied, adds a named PDF outline (bookmark) entry for this
heading.
In tagged documents all headings automatically produce outline
entries; this parameter overrides the bookmark label for non-tagged docs.

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

### -Color

Text colour for the heading, given as an R,G,B triple in 0..1
(e.g.
1,0,0 for red), a hex string ('#3366cc' or '#36c'), or a colour
name.
Works with both -Font and -FontHandle.

```yaml
Type: System.Object
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

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the heading is added, enabling chaining.

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

A base-14 font name for the heading.
Defaults to HelveticaBold.
Ignored
when -FontHandle is supplied.

```yaml
Type: System.String
DefaultValue: HelveticaBold
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

An EmbeddedFontHandle returned by Register-VellumPdfFont for this
document.
When supplied the heading uses the embedded TrueType font and
the base-14 encoding warning is suppressed.
Handles from a different
document are rejected.

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

Font size in points for the heading, between 1 and 1000.
Defaults to 16.

```yaml
Type: System.Double
DefaultValue: 16
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

### -Language

BCP-47 language tag (e.g.
'en-US', 'de-DE') applied to the heading
element.
Enables per-element language metadata in tagged and PDF/UA
documents.

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

### -Level

The heading level from 1 (top-level) to 6 (lowest).
Controls the PDF
outline depth and the H1-H6 structure tag in tagged documents.
Defaults
to 1.

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

### -MarginBottom

Extra spacing in points below the heading element.
Does not affect the
left/right page margins.

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

Extra spacing in points above the heading element.
Does not affect the
left/right page margins.

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

### -Text

The string content of the heading.
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

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


