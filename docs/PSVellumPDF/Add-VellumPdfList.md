---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-14-2026
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
 [[-Font] <string>] [[-FontHandle] <EmbeddedFontHandle>] [[-FontSize] <double>]
 [[-Language] <string>] [[-MarginTop] <double>] [[-MarginBottom] <double>] [<CommonParameters>]
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

Use -FontHandle (from Register-VellumPdfFont) instead of -Font to render
list items in an embedded TrueType font.
Required for Unicode text and
PDF/A documents.
-Font and -FontHandle are mutually exclusive.

-Language sets the BCP-47 language tag (e.g.
'en-US') on each list item,
enabling per-item language metadata in tagged and accessible PDFs.

-MarginTop and -MarginBottom apply spacing above and below the list
without affecting the left/right margins already set on the element.

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

# Embedded-font list (Unicode-safe, required for PDF/A)
$handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
$doc | Add-VellumPdfList -Item 'Item one','Item two' -FontHandle $handle

### EXAMPLE 5

# List with BCP-47 language tag on each item
$doc | Add-VellumPdfList -Item 'Premier','Deuxieme' -Language 'fr-FR'

## PARAMETERS

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
Mutually exclusive with -FontHandle.

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

An EmbeddedFontHandle returned by Register-VellumPdfFont for this
document.
When supplied every list item uses the embedded TrueType font
and the base-14 encoding warning is suppressed.
Handles from a different
document are rejected.
Mutually exclusive with -Font.

```yaml
Type: VellumPdf.Fonts.EmbeddedFontHandle
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
  Position: 6
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

### -Item

The list items.
Each element is either a string (a leaf item) or a
hashtable describing a nested item:
    @{ Text = 'Parent'; Children = @('Child A', @{ Text = 'Child B';
       Children = @('Grandchild') }) }
Children nest to any depth via ListItem.AddChild.
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

BCP-47 language tag (e.g.
'en-US', 'fr-FR') applied to each list item.
Enables per-item language metadata in tagged and PDF/UA documents.

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
  Position: 9
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
  Position: 8
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


