---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-13-2026
PlatyPS schema version: 2024-05-01
title: New-VellumPdfDocument
---

# New-VellumPdfDocument

## SYNOPSIS

Creates a new VellumPdf layout document.

## SYNTAX

### __AllParameterSets

```
New-VellumPdfDocument [[-Conformance] <string>] [[-PageSize] <string>] [[-DefaultFont] <string>]
 [[-DefaultFontSize] <double>] [[-Language] <string>] [[-Margin] <double>] [[-MarginTop] <double>]
 [[-MarginRight] <double>] [[-MarginBottom] <double>] [[-MarginLeft] <double>] [-Tagged]
 [-UseObjectStreams] [<CommonParameters>]
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

The PDF/A conformance level for the document.
Use PdfA2b, PdfA2u, or
PdfA2a to produce an ISO 19005-2 compliant archive file; None (default)
produces a standard PDF without conformance requirements.
Note that PDF/A
forbids encryption, so -Conformance is incompatible with
Protect-VellumPdfDocument.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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
  Position: 2
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
  Position: 3
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
  Position: 4
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
  Position: 5
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
  Position: 8
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
  Position: 9
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
  Position: 7
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
  Position: 6
  IsRequired: false
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
- Name: (All)
  Position: 1
  IsRequired: false
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


