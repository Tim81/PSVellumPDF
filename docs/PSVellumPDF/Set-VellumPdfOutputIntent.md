---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-14-2026
PlatyPS schema version: 2024-05-01
title: Set-VellumPdfOutputIntent
---

# Set-VellumPdfOutputIntent

## SYNOPSIS

Sets a custom ICC output intent on a PDF/A conformant VellumPdf document.

## SYNTAX

### IccProfile (Default)

```
Set-VellumPdfOutputIntent [-IccProfilePath] <string> -Document <Document> -ComponentCount <int>
 -OutputConditionIdentifier <string> [-Info <string>] [<CommonParameters>]
```

### Cmyk

```
Set-VellumPdfOutputIntent -Document <Document> -Cmyk [-OutputConditionIdentifier <string>]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.SetPdfAOutputIntent(iccProfile, componentCount,
outputConditionIdentifier, info) and the UseCmykOutputIntent convenience
(the library's built-in generic CMYK profile).
PDF/A documents embed an
sRGB output intent by default; this cmdlet replaces it, which matters for
archival workflows that mandate a specific output condition.

REQUIRES PDF/A: the library only writes the output intent for conformant
documents (it is silently ignored otherwise), so this cmdlet throws when
the document's Conformance is None - create the document with
New-VellumPdfDocument -Conformance PdfA2b (or another PDF/A level).

CMYK CAVEAT: the layout engine renders text and table fills in DeviceRGB.
A CMYK output intent is intended for documents that also carry CMYK
content produced at the kernel level (not exposed by this module); strict
PDF/A validators may flag DeviceRGB layout content combined with a pure
CMYK output intent.
Prefer a 3-component (RGB) profile for documents
built with this module.

The ICC profile bytes are embedded as-is; the library does not validate
them at set time.
Verify archival output with a PDF/A validator (e.g.
veraPDF) as part of your workflow.

## EXAMPLES

### EXAMPLE 1

New-VellumPdfDocument -Conformance PdfA2b |
    Set-VellumPdfOutputIntent -IccProfilePath ./sRGB-v4.icc -ComponentCount 3 `
        -OutputConditionIdentifier 'sRGB v4 ICC preference' |
    Set-VellumPdfDocumentInfo -Title 'Archive' -Author 'Acme' |
    Add-VellumPdfParagraph -Text 'Archival body.' -FontHandle $font |
    Save-VellumPdfDocument -Path ./archive.pdf

### EXAMPLE 2

# Built-in generic CMYK intent (for documents that add CMYK kernel content)
$doc | Set-VellumPdfOutputIntent -Cmyk

## PARAMETERS

### -Cmyk

Use the library's built-in generic CMYK ICC profile instead of supplying
a profile file.
See the CMYK caveat above.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Cmyk
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ComponentCount

Number of colour components in the profile: 1 (Gray), 3 (RGB), or
4 (CMYK).

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: IccProfile
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

The live VellumPdf document flowing through the pipeline.
The same
instance is returned after the output intent is set, enabling chaining.

```yaml
Type: VellumPdf.Layout.Document
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

### -IccProfilePath

Path to an ICC profile file (.icc/.icm) to embed as the output intent.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: IccProfile
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Info

Optional human-readable /Info string describing the output condition.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: IccProfile
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OutputConditionIdentifier

The OutputConditionIdentifier string written to the OutputIntent
dictionary (e.g.
'sRGB IEC61966-2.1').
Defaults to 'Generic CMYK' when
-Cmyk is used.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Cmyk
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: IccProfile
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

### VellumPdf.Layout.Document


## OUTPUTS

### VellumPdf.Layout.Document (the same instance


### VellumPdf.Layout.Document


## NOTES

## RELATED LINKS


