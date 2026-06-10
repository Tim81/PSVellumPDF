---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
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
 [-FontHandle <EmbeddedFontHandle>] [-Color <double[]>] [-LinkUri <string>] [-Alignment <string>]
 [<CommonParameters>]
```

### Runs

```
Add-VellumPdfParagraph [-Run] <TextRun[]> -Document <Document> [-Alignment <string>]
 [<CommonParameters>]
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

--- Shared ---

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

{{ Fill Color Description }}

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

{{ Fill Document Description }}

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

{{ Fill Font Description }}

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

{{ Fill FontHandle Description }}

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

{{ Fill FontSize Description }}

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

{{ Fill LinkUri Description }}

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

### -Run

--- Runs parameter set ---

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

--- Text parameter set ---

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

{{ Fill in the Description }}

## OUTPUTS

### VellumPdf.Layout.Document (the same instance

{{ Fill in the Description }}

### VellumPdf.Layout.Document

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

