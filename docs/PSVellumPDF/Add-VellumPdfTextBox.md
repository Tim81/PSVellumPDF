---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfTextBox
---

# Add-VellumPdfTextBox

## SYNOPSIS

Places wrapped, optionally justified text in a column on a page of a page-based document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfTextBox [-Text] <string> -Document <PdfDocument> -X <double> -Y <double>
 -Width <double> [-Page <int>] [-FontSize <double>] [-Font <string>]
 [-FontHandle <EmbeddedFontHandle>] [-Color <Object>] [-Align <string>] [-Leading <double>]
 [-MaxHeight <double>] [-Role <string>] [-Language <string>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

Breaks -Text into lines that fit -Width (measured with the real font metrics) and
draws them one under the other.
A line break in -Text (`n) starts a new paragraph, a
blank line leaves an empty line, and a word wider than the column is broken at
character boundaries.
-X is the left edge and -Y the top of the box in points from the
page's bottom-left; the first baseline sits one -FontSize below -Y and the lines follow
at -Leading (default 1.2 times the font size).

-Align Justify stretches every line except the last line of a paragraph to the full
width by widening the gaps between words.
A justified line is drawn word by word, each
word followed by an invisible space, so extracted text keeps its spaces.

With -MaxHeight the box stops after the lines that fit and warns about the rest.
Use
-PassThru to get the number of lines and the height used (to place the next box); the
object also carries the document.

In a tagged page document the whole box is one structure element (-Role, default P).
Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
Register-VellumPdfFont) for Unicode text.
In a PDF/A document base-14 text is embedded
automatically with a metric-compatible Liberation font.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfTextBox $text -X 72 -Y 700 -Width 220 -Align Justify

### EXAMPLE 2

$box = $doc | Add-VellumPdfTextBox $intro -X 72 -Y 700 -Width 300 -PassThru
$box.Document | Add-VellumPdfTextBox $more -X 72 -Y ($box.Bottom - 12) -Width 300

## PARAMETERS

### -Align

Left (default), Center, Right or Justify.

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

Text colour: RGB triple in 0..1, hex or name.
Default black.

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

### -Language

BCP 47 language tag of this text, written on its structure element (tagged documents).

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

### -Leading

Distance between baselines in points.
Default 1.2 times -FontSize.

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

### -MaxHeight

Maximum height of the box in points; lines beyond it are dropped with a warning.

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

### -Page

The 1-based page number.
Default 1.

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

### -PassThru

Return an object with Document, LineCount, Height and Bottom (the y of the box's lower
edge) instead of the document.

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

### -Role

In a tagged document: the structure role of the box - P (default), H1..H6, Span or Caption.

```yaml
Type: System.String
DefaultValue: P
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

The text to wrap.

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

### -Width

Column width in points.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -X

Left edge of the column in points.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Y

Top of the box in points from the bottom of the page.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance


### VellumPdf.Document.PdfDocument


### System.Management.Automation.PSObject


## NOTES

## RELATED LINKS


