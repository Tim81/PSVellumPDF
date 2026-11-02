---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfElement
---

# Add-VellumPdfElement

## SYNOPSIS

Adds a custom layout element (any VellumPdf IRenderer) to a document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfElement [-Document] <Document> [-Renderer] <IRenderer> [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(IRenderer): the extension point behind barcodes and
charts.
Use it with a renderer you compiled yourself (Add-Type) or got from
another VellumPdf package.
The renderer's Layout(LayoutContext) is called
during the save - possibly several times - to measure and split it across
pages, and Draw(DrawContext) to paint it, so exceptions from either surface
from Save-VellumPdfDocument.
An element may use at most 50,000 page
continuations.
Space left by a previous element's -MarginBottom is inserted
before the element as an invisible spacer.

Write the renderer in C# (Add-Type): PowerShell classes cannot run on the
thread-pool threads an asynchronous save uses.
For quick drawing from a
script block use Add-VellumPdfDrawing instead.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfElement -Renderer ([VellumPdf.Barcodes.BarcodeRenderer]::new($qr))

## PARAMETERS

### -Document

The live VellumPdf document flowing through the pipeline.

```yaml
Type: VellumPdf.Layout.Document
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Renderer

The renderer to add.

```yaml
Type: VellumPdf.Layout.Core.IRenderer
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
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

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


