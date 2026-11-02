---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfList
---

# Add-VellumPdfList

## SYNOPSIS

Adds an ordered or unordered list to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfList [-Document] <Document> [-Item] <Object[]> [[-Style] <string>] [[-Indent] <double>]
 [[-Font] <string>] [[-FontSize] <double>] [[-FontHandle] <EmbeddedFontHandle>] [[-Color] <Object>]
 [[-Leading] <double>] [[-Language] <string>] [[-Format] <string>] [[-Culture] <Object>]
 [[-InputCulture] <Object>] [[-MarginTop] <double>] [[-MarginBottom] <double>] [-NoNumberParsing]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Add(ListElement).
Builds a ListElement from an array of
string items and an optional list style (Unordered, OrderedDecimal,
OrderedAlpha, OrderedRoman).
An optional -Indent adjusts the left indent
for the list.
An optional -Font/-FontSize override applies a TextStyle to
every item; when omitted the document default font is used.

-MarginTop and -MarginBottom apply spacing above and below the list
without affecting the left/right margins already set on the element.

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

The document flows through the pipeline for chaining with other
Add-VellumPdf* functions.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument |
    Add-VellumPdfList -Item 'Apples','Bananas','Cherries' |
    Save-VellumPdfDocument -Path ./fruit.pdf

### EXAMPLE 2

$doc | Add-VellumPdfList -Item 'First','Second','Third' `
       -Style OrderedDecimal -Indent 20 -Font Helvetica -FontSize 11

### EXAMPLE 3

# Nested list
$doc | Add-VellumPdfList -Item @(
    'Fruit',
    @{ Text = 'Vegetables'; Children = @('Carrot', 'Potato') }
)

### EXAMPLE 4

# Numbers and dates with a culture and a format
New-VellumPdfDocument |
    Add-VellumPdfList -Item 1234.5, '1.444,5', 99 -Format 'N2' -Culture de-DE |
    Save-VellumPdfDocument -Path ./amounts.pdf

## PARAMETERS

### -Color

Text colour for every item: an R,G,B triple in 0..1, a hex string
('#3366cc'), or a colour name.

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
  Position: 11
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
instance is returned after the list is added, enabling chaining.

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

A base-14 font name applied to every list item.
When omitted the
document default font is used.

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

### -FontHandle

An embedded TrueType font from Register-VellumPdfFont, applied to every
item (takes precedence over -Font).
Needed for text outside Windows-1252
and for PDF/A documents.
An item may override it with its own FontHandle key.

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
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

### -FontSize

Font size in points for list items, between 1 and 1000.
When omitted
the document default size is used.

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
  Position: 10
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Indent

Left indent for the list in points, between 0 and 1000.
When omitted
the VellumPdf library default indent is used.

```yaml
Type: System.Double
DefaultValue: 0
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
  Position: 12
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Item

The list items.
Each element is either a string (a leaf item) or a
hashtable describing a nested item:
    @{ Text = 'Parent'; Children = @('Child A', @{ Text = 'Child B' }) }
One level of children is supported: VellumPdf.Layout draws a child's own
children nowhere (a grandchild's text would silently vanish), so deeper
nesting is refused with an error.
Flatten deeper trees or add separate
lists.
An item hashtable may also set Font, FontSize, FontHandle, Color,
Leading and Language for that item alone.
A nested item in an Unordered list is marked with U+25E6, which
the base-14 fonts cannot encode (it shows as '?').
Empty strings are
permitted.
Mandatory.

```yaml
Type: System.Object[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Language

A BCP 47 language tag written for every item (e.g.
'fr'); only used in tagged
documents.
An item hashtable may carry its own Language key.

```yaml
Type: System.String
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

### -Leading

Line height in points for every item; 0 (the default) means 1.2 x the font size.

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

### -MarginBottom

Extra spacing in points below the list element.
Does not affect the
left/right page margins.

```yaml
Type: System.Double
DefaultValue: 0
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

### -MarginTop

Extra spacing in points above the list element.
Does not affect the
left/right page margins.

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

### -Style

The list marker style.
Unordered uses bullet points; OrderedDecimal,
OrderedAlpha, and OrderedRoman use numbered, alphabetic, and Roman
numeral markers respectively.
Defaults to Unordered.

```yaml
Type: System.String
DefaultValue: Unordered
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


