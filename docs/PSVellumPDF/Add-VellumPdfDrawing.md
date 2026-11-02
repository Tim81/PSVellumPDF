---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfDrawing
---

# Add-VellumPdfDrawing

## SYNOPSIS

Reserves a block in the page flow and draws into it with a script block.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfDrawing [-ScriptBlock] <scriptblock> -Document <Document> -Height <double>
 [-AltText <string>] [-Decorative] [-MarginTop <double>] [-MarginBottom <double>]
 [<CommonParameters>]
```

## DESCRIPTION

Gives you the full VellumPdf canvas (PdfCanvas) for free-form vector
drawing - shapes, gradients, transparency, CMYK colour, clipping, dashes,
arcs, text - inside the normal flow of a Layout document.
The script block
receives:

  $canvas  the VellumPdf.Canvas.PdfCanvas, already in PDF page space
  $box     a record with X, Y (bottom-left corner), Width and Height in
           points: the area reserved for the drawing
  $ctx     the VellumPdf.Layout.Core.DrawContext, for fonts:
           $font = $ctx.GetFont([VellumPdf.Fonts.Standard14]::Helvetica)
           $canvas.SetFont($font, 12) ; embedded fonts: $ctx.UseEmbeddedFont($handle)

Coordinates are PDF points with the origin at the page's bottom-left.
The
canvas state is saved before and restored after your script, so you cannot
leak colours or transforms into later content.

PowerShell cannot pass arrays to the canvas operators that take spans
(dash patterns, raw colour components, glyph ids); use the helpers in
[PSVellumPDF.Interop.CanvasHelpers] (SetLineDash, SetFillColor,
SetStrokeColor, ShowGlyphs) instead.

The script block runs while the document is saved, on the PowerShell
thread.
It therefore works with Save-VellumPdfDocument but not with an
asynchronous save or an external asynchronous signer.
In a tagged document
the drawing is a Figure with -AltText (or the text 'Drawing'); pass
-Decorative for purely decorative graphics.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfDrawing -Height 60 -AltText 'A red box with a blue border' -ScriptBlock {
    param($canvas, $box)
    $canvas.SetFillColorRgb(1, 0, 0).SetStrokeColorRgb(0, 0, 1).SetLineWidth(2)
    $canvas.Rectangle($box.X + 5, $box.Y + 5, 100, $box.Height - 10).FillAndStroke() | Out-Null
}

## PARAMETERS

### -AltText

Alternate text for a tagged document.

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

### -Decorative

Mark the drawing as an artifact (not read by screen readers).

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

### -Document

The live VellumPdf document flowing through the pipeline.

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

### -Height

Height in points of the block to reserve.
It spans the content width.

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

### -MarginBottom

Extra spacing in points below the block.

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

Extra spacing in points above the block.

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

### -ScriptBlock

Draws into the block: param($canvas, $box, $ctx).

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


