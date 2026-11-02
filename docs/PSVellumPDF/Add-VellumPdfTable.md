---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfTable
---

# Add-VellumPdfTable

## SYNOPSIS

Adds a table to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfTable [-Document] <Document> [[-Header] <Object[]>] [-Row] <Object[]>
 [[-ColumnWidth] <double[]>] [[-BorderWidth] <double>] [[-BorderColor] <Object>]
 [[-HeaderBackground] <Object>] [[-AlternateRowBackground] <Object>] [[-ColumnAlignment] <string[]>]
 [[-ColumnFormat] <string[]>] [[-Culture] <Object>] [[-InputCulture] <Object>] [[-Font] <string>]
 [[-FontSize] <double>] [[-FontHandle] <EmbeddedFontHandle>] [[-CellPadding] <Object>]
 [[-Alignment] <string>] [[-MarginTop] <double>] [[-MarginBottom] <double>] [-NoNumberParsing]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(TableElement).
Builds a TableElement from row data, an
optional header row, optional column widths, border and row styling, and a
default cell text style.
The document flows through the pipeline for
chaining with other Add-VellumPdf* functions.

-Row accepts two shapes (the first row decides which):
  - Records: PSCustomObject rows straight from Import-Csv or Select-Object,
    or one [ordered] dictionary per row.
Columns are the property/key names,
    in the first row's order, and a header is derived from them when -Header
    is omitted.
A plain @{} hashtable with more than one key is refused: it
    has no fixed key order, so the columns would come out shuffled.
Write
    [ordered]@{ ...
} or [pscustomobject]@{ ...
} (a one-key hashtable is fine).
  - Cell arrays: one array per row.
Each element is a scalar (added as
    text) or a rich-cell hashtable for that one cell:
      @{ Text = 'Total'; ColSpan = 2; Alignment = 'Right';
         Background = '#eeeeee'; Font = 'HelveticaBold'; FontSize = 11;
         Color = 'navy' }
    Text is required; the rest are optional.
More keys: FontHandle (an
    embedded font for this cell), Leading, Padding (1, 2 or 4 numbers),
    Language (BCP 47 tag, tagged documents only), Format (a .NET format string for
    this cell) and Parse (set $false to draw a string as given).
A LinkUri key is
    refused because VellumPdf ignores hyperlinks in table cells.
  - The same keys work in -Header entries.

Values become text with a culture and an optional format.
A string cell is drawn as given unless it
consists only of a number; any other value (a number, a date, ...) is converted with -Culture (the
document's -Culture, invariant unless set) and the column's -ColumnFormat or the cell's own Format
key (a .NET format string such as 'N2' or 'yyyy-MM-dd').
A rich cell may carry a Format key, which
wins over -ColumnFormat, and Parse = $false to draw its string exactly as given.

Numbers in strings are always recognised (switch it off with -NoNumberParsing): a string cell (never
a header cell) that is only a number is read as [decimal], keeping its decimals, and then drawn like
any other number, so with the invariant default
'1.444,50' becomes 1444.50, '1,976.08' becomes 1976.08 and '55433.34' stays 55433.34.
The
separators are detected from the text:
  1.
With both '.' and ',' the LAST one is the decimal mark (1.444,50 and 1,976.08).
  2.
A separator that appears more than once is grouping (1.234.567).
  3.
A separator that appears once is a decimal mark (55433.34, 66443,85, 777544434,7755), except
     that exactly three digits after it with at most three digits before it is ambiguous (1,234
     and 1.234: with more than three digits before it, as in 12345,678, it is a decimal mark).
  4.
Grouping must be regular: 1-3 digits, then groups of exactly 3 (1.2.3 and the IP-like 10.0.0.1
     stay text).
  5.
Not a number, so left as is: a leading zero in a multi-digit integer part (007, 01234),
     spaces, currency symbols, '%', exponents, an empty string.
  6.
An ambiguous number takes the convention of the other values in the same column
     ('1.444,50' above shows that '.' groups); without such evidence it is left unchanged and
     ONE warning per call names the values.
-InputCulture switches detection off: every string is read strictly with that culture's separators
(de-DE: '1.234' is 1234 and '55433.34' is text).
-NoNumberParsing draws every string as given
(codes, ids, phone numbers).

Colour parameters (-BorderColor, -HeaderBackground, -AlternateRowBackground,
and a cell's Background/Color) accept an R,G,B triple in 0..1, a hex string
('#3366cc'/'#36c'), or a colour name.

NOTE: with cell-array rows, a SINGLE row needs the unary comma operator so
PowerShell does not flatten the outer array: -Row @(,@('Cell1','Cell2')).
A flat array like -Row @('a','b') is treated as two one-cell rows.
Records
do not need this.

-MarginTop and -MarginBottom apply spacing above and below the table
without affecting the left/right margins already set on the element.

Import-Csv example:
    Import-Csv data.csv | ForEach-Object { $rows += $_ }
    Add-VellumPdfTable -Row (Import-Csv data.csv)

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

### EXAMPLE 3

# Numbers in strings are read, dates and numbers use the culture and the column formats
$rows = @(
    @('Widget', '1.444,50', [datetime]'2026-03-05'),
    @('Gadget', '55433.34', [datetime]'2026-12-25'))
New-VellumPdfDocument |
    Add-VellumPdfTable -Header 'Item', 'Amount', 'Date' -Row $rows -Culture de-DE `
        -ColumnFormat '', 'N2', 'd' -ColumnAlignment Left, Right, Right |
    Save-VellumPdfDocument -Path ./amounts.pdf

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
  Position: 16
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -AlternateRowBackground

Background fill colour applied to every second data row (zebra striping):
an R,G,B triple in 0..1, a hex string, or a colour name.

```yaml
Type: System.Object
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

### -BorderColor

Border line colour: an R,G,B triple in 0..1, a hex string ('#3366cc'),
or a colour name.
When omitted the library default border colour is used.

```yaml
Type: System.Object
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

### -CellPadding

Default padding for every cell, in points: one number (all sides), two
(top/bottom, left/right) or four (top, right, bottom, left).
A cell's own
Padding key wins.
When omitted the engine default (4, 6, 4, 6) applies.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 15
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ColumnAlignment

Per-column horizontal alignment by column index (Left/Center/Right/
Justify), overriding -Alignment for those columns.
A cell's own
Alignment key still wins over this.

```yaml
Type: System.String[]
DefaultValue: ''
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

### -ColumnFormat

A .NET format string per column, parallel to -ColumnAlignment (by grid column index, a $null or ''
entry leaves a column on the type's default): -ColumnFormat '', 'N2', 'yyyy-MM-dd'.
Applied to numbers
and dates (and to numbers read from strings) with -Culture; text is never changed.
A cell's own
Format key wins.
A format the value's type rejects is an error naming the column.

```yaml
Type: System.String[]
DefaultValue: ''
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

### -ColumnWidth

Column widths in points, each between 0 and 100000.
A width of 0 means
"auto": the column shares the remaining space.
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

### -Culture

The culture used to turn numbers and dates into text: a name ('de-DE') or a [cultureinfo]
(-Culture (Get-Culture) matches the console).
Default: the document's -Culture, which is the
invariant culture unless New-VellumPdfDocument/New-VellumPdfPageDocument set one, so the output is
the same on every machine.
An unknown name is an error.

```yaml
Type: System.Object
DefaultValue: ''
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
  Position: 12
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -FontHandle

An embedded TrueType font from Register-VellumPdfFont, used as the table's
default cell font.
Takes precedence over -Font.
Needed for text outside
Windows-1252 and for PDF/A documents.
A cell may override it with its own
FontHandle key.

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 14
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
  Position: 13
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Header

Optional column header entries: strings, or rich-cell hashtables with the
same keys as a data cell.
For several header rows pass an array per row, e.g.
-Header @('Region', @{ Text = 'Sales'; ColSpan = 2 }), @('', 'Q1', 'Q2'); the
leading header rows repeat on every page.
When supplied, a header row is prepended to the
table via AddHeaderRow().
The count of header cells determines the
expected column count for -ColumnWidth mismatch warnings.

```yaml
Type: System.Object[]
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

Background fill colour for the header row (R,G,B triple, hex, or name).
Applied only when a header is present (supplied via -Header or derived
from record columns).

```yaml
Type: System.Object
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

### -InputCulture

Read number strings strictly with this culture (name or [cultureinfo]) instead of detecting the
separators.
Default: the document's -InputCulture, else detection.
Pass $null to switch the
document's -InputCulture off for this call.

```yaml
Type: System.Object
DefaultValue: ''
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
  Position: 18
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
  Position: 17
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -NoNumberParsing

Draw every string exactly as given instead of reading numbers from it.
A single cell can do the same
with the rich-cell key Parse = $false.

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

### -Row

The table rows.
Either PSCustomObject/[ordered] records (columns are the
property/key names; header derived when -Header is omitted), or one array
per row whose elements are scalars or rich-cell hashtables (see the
description).
For a single cell-array row, use the unary comma operator to
prevent PowerShell from flattening the outer array: -Row @(,@('a','b')).
May be empty (or $null) when -Header is given: the result is a header-only
table (drawn as ordinary rows, because the engine cannot lay out a table
of header rows alone, so a tagged document does not mark them as header
cells).
An empty -Row without -Header is an error.

```yaml
Type: System.Object[]
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


