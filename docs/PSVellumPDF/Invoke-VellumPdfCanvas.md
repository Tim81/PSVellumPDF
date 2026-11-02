---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Invoke-VellumPdfCanvas
---

# Invoke-VellumPdfCanvas

## SYNOPSIS

Draws on a page of a page-based document with a script block that receives the canvas.

## SYNTAX

### __AllParameterSets

```
Invoke-VellumPdfCanvas [-ScriptBlock] <scriptblock> -Document <PdfDocument> [-Page <int>]
 [-NoMarkedContent] [<CommonParameters>]
```

## DESCRIPTION

Gives full access to the VellumPdf PdfCanvas of one page - paths, colours
(RGB, grey, CMYK), transparency, gradients, clipping, dashes, text, images -
for anything the Add-VellumPdfShape/Text/...
cmdlets do not cover.
The script
block receives:

  $canvas    the VellumPdf.Canvas.PdfCanvas of the page
  $page      the VellumPdf.Document.PdfPage
  $document  the VellumPdf.Document.PdfDocument

All drawing on a page shares one canvas, so calls accumulate in order.
The
graphics state is saved before and restored after your script.
Operators that
take spans (dash patterns, raw colour components, glyph ids) cannot be called
from PowerShell directly; use [PSVellumPDF.Interop.CanvasHelpers].

In a tagged page document the drawing is wrapped in an artifact (decorative
graphics) unless you pass -NoMarkedContent and mark the content yourself.

## EXAMPLES

### EXAMPLE 1

$doc | Invoke-VellumPdfCanvas -Page 1 -ScriptBlock {
    param($canvas)
    $canvas.SetFillAlpha(0.4).SetFillColorRgb(0, 0, 1).Rectangle(100, 100, 200, 120).Fill() | Out-Null
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

### -NoMarkedContent

Do not wrap the drawing as an artifact in a tagged document.

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

### -ScriptBlock

The drawing code: param($canvas, $page, $document).

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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance


### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


