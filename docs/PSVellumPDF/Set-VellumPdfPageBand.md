---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfPageBand
---

# Set-VellumPdfPageBand

## SYNOPSIS

Adds a repeated header or footer, such as page numbers, to every page of a page-based document.

## SYNTAX

### Set (Default)

```
Set-VellumPdfPageBand [-Position] <string> [-Template] <string> -Document <PdfDocument>
 [-Align <string>] [-FontSize <double>] [-Font <string>] [-FontHandle <EmbeddedFontHandle>]
 [-Color <Object>] [-Inset <double>] [-Offset <double>] [-StartNumber <int>] [-SkipFirstPage]
 [<CommonParameters>]
```

### Remove

```
Set-VellumPdfPageBand [-Position] <string> -Document <PdfDocument> -Remove [-Align <string>]
 [<CommonParameters>]
```

## DESCRIPTION

The page-document counterpart of Set-VellumPdfHeader / Set-VellumPdfFooter.
The band is
stamped on every page when the document is saved, so it also covers pages added after
this call and knows the final page count.

Template tokens:
  {page}   the page number (counted from -StartNumber)
  {pages}  the last page number

'Page {page} of {pages}' gives "Page 2 of 9".
A document can hold several bands:
a band is identified by its -Position and -Align, so a footer with left-aligned
'Confidential' and right-aligned 'Page {page} of {pages}' is two calls, and calling again
for the same position and alignment replaces the earlier band.

In a tagged document (PdfUA1, PdfA2a, -Tagged) the band is marked as an artifact, which
is what PDF/UA requires of running headers and footers.
In a PDF/A document base-14 text
is embedded automatically with a metric-compatible Liberation font.

Positions are measured from the page's unrotated edges; on a page with -Rotate the band
follows the unrotated page, and a warning is written when the document is saved.

## EXAMPLES

### EXAMPLE 1

$doc | Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Align Right

### EXAMPLE 2

$doc | Set-VellumPdfPageBand Header 'Quarterly report' -Align Left -Font HelveticaBold -SkipFirstPage

## PARAMETERS

### -Align

Left, Center (default) or Right.

```yaml
Type: System.String
DefaultValue: Center
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
- Name: Set
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
- Name: Set
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
- Name: Set
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

Size in points (default 9).

```yaml
Type: System.Double
DefaultValue: 9
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Inset

Distance of left/right aligned text from the page's side edges, in points (default 36).

```yaml
Type: System.Double
DefaultValue: 36
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Offset

Distance of the text baseline from the top (Header) or bottom (Footer) edge, in points
(default 30).

```yaml
Type: System.Double
DefaultValue: 30
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Position

Header (near the top edge) or Footer (near the bottom edge).

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

### -Remove

Remove the band with this -Position and -Align instead of setting one.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Remove
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipFirstPage

Leave the first page without this band (cover pages).
The numbering still counts it,
so the second page shows StartNumber + 1.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -StartNumber

The number {page} shows on the first page (default 1).

```yaml
Type: System.Int32
DefaultValue: 1
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Template

The band text with optional {page} and {pages} tokens.
A single line.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Set
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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance


### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


