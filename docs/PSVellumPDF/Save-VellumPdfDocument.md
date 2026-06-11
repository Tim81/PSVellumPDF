---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-11-2026
PlatyPS schema version: 2024-05-01
title: Save-VellumPdfDocument
---

# Save-VellumPdfDocument

## SYNOPSIS

Writes a VellumPdf document to a .pdf file and disposes it.

## SYNTAX

### __AllParameterSets

```
Save-VellumPdfDocument [-Path] <string> -Document <Document> [-KeepOpen] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Save(path) - or, when a signature has been staged with
Set-VellumPdfSignature, SigningExtensions.Sign(document, stream,
settings), which signs the document while writing it (PAdES).
The document is IDisposable; this function
disposes it after the save attempt (success or failure) because saving is
the terminal step of a build pipeline, and marks it so later cmdlet calls
against the stale document fail with a clear error.
Use -KeepOpen to keep
the document alive for further edits, in which case you are responsible
for calling $doc.Dispose() yourself.
With -WhatIf nothing is saved and the
document is left open.

If the pipeline is aborted BEFORE this cmdlet runs (for example by an
error in an earlier Add-VellumPdf* call, or -WarningAction Stop turning
the encoding warning into a terminating error), the document is never
saved or disposed - dispose it yourself in your catch block.

The write is atomic: the PDF is rendered (and signed) to a temporary
file beside -Path and only moved into place once it is complete, so a
render or signing failure leaves any existing file at -Path untouched.
On success an existing file at -Path is overwritten.

## EXAMPLES

### EXAMPLE 1

$doc | Save-VellumPdfDocument -Path ./out.pdf

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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

The live VellumPdf document to save.
Accepts pipeline input.
After saving,
the document is disposed and stamped so subsequent cmdlet calls against
the stale instance fail with a clear error.
Use -KeepOpen to suppress
disposal.

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

### -KeepOpen

When specified, the document is not disposed after saving.
The caller is
responsible for calling $doc.Dispose() when finished.
Useful when the
same document object must be inspected or further manipulated after the
file is written.

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

### -Path

File system path for the output PDF file.
The parent directory must
already exist; an existing file at this path is overwritten.
Mandatory
and positional (position 0).

```yaml
Type: System.String
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

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

### VellumPdf.Layout.Document


## OUTPUTS

### System.IO.FileInfo for the written file.


### System.IO.FileInfo


## NOTES

## RELATED LINKS


