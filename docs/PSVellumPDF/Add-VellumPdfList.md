---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfList
---

# Add-VellumPdfList

## SYNOPSIS

Adds an ordered or unordered list to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Add-VellumPdfList [-Document] <Document> [-Item] <string[]> [[-Style] <string>] [[-Indent] <double>]
 [[-Font] <string>] [[-FontSize] <double>] [<CommonParameters>]
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
The document
flows through the pipeline for chaining with other Add-VellumPdf*
functions.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument |
    Add-VellumPdfList -Item 'Apples','Bananas','Cherries' |
    Save-VellumPdfDocument -Path ./fruit.pdf

### EXAMPLE 2

$doc | Add-VellumPdfList -Item 'First','Second','Third' `
       -Style OrderedDecimal -Indent 20 -Font Helvetica -FontSize 11

## PARAMETERS

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
  Position: 4
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
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Indent

{{ Fill Indent Description }}

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

{{ Fill Item Description }}

```yaml
Type: System.String[]
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

### -Style

{{ Fill Style Description }}

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

{{ Fill in the Description }}

## OUTPUTS

### VellumPdf.Layout.Document (the same instance

{{ Fill in the Description }}

### VellumPdf.Layout.Document

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

