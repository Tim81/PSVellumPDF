---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Use-VellumPdfTransform
---

# Use-VellumPdfTransform

## SYNOPSIS

Runs a script block whose page drawing is rotated, scaled and/or moved.

## SYNTAX

### __AllParameterSets

```
Use-VellumPdfTransform [-ScriptBlock] <scriptblock> -Document <PdfDocument> [-Page <int>]
 [-Rotate <double>] [-Scale <double[]>] [-OriginX <double>] [-OriginY <double>]
 [-TranslateX <double>] [-TranslateY <double>] [<CommonParameters>]
```

## DESCRIPTION

Everything drawn on the page by the script block (Add-VellumPdfShape, -Path, -Text, -TextBox,
-PageImage, -PageBarcode, -Gradient, Invoke-VellumPdfCanvas ...) is transformed; the
transformation ends with the block, even if it throws.
Scopes can be nested.

The transformation is applied in this order: scale about the origin, rotate about the origin,
then move.
The origin is -OriginX/-OriginY (default the page's bottom-left corner), so to
rotate a stamp about its own centre give that centre as the origin.
Rotation is in degrees,
counter-clockwise.

Coordinates inside the block are the ones you would have used without the transform; only
the result moves.
A block that draws on another page than -Page is not transformed there
(a warning says so).

Links and form fields (Add-VellumPdfLink, Add-VellumPdfFormField) are annotations placed in page
coordinates and are not transformed, nor clipped by Use-VellumPdfClip.

The block runs in the caller's scope with the document as $_.
Its own output is discarded;
the cmdlet writes the document to the pipeline, so the call chains.

## EXAMPLES

### EXAMPLE 1

# A diagonal "DRAFT" stamp, rotated 45 degrees about the page centre.
$doc | Use-VellumPdfTransform -Rotate 45 -OriginX 297 -OriginY 421 -ScriptBlock {
    $_ | Add-VellumPdfText 'DRAFT' -X 297 -Y 421 -FontSize 80 -Font HelveticaBold -Align Center -Color '#cccccc'
}

## PARAMETERS

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

### -OriginX

x of the point the scale and rotation are about, in points (default 0).

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

### -OriginY

y of the point the scale and rotation are about, in points (default 0).

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

### -Rotate

Rotation in degrees, counter-clockwise (negative is clockwise).

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

### -Scale

One factor for both directions, or two (horizontal, vertical).
Negative values mirror.
The size of
a factor is limited to 0.000001 ...
1,000,000.

```yaml
Type: System.Double[]
DefaultValue: '@(1.0)'
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

### -ScriptBlock

The drawing to transform.

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

### -TranslateX

Horizontal move applied last, in points.

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

### -TranslateY

Vertical move applied last, in points.

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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance


### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


