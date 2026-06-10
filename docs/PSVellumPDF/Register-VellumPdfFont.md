---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: Register-VellumPdfFont
---

# Register-VellumPdfFont

## SYNOPSIS

Registers a TrueType font file with a VellumPdf document for embedding.

## SYNTAX

### __AllParameterSets

```
Register-VellumPdfFont [-Path] <string> -Document <Document> [<CommonParameters>]
```

## DESCRIPTION

Loads a TrueType (.ttf) font file into the document and returns an
EmbeddedFontHandle.
Pass the returned handle to the -FontHandle parameter
of Add-VellumPdfHeading or Add-VellumPdfParagraph to use the embedded font
instead of a Standard14 base-14 font.

NOTE: This cmdlet returns the EmbeddedFontHandle, NOT the document.
TrueType font embedding is required for Unicode text and PDF/A conformance;
the Standard14 base-14 fonts cannot be embedded.

## EXAMPLES

### EXAMPLE 1

$doc = New-VellumPdfDocument -Conformance PdfA2b
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfHeading -Text 'Unicode Heading' -FontHandle $handle |
       Add-VellumPdfParagraph -Text 'Body with embedded font.' -FontHandle $handle |
       Save-VellumPdfDocument -Path ./output.pdf

## PARAMETERS

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

### -Path

{{ Fill Path Description }}

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

{{ Fill in the Description }}

## OUTPUTS

### VellumPdf.Fonts.EmbeddedFontHandle

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

