---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-11-2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfDocumentInfo
---

# Set-VellumPdfDocumentInfo

## SYNOPSIS

Sets PDF document metadata (Info dictionary) on a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Set-VellumPdfDocumentInfo [-Document] <Document> [[-Title] <string>] [[-Author] <string>]
 [[-Subject] <string>] [[-Keywords] <string>] [[-Creator] <string>] [[-Producer] <string>]
 [<CommonParameters>]
```

## DESCRIPTION

Writes one or more string properties on Document.Info.
Only parameters
that are explicitly supplied are set; omitted parameters leave the
existing property values unchanged.

Note: Title and Author are embedded in the XMP packet when writing
PDF/A conformant documents and are required for PDF/A XMP metadata
compliance.

## EXAMPLES

### EXAMPLE 1

$doc | Set-VellumPdfDocumentInfo -Title 'Annual Report 2026' `
       -Author 'Acme Corp' -Subject 'Finance' -Keywords 'finance,annual'

### EXAMPLE 2

$doc | Set-VellumPdfDocumentInfo -Title 'Draft'

## PARAMETERS

### -Author

The document author written to Document.Info.Author and the XMP
dc:creator field for PDF/A documents.
Required for PDF/A XMP compliance.

```yaml
Type: System.String
DefaultValue: ''
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

### -Creator

The name of the application or tool that created the document content,
written to Document.Info.Creator.

```yaml
Type: System.String
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

### -Document

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the metadata is set, enabling chaining.

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

### -Keywords

Keyword string written to Document.Info.Keywords.
Typically a
comma-separated list of search terms.

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

### -Producer

The name of the tool that produced the PDF file, written to
Document.Info.Producer.

```yaml
Type: System.String
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

### -Subject

A short subject or description written to Document.Info.Subject.

```yaml
Type: System.String
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

### -Title

The document title written to Document.Info.Title and the XMP dc:title
field for PDF/A documents.
Required for PDF/A XMP compliance.

```yaml
Type: System.String
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


