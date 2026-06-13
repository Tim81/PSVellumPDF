---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
PlatyPS schema version: 2024-05-01
title: Register-VellumPdfFont
---

# Register-VellumPdfFont

## SYNOPSIS

Registers a TrueType font file with a VellumPdf document for embedding.

## SYNTAX

### Path (Default)

```
Register-VellumPdfFont [-Path] <string> -Document <Document> [<CommonParameters>]
```

### Bytes

```
Register-VellumPdfFont -Document <Document> -FontBytes <byte[]> [<CommonParameters>]
```

## DESCRIPTION

Loads a TrueType (.ttf) font into the document and returns an
EmbeddedFontHandle.
Pass the returned handle to the -FontHandle parameter
of Add-VellumPdfHeading or Add-VellumPdfParagraph to use the embedded font
instead of a Standard14 base-14 font.

Use the 'Path' parameter set (default) to load the font from a file path.
Use the 'Bytes' parameter set to supply raw font bytes directly (e.g.
when
the font is already in memory or was read from a stream).

NOTE: This cmdlet returns the EmbeddedFontHandle, NOT the document.
TrueType font embedding is required for Unicode text and PDF/A conformance;
the Standard14 base-14 fonts cannot be embedded.

A handle is only valid for the document it was registered on.
Using it
with a different document would silently produce a PDF whose text cannot
render (the font resource is missing), so the content cmdlets reject
foreign handles with a clear error.

## EXAMPLES

### EXAMPLE 1

$doc = New-VellumPdfDocument -Conformance PdfA2b
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfHeading -Text 'Unicode Heading' -FontHandle $handle |
       Add-VellumPdfParagraph -Text 'Body with embedded font.' -FontHandle $handle |
       Save-VellumPdfDocument -Path ./output.pdf

### EXAMPLE 2

$bytes = [System.IO.File]::ReadAllBytes('./DejaVuSans.ttf')
$handle = Register-VellumPdfFont -Document $doc -FontBytes $bytes

## PARAMETERS

### -Document

The VellumPdf document to register the font on.
Accepts pipeline input.
The returned handle is only valid for this specific document instance.

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

### -FontBytes

Raw TrueType font data as a byte array.
Used in the 'Bytes' parameter
set when the font is already in memory (e.g.
read from a stream or
embedded resource).
Mutually exclusive with -Path.

```yaml
Type: System.Byte[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Bytes
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path

File system path to a TrueType (.ttf) font file.
Used in the default
'Path' parameter set.
The path is resolved relative to the current
PowerShell provider location before reading.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
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

### VellumPdf.Fonts.EmbeddedFontHandle


## NOTES

## RELATED LINKS


