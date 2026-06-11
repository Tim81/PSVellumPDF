---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-11-2026
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
 [[-MarginTop] <double>] [[-MarginBottom] <double>] [<CommonParameters>]
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

-MarginTop and -MarginBottom apply spacing above and below the table
without affecting the left/right margins already set on the element.

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

Horizontal text alignment for all cells (header and data).
Accepts
Left, Center, Right, or Justify.
Defaults to Left.

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

Border line colour as three doubles representing Red, Green, and Blue
channels, each in the 0.0..1.0 range.
Exactly three values must be
supplied.
When omitted the library default border colour is used.

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

Border line width in points applied to all cell borders, between 0 and
100.
When omitted the VellumPdf library default is used.

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

Column widths in points, each between 0.01 and 100000.
The count should
match the number of columns determined by the -Header or first -Row; a
mismatch emits a warning and extra widths are ignored.

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

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the table is added, enabling chaining.

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

A base-14 font name applied as the default cell style for all data
cells.
When omitted the document default font is used.

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

Font size in points for all data cells, between 1 and 1000.
When
omitted the document default size is used.

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

An optional string array of column header labels.
When supplied, a
styled header row is prepended to the table via AddHeaderRow().
The
count of header cells determines the expected column count for
-ColumnWidth mismatch warnings.

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

Background fill colour for the header row as three doubles representing
Red, Green, and Blue channels, each in the 0.0..1.0 range.
Exactly
three values must be supplied.
Only applied when -Header is also
supplied.

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

### -MarginBottom

Extra spacing in points below the table element.
Does not affect the
left/right page margins.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 11
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MarginTop

Extra spacing in points above the table element.
Does not affect the
left/right page margins.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 10
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Row

A jagged array of data rows (array of arrays).
Each inner array element
is converted to a string via ToString() and added as a cell.
PSCustomObject
elements are rejected with a conversion hint.
For a single data row, use
the unary comma operator to prevent PowerShell from flattening the outer
array: -Row @(,@('Cell1','Cell2')).

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


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


