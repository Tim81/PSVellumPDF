---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: New-VellumPdfDocument
---

# New-VellumPdfDocument

## SYNOPSIS

Creates a new VellumPdf layout document.

## SYNTAX

### NamedPage (Default)

```
New-VellumPdfDocument [-Conformance <string>] [-PageSize <string>] [-DefaultFont <string>]
 [-DefaultFontSize <double>] [-Tagged] [-Language <string>] [-Margin <double>] [-MarginTop <double>]
 [-MarginRight <double>] [-MarginBottom <double>] [-MarginLeft <double>] [-UseObjectStreams]
 [-Culture <Object>] [-InputCulture <Object>] [<CommonParameters>]
```

### CustomPage

```
New-VellumPdfDocument -PageWidthMm <double> -PageHeightMm <double> [-Conformance <string>]
 [-DefaultFont <string>] [-DefaultFontSize <double>] [-Tagged] [-Language <string>]
 [-Margin <double>] [-MarginTop <double>] [-MarginRight <double>] [-MarginBottom <double>]
 [-MarginLeft <double>] [-UseObjectStreams] [-Culture <Object>] [-InputCulture <Object>]
 [<CommonParameters>]
```

## DESCRIPTION

Returns a live VellumPdf.Layout.Document.
Pipe it through the Add-VellumPdf*
functions and finish with Save-VellumPdfDocument, which disposes it.

The document is IDisposable.
If you do not call Save-VellumPdfDocument,
dispose it yourself with $doc.Dispose().

Page margins can be set uniformly with -Margin, or per-side with
-MarginTop, -MarginRight, -MarginBottom, -MarginLeft.
 When any per-side
parameter is supplied, the uniform -Margin value (if given) is used as
the baseline for the unspecified sides; otherwise the library defaults
are kept for unspecified sides.

-UseObjectStreams enables PDF cross-reference object streams, which
reduces file size for documents with many objects.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument -Conformance PdfA2b |
    Add-VellumPdfHeading -Text 'Report' |
    Add-VellumPdfParagraph -Text 'Body text.' |
    Save-VellumPdfDocument -Path ./report.pdf

### EXAMPLE 2

New-VellumPdfDocument -Margin 30

### EXAMPLE 3

New-VellumPdfDocument -Margin 30 -MarginLeft 50

## PARAMETERS

### -Conformance

The conformance level for the document.
Use PdfA2b, PdfA2u, or PdfA2a to
produce an ISO 19005-2 compliant archive file, or PdfUA1 for ISO 14289-1
(PDF/UA-1) accessibility; None (default) produces a standard PDF without
conformance requirements.
PDF/UA-1 forces a tagged document.
To pass the
preflight (Test-VellumPdfConformance, or Save-VellumPdfDocument -Validate)
also set -Language, give the document a title with Set-VellumPdfDocumentInfo
-Title, and give images, charts and barcodes alternate text.
Both levels
require embedded fonts: a conformant document therefore draws every base-14
font name it uses (the document default, -Font on paragraphs, headings,
tables, lists, text runs, headers and footers) in the metric-compatible
Liberation font (Helvetica -> Liberation Sans, Times -> Serif, Courier ->
Mono, with bold and italic variants), embedded once per document; layout is
unchanged.
Symbol and ZapfDingbats have no substitute: use -FontHandle
(Register-VellumPdfFont) for those and for text outside Windows-1252.
Text
in embedded fonts is not extracted by Get-VellumPdfText (its reader decodes
simple fonts only).
A document without -Conformance keeps the plain base-14
fonts.
Hyperlinks (-LinkUri) are not tagged by
VellumPdf, so a PDF/UA document containing them is not fully conformant.
Note that PDF/A forbids encryption, so PDF/A is incompatible with
Protect-VellumPdfDocument; PDF/UA-1 may be encrypted if Extract is kept.

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

### -DefaultFont

The base-14 font name stored as the document-wide default.
Content
cmdlets that receive no explicit -Font fill the gap from this value
rather than from the library-global Helvetica.
Defaults to Helvetica.

```yaml
Type: System.String
DefaultValue: Helvetica
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

### -DefaultFontSize

The font size in points stored as the document-wide default.
Content
cmdlets that receive no explicit -FontSize fill the gap from this value.
Must be between 1 and 1000.
Defaults to 11.

```yaml
Type: System.Double
DefaultValue: 11
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

A BCP 47 language tag written as the PDF /Lang entry (e.g.
'en-US').
Relevant for tagged PDF and PDF/A accessibility.
Requires VellumPdf 1.1+.

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

### -Margin

Uniform page margin in points applied to all four sides.
When any
per-side parameter (-MarginTop, -MarginRight, -MarginBottom, -MarginLeft)
is also supplied, this value becomes the baseline for the unspecified
sides rather than overriding them.

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

Bottom page margin in points.
When supplied, overrides the -Margin
baseline (or the library default) for the bottom side only.

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

### -MarginLeft

Left page margin in points.
When supplied, overrides the -Margin
baseline (or the library default) for the left side only.

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

### -MarginRight

Right page margin in points.
When supplied, overrides the -Margin
baseline (or the library default) for the right side only.

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

Top page margin in points.
When supplied, overrides the -Margin baseline
(or the library default) for the top side only.

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

### -PageHeightMm

Custom page height in millimetres (1..5080); see -PageWidthMm.

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

The paper size for every page in the document.
Accepts standard ISO and
US names (A0-A6, Ledger, Legal, Letter).
Defaults to A4.

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

Custom page width in millimetres (1..5080), used together with
-PageHeightMm instead of -PageSize.
For a landscape page make the width
the larger value.

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

When specified, marks the document as a tagged PDF (sets Document.Tagged
to $true).
Tagged PDFs are required for full PDF/A accessibility
conformance and enable assistive-technology support.

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

### -UseObjectStreams

When specified, enables PDF cross-reference object streams in the output
file.
Object streams reduce file size for documents with many objects by
compressing the cross-reference table.

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

### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


