---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfTable
---

# Add-VellumPdfTable

## SYNOPSIS

Adds a table to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfTable [-Document] <Document> [[-Header] <string[]>] [-Row] <Object[][]>
 [[-ColumnWidth] <double[]>] [[-BorderWidth] <double>] [[-BorderColor] <double[]>]
 [[-HeaderBackground] <double[]>] [[-Font] <string>] [[-FontSize] <double>] [[-Alignment] <string>]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(TableElement).
Builds a TableElement from a jagged array
of row data, an optional header row, optional column widths, border styling,
and a default cell text style.
The document flows through the pipeline for
chaining with other Add-VellumPdf* functions.

Each inner array in -Row represents one data row; each element is converted
to a string with ToString() and added as a cell.
The optional -Header array
produces a header row via AddHeaderRow().

The -BorderColor and -HeaderBackground parameters accept a three-element
array of [double] values in the 0..1 range (R, G, B).

NOTE: -Row is a jagged array (array of rows).
For a SINGLE row use the
unary comma operator so PowerShell does not flatten the outer array:
-Row @(,@('Cell1','Cell2')).
A flat array like -Row @('a','b') is
treated as two one-cell rows.

Objects from Import-Csv (PSCustomObject) are rejected with a hint;
convert them to value arrays first:
    $rows = Import-Csv data.csv |
        ForEach-Object { [object[]]($_.PSObject.Properties.Value) }

## EXAMPLES

### EXAMPLE 1

$headers = @('Name', 'Score', 'Grade')
$rows = @(
    @('Alice', '95', 'A'),
    @('Bob',   '82', 'B')
)
New-VellumPdfDocument |
    Add-VellumPdfTable -Header $headers -Row $rows -BorderWidth 0.5 |
    Save-VellumPdfDocument -Path ./report.pdf

### EXAMPLE 2

$doc | Add-VellumPdfTable -Row @(@('Cell1','Cell2')) `
       -ColumnWidth @(100, 200) -Font Helvetica -FontSize 10 -Alignment Center

## PARAMETERS

### -Alignment

{{ Fill Alignment Description }}

```yaml
Type: System.String
DefaultValue: Left
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

### -BorderColor

{{ Fill BorderColor Description }}

```yaml
Type: System.Double[]
DefaultValue: ''
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

### -BorderWidth

{{ Fill BorderWidth Description }}

```yaml
Type: System.Double
DefaultValue: 0
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

### -ColumnWidth

{{ Fill ColumnWidth Description }}

```yaml
Type: System.Double[]
DefaultValue: ''
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

### -Document

{{ Fill Document Description }}

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

### -Font

{{ Fill Font Description }}

```yaml
Type: System.String
DefaultValue: ''
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

### -FontSize

{{ Fill FontSize Description }}

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

### -Header

{{ Fill Header Description }}

```yaml
Type: System.String[]
DefaultValue: ''
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

### -HeaderBackground

{{ Fill HeaderBackground Description }}

```yaml
Type: System.Double[]
DefaultValue: ''
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

### -Row

{{ Fill Row Description }}

```yaml
Type: System.Object[][]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
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

### VellumPdf.Layout.Document (the same instance

{{ Fill in the Description }}

### VellumPdf.Layout.Document

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

