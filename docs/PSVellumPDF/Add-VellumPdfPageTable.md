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
Add-VellumPdfPageTable [-Row] <Object[]> -Document <PdfDocument> -X <double> -Y <double>
 -Width <double> [-Header <Object[]>] [-Page <int>] [-ColumnAlignment <string[]>]
 [-FontSize <double>] [-Font <string>] [-HeaderFont <string>] [-FontHandle <EmbeddedFontHandle>]
 [-Color <Object>] [-Leading <double>] [-Padding <double>] [-BorderWidth <double>]
 [-BorderColor <Object>] [-HeaderBackground <Object>] [-AlternateRowBackground <Object>]
 [-RowHeader] [-Language <string>] [-PassThru] [<CommonParameters>]
```

### ColumnWidth

```
Add-VellumPdfPageTable [-Row] <Object[]> -Document <PdfDocument> -X <double> -Y <double>
 -ColumnWidth <double[]> [-Header <Object[]>] [-Page <int>] [-ColumnAlignment <string[]>]
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
A cell is text, or a hashtable with Text and optionally ColSpan,
RowSpan, Alignment (Left, Center, Right, Justify), Background (colour) and Color (text colour):

    -Row @(
        @('Widget', '2', '10.00'),
        @(@{ Text = 'Shipping'; ColSpan = 2 }, '5.00')
    )

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

```yaml
Type: System.Object[]
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


