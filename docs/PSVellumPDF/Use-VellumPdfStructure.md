---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Use-VellumPdfStructure
---

# Use-VellumPdfStructure

## SYNOPSIS

Groups everything tagged inside a script block under one structure element.

## SYNTAX

### __AllParameterSets

```
Use-VellumPdfStructure [-ScriptBlock] <scriptblock> -Document <PdfDocument> [-Type <string>]
 [-Language <string>] [<CommonParameters>]
```

## DESCRIPTION

In a tagged page document (PDF/UA-1, PDF/A-2a or -Tagged) every text, shape or image cmdlet adds
its own element to the structure tree, side by side at the top.
Use-VellumPdfStructure nests them:
the elements created by the script block become children of one grouping element such as a
section (Sect), a division (Div), an article (Art) or a part (Part), which gives assistive
technology the outline of the page.
Scopes nest, and tables and lists use the same mechanism
for their rows and items.

The group is added to the tree when the block ends, and only if something was tagged inside it
(a warning says so otherwise).
In an untagged document the block just runs.

The block runs in the caller's scope with the document as $_.
Its own output is discarded; the
cmdlet writes the document to the pipeline, so the call chains.

## EXAMPLES

### EXAMPLE 1

$doc | Use-VellumPdfStructure -Type Sect -ScriptBlock {
    $_ | Add-VellumPdfText 'Results' -X 72 -Y 760 -Role H1 |
        Add-VellumPdfTextBox 'The results are shown below.' -X 72 -Y 740 -Width 400
}

## PARAMETERS

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

### -Language

BCP 47 language tag for the whole group.

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

### -ScriptBlock

The drawing whose elements are grouped.

```yaml
Type: System.Management.Automation.ScriptBlock
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

### -Type

The grouping element: Sect (default), Div, Art, Part, BlockQuote, Index or TOC.

```yaml
Type: System.String
DefaultValue: Sect
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


## NOTES

## RELATED LINKS


