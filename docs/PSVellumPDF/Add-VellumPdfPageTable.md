---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfPageTable
---

# Add-VellumPdfPageTable

## SYNOPSIS

Draws a table at x/y on a page of a page-based document, tagged as a real table in accessible PDFs.

## SYNTAX

### Width (Default)

```
Add-VellumPdfPageTable [[-Row] <Object[]>] -Document <PdfDocument> -X <double> -Y <double>
 -Width <double> [-Header <Object[]>] [-Page <int>] [-ColumnAlignment <string[]>]
 [-ColumnFormat <string[]>] [-Culture <Object>] [-InputCulture <Object>] [-NoNumberParsing]
 [-FontSize <double>] [-Font <string>] [-HeaderFont <string>] [-FontHandle <EmbeddedFontHandle>]
 [-Color <Object>] [-Leading <double>] [-Padding <double>] [-BorderWidth <double>]
 [-BorderColor <Object>] [-HeaderBackground <Object>] [-AlternateRowBackground <Object>]
 [-RowHeader] [-Language <string>] [-PassThru] [<CommonParameters>]
```

### ColumnWidth

```
Add-VellumPdfPageTable [[-Row] <Object[]>] -Document <PdfDocument> -X <double> -Y <double>
 -ColumnWidth <double[]> [-Header <Object[]>] [-Page <int>] [-ColumnAlignment <string[]>]
 [-ColumnFormat <string[]>] [-Culture <Object>] [-InputCulture <Object>] [-NoNumberParsing]
 [-FontSize <double>] [-Font <string>] [-HeaderFont <string>] [-FontHandle <EmbeddedFontHandle>]
 [-Color <Object>] [-Leading <double>] [-Padding <double>] [-BorderWidth <double>]
 [-BorderColor <Object>] [-HeaderBackground <Object>] [-AlternateRowBackground <Object>]
 [-RowHeader] [-Language <string>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The page-document counterpart of Add-VellumPdfTable: a grid whose cell text wraps inside its
column, with column and row spans, backgrounds and borders.
Because a page document has no
flow, you give the position (-X and -Y, the top-left corner in points from the page's
bottom-left) and the column widths yourself, and the table must fit on the page: one that is
too tall is an error rather than being split.

Rows are arrays of cells.
A row may be empty (@()) when RowSpans from the rows above cover all of
its columns; it is drawn as the extension of those cells and keeps an empty TR element (PDF/UA counts rows by TR).
-Row may be an
empty array when -Header is given (a header-only table); a table with neither is an error.
A cell is text, or a hashtable with Text and optionally ColSpan,
RowSpan, Alignment (Left, Center, Right, Justify), Background (colour), Color (text colour),
Format (a .NET format string) and Parse ($false draws a string as given):

    -Row @(
        @('Widget', '2', '10.00'),
        @(@{ Text = 'Shipping'; ColSpan = 2 }, '5.00')
    )

Values become text with a culture and an optional format.
A string cell is drawn as given unless it
consists only of a number; any other value (a number, a date, ...) is converted with -Culture (the
document's -Culture, invariant unless set) and the column's -ColumnFormat or the cell's own Format
key (a .NET format string such as 'N2' or 'yyyy-MM-dd').
A cell hashtable may carry a Format key, which
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

A single row is written @(,@('a','b')).
-Header takes one row of cells (-Header 'Item','Qty')
or several (an array of arrays).

In a tagged page document (PDF/UA-1, PDF/A-2a, -Tagged) the table is a Table element with TR rows
and TH/TD cells: header cells carry Scope Column (with -RowHeader, the first cell of every body
row is a TH with Scope Row), and ColSpan and RowSpan are written on the cells.
The grid lines and
backgrounds are artifacts.
In an untagged document it is only drawing.

Header text uses the bold variant of -Font (Helvetica, Times and Courier), or -HeaderFont.
Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
Register-VellumPdfFont); PDF/A and PDF/UA documents embed base-14 text automatically.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 450 -Header 'Item', 'Qty', 'Price' `
    -ColumnAlignment Left, Right, Right -HeaderBackground '#e8f0fe' -Row @(
        @('Widget', '2', '10.00'),
        @('Gadget', '1', '24.50'),
        @(@{ Text = 'Total'; ColSpan = 2 }, '44.50'))

### EXAMPLE 2

# Numbers in strings are read; the document culture and the column formats decide how they look
$page = New-VellumPdfPageDocument -Culture de-DE | Add-VellumPdfPage
$page | Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Header 'Item', 'Amount' -ColumnFormat '', 'N2' `
    -ColumnAlignment Left, Right -Row @(@('Widget', '1.444,5'), @('Gadget', 55433.34))

## PARAMETERS

### -AlternateRowBackground

Background colour of every second body row.

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

### -BorderColor

Grid line colour (default black).

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

### -BorderWidth

Grid line width in points (default 0.5); 0 draws no lines.

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

### -Color

Text colour: RGB triple in 0..1, hex or name.
Default black.

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

### -ColumnAlignment

Left, Center, Right or Justify per grid column.
A cell's own Alignment wins.

```yaml
Type: System.String[]
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
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ColumnWidth

One width per grid column, in points.
Give this or -Width.

```yaml
Type: System.Double[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ColumnWidth
  Position: Named
  IsRequired: true
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

A document from New-VellumPdfPageDocument.

```yaml
Type: VellumPdf.Document.PdfDocument
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

### -Font

A base-14 font name (default Helvetica).

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

### -FontHandle

An embedded TrueType font from Register-VellumPdfFont.
Overrides -Font and -HeaderFont.

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

### -FontSize

Size in points (default 10).

```yaml
Type: System.Double
DefaultValue: 10
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

### -Header

The header row (an array of cells) or rows (an array of arrays).

```yaml
Type: System.Object[]
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

### -HeaderBackground

Background colour of the header rows.

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

### -HeaderFont

A base-14 font for header cells (default: the bold variant of -Font).

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

BCP 47 language tag of the table text, written on the Table element.

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

### -Leading

Distance between baselines in points.
Default 1.2 times -FontSize.

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

### -Padding

Space between a cell's border and its text, in points (default 4).

```yaml
Type: System.Double
DefaultValue: 4
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

### -Page

The 1-based page number.
Default 1.

```yaml
Type: System.Int32
DefaultValue: 1
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

### -PassThru

Return an object with Document, Height, Bottom (the y of the table's lower edge), Rows and
Columns instead of the document.

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

The body rows: an array of rows, each an array of cells.
May be omitted or empty when -Header is given.

```yaml
Type: System.Object[]
DefaultValue: ''
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

### -RowHeader

Make the first cell of every body row a row header (TH, Scope Row).

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

### -Width

Total table width; the columns share it equally.
Give this or -ColumnWidth.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Width
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -X

Left edge of the table in points.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Y

Top edge of the table in points from the bottom of the page.

```yaml
Type: System.Double
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
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

### VellumPdf.Document.PdfDocument


## OUTPUTS

### VellumPdf.Document.PdfDocument (the same instance


### VellumPdf.Document.PdfDocument


### System.Management.Automation.PSObject


## NOTES

## RELATED LINKS


