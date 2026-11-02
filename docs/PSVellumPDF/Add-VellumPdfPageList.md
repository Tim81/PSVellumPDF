---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfPageList
---

# Add-VellumPdfPageList

## SYNOPSIS

Draws a bulleted or numbered list at x/y on a page of a page-based document, tagged as a real list.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfPageList [-Item] <Object[]> -Document <PdfDocument> -X <double> -Y <double>
 -Width <double> [-Page <int>] [-Numbered] [-Marker <string>] [-FontSize <double>] [-Font <string>]
 [-FontHandle <EmbeddedFontHandle>] [-Color <Object>] [-Leading <double>] [-ItemSpacing <double>]
 [-Indent <double>] [-Language <string>] [-Format <string>] [-Culture <Object>]
 [-InputCulture <Object>] [-NoNumberParsing] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION

The page-document counterpart of Add-VellumPdfList: each item is a marker (a bullet, or 1.
2.
3.
with -Numbered) followed by text that wraps inside -Width and hangs under itself.
-X is the left
edge and -Y the top of the list in points from the page's bottom-left.
A list that does not fit
above the bottom of the page is an error.

An item is text, or a hashtable (or object) with Text and optionally Children (one more level of
items).
An item without Text is an error; a missing or $null Children means no children:

    -Item 'First', @{ Text = 'Second'; Children = 'Second A', 'Second B' }, 'Third'

In a tagged page document (PDF/UA-1, PDF/A-2a, -Tagged) the list is an L element with LI items,
each holding a Lbl (the marker) and an LBody (the text, plus the nested L of an item that has
children).
In an untagged document it is only drawing.

Items become text with a culture and an optional format.
A string item is drawn as given unless it
consists only of a number; any other value (a number, a date, ...) is converted with -Culture (the
document's -Culture, invariant unless set) and -Format (a .NET format string such as 'N2' or
'yyyy-MM-dd'); an item hashtable may carry its own Format key, and Parse = $false to draw its string
as given.

Numbers in strings are always recognised (switch it off with -NoNumberParsing): a string item that is
only a number is read as [decimal], keeping its decimals, and then drawn like any other number, so
with the invariant default '1.444,50' becomes 1444.50, '1,976.08' becomes 1976.08 and '55433.34'
stays 55433.34.
The separators are detected from the text:
  1.
With both '.' and ',' the LAST one is the decimal mark (1.444,50 and 1,976.08).
  2.
A separator that appears more than once is grouping (1.234.567).
  3.
A separator that appears once is a decimal mark (55433.34, 66443,85), except that exactly three
     digits after it with at most three digits before it is ambiguous (1,234 and 1.234; with more
     than three digits before it, as in 12345,678, it is a decimal mark).
  4.
Grouping must be regular: 1-3 digits, then groups of exactly 3 (1.2.3 and 10.0.0.1 stay text).
  5.
Not a number, so left as is: a leading zero in a multi-digit integer part (007, 01234), spaces,
     currency symbols, '%', exponents, an empty string.
  6.
An ambiguous number takes the convention of the other items of the same call; without such
     evidence it is left unchanged and ONE warning per call names the values.
-InputCulture switches detection off: every string is read strictly with that culture's separators.

Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
Register-VellumPdfFont); PDF/A and PDF/UA documents embed base-14 text automatically.

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item 'Read the brief', 'Draft the plan', 'Review with the team'

### EXAMPLE 2

$doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Numbered -Item 'Prepare', @{ Text = 'Run'; Children = 'Dry run', 'Real run' }, 'Report'

### EXAMPLE 3

$doc | Add-VellumPdfPageList -X 72 -Y 500 -Width 300 -Item 1234.5, '1.444,5', 99 -Format 'N2' -Culture de-DE

## PARAMETERS

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

### -Culture

The culture used to turn numbers and dates into text: a name ('de-DE') or a [cultureinfo]
(-Culture (Get-Culture) matches the console).
Default: the document's -Culture, which is the
invariant culture unless New-VellumPdfDocument/New-VellumPdfPageDocument set one.
An unknown name is
an error.

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
Overrides -Font.

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

Size in points (default 11).

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

### -Format

A .NET format string for items that are not text ('N2', 'yyyy-MM-dd'), applied with -Culture; also to
numbers read from strings.
An item's own Format key wins.
A format the value's type rejects is an
error naming the item.

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

### -Indent

Width of the marker column in points (default 1.8 times -FontSize).
Children are indented by one more.

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

### -Item

The items: text, or hashtables with Text and Children.

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

### -ItemSpacing

Extra space after every item, in points (default 3).

```yaml
Type: System.Double
DefaultValue: 3
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

BCP 47 language tag of the list text, written on the L element.

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

### -Marker

The bullet character (default a bullet; a hyphen when the font has no bullet glyph).

```yaml
Type: System.String
DefaultValue: '[string][char]0x2022'
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
A single item can do the same
with the key Parse = $false.

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

### -Numbered

Number the items 1.
2.
3.
instead of using a bullet; children are numbered a.
b.
c.

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

Return an object with Document, Height, Bottom (the y of the list's lower edge) and ItemCount
instead of the document.

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

Total width of the list including the marker column.

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

### -X

Left edge of the list in points.

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

Top of the list in points from the bottom of the page.

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


