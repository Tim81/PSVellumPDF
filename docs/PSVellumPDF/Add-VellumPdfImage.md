---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfImage
---

# Add-VellumPdfImage

## SYNOPSIS

Embeds an image file into a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfImage [-Path] <string> -Document <Document> [-Width <double>] [-Height <double>]
 [-Alignment <string>] [-AltText <string>] [-MarginTop <double>] [-MarginBottom <double>]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(LayoutImage).
Reads the image from -Path, selects the
appropriate VellumPdf loader by file extension (JPEG, PNG, BMP, GIF, TIFF,
JBIG2, JPEG 2000), constructs a LayoutImage, and adds it to the document.

Supported extensions: .jpg/.jpeg, .png, .bmp, .gif, .tif/.tiff,
.jbig2/.jb2, and .jp2/.jpx/.j2k/.jpf (JPEG 2000).

Optional -Width and -Height (in points) constrain the rendered size; when
omitted the image renders at its natural size.
-Alignment positions the
image horizontally on the page.
-AltText supplies alternate text that aids
tagged PDF and PDF-A accessibility readers.

-MarginTop and -MarginBottom apply spacing above and below the image
without affecting the left/right margins already set on the element.

The document flows through the pipeline for chaining with other
Add-VellumPdf* functions.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument |
    Add-VellumPdfImage -Path ./logo.png |
    Save-VellumPdfDocument -Path ./report.pdf

### EXAMPLE 2

$doc | Add-VellumPdfImage -Path ./photo.jpg -Width 200 -Height 150 `
       -Alignment Center -AltText 'Company photo'

## PARAMETERS

### -Alignment

Horizontal alignment of the image on the page.
Accepts Left, Center,
Right, or Justify.
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

### -AltText

Alternate text description for the image.
Stored on the LayoutImage
element and included in tagged PDF structure for accessibility readers
and PDF/A compliance.

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

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the image is added, enabling chaining.

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

Rendered height of the image in points, between 1 and 100000.
When
omitted the image is rendered at its natural height.

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

### -MarginBottom

Extra spacing in points below the image element.
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

Extra spacing in points above the image element.
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

### -Path

File system path to the image file.
Supported extensions are .jpg,
.jpeg, .png, .bmp, .gif, .tif, .tiff, .jbig2, .jb2, .jp2, .jpx, .j2k,
and .jpf.
The path is resolved relative to the current PowerShell
provider location.
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

### -Width

Rendered width of the image in points, between 1 and 100000.
When
omitted the image is rendered at its natural width.

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

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


