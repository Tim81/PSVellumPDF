---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
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

{{ Fill Author Description }}

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

{{ Fill Creator Description }}

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

### -Keywords

{{ Fill Keywords Description }}

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

{{ Fill Producer Description }}

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

{{ Fill Subject Description }}

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

{{ Fill Title Description }}

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

{{ Fill in the Description }}

## OUTPUTS

### VellumPdf.Layout.Document (the same instance

{{ Fill in the Description }}

### VellumPdf.Layout.Document

{{ Fill in the Description }}

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

