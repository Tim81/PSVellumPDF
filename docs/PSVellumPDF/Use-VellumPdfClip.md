---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Use-VellumPdfClip
---

# Use-VellumPdfClip

## SYNOPSIS

Runs a script block whose page drawing is clipped to a region.

## SYNTAX

### Box (Default)

```
Use-VellumPdfClip [-ScriptBlock] <scriptblock> -Document <PdfDocument> -X <double> -Y <double>
 -Width <double> -Height <double> [-Ellipse] [-Page <int>] [-FillRule <string>] [<CommonParameters>]
```

### Data

```
Use-VellumPdfClip [-ScriptBlock] <scriptblock> -Document <PdfDocument> -Data <string> [-Page <int>]
 [-FillRule <string>] [<CommonParameters>]
```

### Point

```
Use-VellumPdfClip [-ScriptBlock] <scriptblock> -Document <PdfDocument> -Point <Object[]>
 [-Page <int>] [-FillRule <string>] [<CommonParameters>]
```

## DESCRIPTION

Everything drawn on the page by the script block (Add-VellumPdfShape, -Path,
-Text, -Gradient, -PageImage, Invoke-VellumPdfCanvas ...) is visible only inside the
clip region; the clip is lifted again when the block ends, even if it throws.
Clip
scopes can be nested, which intersects the regions.

Give the region as -Data/-Point (see Add-VellumPdfPath), as a rectangle with
-X/-Y/-Width/-Height, or as an ellipse with -Ellipse.
The default -FillRule NonZero
or EvenOdd decides what is inside when sub-paths overlap.

Links and form fields (Add-VellumPdfLink, Add-VellumPdfFormField) are annotations in page coordinates
and are not affected by the clip.

The block runs in the caller's scope with the document as $_.
Its own output is
discarded; the cmdlet writes the document to the pipeline, so the call chains.

## EXAMPLES

### EXAMPLE 1

$doc | Use-VellumPdfClip -X 72 -Y 500 -Width 200 -Height 100 -Ellipse -ScriptBlock {
    $_ | Add-VellumPdfGradient -Direction LeftToRight -X 72 -Y 500 -Width 200 -Height 100 -StartColor red -EndColor blue
}

## PARAMETERS

### -Data

Path data for the region, e.g.
'M 100 100 L 300 100 L 200 250 Z'.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: Named
  IsRequired: true
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

### -Ellipse

Make the box an ellipse instead of a rectangle.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Box
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -FillRule

NonZero (default) or EvenOdd.

```yaml
Type: System.String
DefaultValue: NonZero
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

### -Height

Rectangle/ellipse height.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Box
  Position: Named
  IsRequired: true
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

### -Point

Polygon vertices as x,y pairs.

```yaml
Type: System.Object[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Point
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ScriptBlock

The drawing to clip.

```yaml
Type: System.Management.Automation.ScriptBlock
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

Rectangle/ellipse width.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Box
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

Rectangle/ellipse left edge.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Box
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

Rectangle/ellipse bottom edge.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Box
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


## NOTES

## RELATED LINKS


