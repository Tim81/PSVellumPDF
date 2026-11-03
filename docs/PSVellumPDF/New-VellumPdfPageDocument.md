---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: New-VellumPdfPageDocument
---

# New-VellumPdfPageDocument

## SYNOPSIS

Creates a page-based PDF document for precise placement: drawing, forms, links, outlines.

## SYNTAX

### NamedPage (Default)

```
New-VellumPdfPageDocument [-Conformance <string>] [-Tagged] [-PageSize <string>]
 [-Language <string>] [-UseObjectStreams] [-Linearize] [-DocumentId <byte[]>]
 [-Timestamp <DateTimeOffset>] [-Culture <Object>] [-InputCulture <Object>] [<CommonParameters>]
```

### CustomPage

```
New-VellumPdfPageDocument -PageWidthMm <double> -PageHeightMm <double> [-Conformance <string>]
 [-Tagged] [-Language <string>] [-UseObjectStreams] [-Linearize] [-DocumentId <byte[]>]
 [-Timestamp <DateTimeOffset>] [-Culture <Object>] [-InputCulture <Object>] [<CommonParameters>]
```

## DESCRIPTION

New-VellumPdfDocument builds flowing documents (text wraps and paginates
for you).
This cmdlet creates the other kind: a document made of explicit
pages that you place content on by coordinates, using the VellumPdf.Kernel
engine directly.
Use it for what flow layout cannot express:

  Add-VellumPdfPage          add pages (any size, rotation)
  Add-VellumPdfShape / -Text / -Gradient / -PageImage / -PageBarcode
                             draw at x/y positions
  Invoke-VellumPdfCanvas     full canvas access from a script block
  Add-VellumPdfFormField     fillable AcroForm fields
  Add-VellumPdfLink          link rectangles to URLs or other pages
  Add-VellumPdfOutlineEntry  bookmarks, collapsed or expanded

then Save-VellumPdfDocument.
Coordinates are PDF points with the origin at
the page's bottom-left (72 points = 1 inch).
Set-VellumPdfDocumentInfo,
Set-VellumPdfOutputIntent, Register-VellumPdfFont, Protect-VellumPdfDocument
and Set-VellumPdfSignature work on page documents too.

Tagging: with -Tagged (implied by -Conformance PdfA2a and PdfUA1) the document
gets a structure tree.
Text is tagged (P, H1-H6, Span, Caption via
Add-VellumPdfText -Role), shapes and gradients are artifacts unless given
-AltText, images and barcodes need alternate text (or -Decorative), and
Invoke-VellumPdfCanvas drawing is an artifact.
Links and form fields cannot be
tagged by VellumPdf, so a PDF/UA document containing them is not fully
conformant (the cmdlets warn).
PDF/A and PDF/UA need embedded fonts and, for
PDF/UA, a title (Set-VellumPdfDocumentInfo -Title) and -Language; base-14 text
is embedded automatically with a metric-compatible substitute font.

-Linearize writes a "fast web view" file (first page readable while the rest
downloads).
It cannot be combined with -UseObjectStreams or encryption, and
signing ignores it.
-DocumentId and -Timestamp fix the otherwise random
document ID and creation date, which makes the output byte-for-byte
reproducible.

## EXAMPLES

### EXAMPLE 1

$doc = New-VellumPdfPageDocument -Language en
$doc | Add-VellumPdfPage | Add-VellumPdfText -Text 'Hello' -X 72 -Y 700 -FontSize 24 |
    Save-VellumPdfDocument -Path ./hello.pdf

### EXAMPLE 2

# Reproducible output
New-VellumPdfPageDocument -DocumentId ([byte[]](1..16)) -Timestamp '2026-01-01T00:00:00Z' | ...

## PARAMETERS

### -Conformance

None (default), PdfA2b, PdfA2u, PdfA2a or PdfUA1.

```yaml
Type: System.String
DefaultValue: None
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

### -Culture

The culture used to turn non-string values into text: table cells, list items and pie-chart
percentage labels (dates, numbers, and numbers read from strings).
A culture name ('de-DE') or a
[cultureinfo] (-Culture (Get-Culture) matches the console); an unknown name is an error.
Default:
the invariant culture, so the output is the same on every machine.
Each of Add-VellumPdfTable,
Add-VellumPdfList, Add-VellumPdfPieChart (and the page-document counterparts) has its own -Culture
that overrides this default for one call.
It is deliberately not derived from -Language: a language
tag says nothing about how dates and numbers look.

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

### -DocumentId

Exactly 16 bytes used as the document /ID.
Default: derived from the content
and the creation time.

```yaml
Type: System.Byte[]
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

### -InputCulture

A culture name or [cultureinfo] used to READ numbers that are given as strings in table cells and
list items (the document default; the table and list cmdlets have a per-call -InputCulture).
With it,
a string that consists only of a number is parsed strictly with that culture's decimal and grouping
separators ('de-DE': '1.234,5' is 1234.5, '1.5' is not a number).
Without it (the default) the
separators are detected from the text.
See Add-VellumPdfTable for the detection rules.

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

### -Language

BCP 47 document language written as /Lang (e.g.
'en-US').

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

### -Linearize

Write a linearized ("fast web view") file.

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

### -PageHeightMm

Custom default page height in millimetres (1..5080).

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomPage
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PageSize

The default size of added pages: A0-A6, Ledger, Legal, Letter.
Default A4.

```yaml
Type: System.String
DefaultValue: A4
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: NamedPage
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PageWidthMm

Custom default page width in millimetres (1..5080), with -PageHeightMm.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomPage
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Tagged

Write a structure tree (tagged PDF).
Implied by PdfA2a and PdfUA1.

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

### -Timestamp

The creation/modification date written to the file.
Default: now.

```yaml
Type: System.DateTimeOffset
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

### -UseObjectStreams

Compress the cross-reference data into object streams (smaller files).

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


