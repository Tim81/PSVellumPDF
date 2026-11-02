---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfPieChart
---

# Add-VellumPdfPieChart

## SYNOPSIS

Adds a pie chart to a VellumPdf document.

## SYNTAX

### Slices (Default)

```
Add-VellumPdfPieChart -Document <Document> -Slice <Object[]> [-Diameter <double>]
 [-StrokeColor <Object>] [-StrokeWidth <double>] [-Alignment <string>] [-StartAngle <double>]
 [-CounterClockwise] [-AltText <string>] [-Decorative] [-Legend] [-FontHandle <EmbeddedFontHandle>]
 [-MarginTop <double>] [-MarginBottom <double>] [<CommonParameters>]
```

### Data

```
Add-VellumPdfPieChart -Document <Document> -InputObject <Object> -ValueProperty <string>
 [-LabelProperty <string>] [-Diameter <double>] [-StrokeColor <Object>] [-StrokeWidth <double>]
 [-Alignment <string>] [-StartAngle <double>] [-CounterClockwise] [-AltText <string>] [-Decorative]
 [-Legend] [-FontHandle <EmbeddedFontHandle>] [-MarginTop <double>] [-MarginBottom <double>]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps VellumPdf.Layout.Elements.PieChart / PieSlice and Document.Add.
Give
the slices explicitly with -Slice, or pipe any objects in and name the
properties holding the value and the label:

    $doc | Add-VellumPdfPieChart -Slice @(
        @{ Value = 40; Label = 'North' },
        @{ Value = 25; Label = 'South'; Color = 'orange' })

    Get-Process | Group-Object Company |
        Add-VellumPdfPieChart -Document $doc -ValueProperty Count -LabelProperty Name

A slice without a Color takes the next colour of a built-in palette
designed to stay distinguishable for colour-blind readers.
The engine
never draws slice labels on the chart; pass -Legend to add a table
(colour swatch, label, share) below it.
In a tagged document the chart is
a Figure whose alternate text is -AltText, or - when omitted - composed
from the labels and percentages; use -Decorative when the same numbers
are already in nearby text.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument -Tagged -Language en |
    Add-VellumPdfPieChart -Legend -Slice @(
        @{ Value = 60; Label = 'Hardware' }, @{ Value = 40; Label = 'Services' }) |
    Save-VellumPdfDocument -Path ./share.pdf

## PARAMETERS

### -Alignment

Left, Center (default) or Right.

```yaml
Type: System.String
DefaultValue: Center
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

Alternate text for the chart in a tagged document.
Default: composed from
the slice labels and percentages.

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

### -CounterClockwise

Draw the slices counter-clockwise (default clockwise).

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

### -Decorative

Mark the chart as an artifact (not read by screen readers).
Cannot be
combined with -AltText.

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

### -Diameter

Chart diameter in points (default 200).
Wider than the page content area is
clamped by the engine, and warned about here.

```yaml
Type: System.Double
DefaultValue: 200
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

The live VellumPdf document.
Pipe it in with -Slice; pass it by parameter
when piping the data objects.

```yaml
Type: VellumPdf.Layout.Document
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Slices
  Position: Named
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -FontHandle

Embedded font for the -Legend table (needed for PDF/A and non-Windows-1252
labels).

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
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

### -InputObject

Data objects to chart (pipeline).
Use with -ValueProperty.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: Named
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LabelProperty

The property used as the slice label.
When omitted slices are unlabeled.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Legend

Add a table below the chart listing each slice: swatch, label, percentage.

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

### -MarginBottom

Extra spacing in points below the chart.

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

Extra spacing in points above the chart.

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

### -Slice

The slices: hashtables with Value (required, finite, >= 0), and optional
Color (RGB triple, hex or name) and Label, or VellumPdf PieSlice objects.

```yaml
Type: System.Object[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Slices
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -StartAngle

Where the first slice starts, in degrees counter-clockwise from 3 o'clock.
Default 90 (12 o'clock).

```yaml
Type: System.Double
DefaultValue: 90
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

### -StrokeColor

Colour of the thin separator drawn between slices.
Default: none.

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

### -StrokeWidth

Separator width in points (default 0.5).

```yaml
Type: System.Double
DefaultValue: 0.5
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

### -ValueProperty

The property of each input object holding the slice size.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: Named
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


### System.Object


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


