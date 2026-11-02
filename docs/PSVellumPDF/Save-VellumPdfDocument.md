---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Save-VellumPdfDocument
---

# Save-VellumPdfDocument

## SYNOPSIS

Writes a VellumPdf document to a .pdf file and disposes it.

## SYNTAX

### Path (Default)

```
Save-VellumPdfDocument [-Path] <string> -Document <Object> [-Validate] [-KeepOpen] [-PassThru]
 [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Stream

```
Save-VellumPdfDocument -Document <Object> -Stream <Stream> [-Validate] [-KeepOpen] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Bytes

```
Save-VellumPdfDocument -Document <Object> -AsByteArray [-Validate] [-KeepOpen] [-WhatIf] [-Confirm]
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
the document alive for inspection, in which case you are responsible
for calling $doc.Dispose() yourself.
A layout document is single-use:
saving it a second time is refused, and after a FAILED save the document
must be rebuilt (the engine can leave state from the failed attempt, so a
retry could write a different file).
With -WhatIf nothing is saved and the
document is left open.

After a successful save the engine's own diagnostics are reported:
characters the base-14 fonts could not encode (written as '?') produce one
warning, and a header or footer cut to fit the page produces one warning
each.
The same information is attached to the returned file object as
the TextEncodingWarnings and BandTruncations properties.

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

### -AsByteArray

Return the PDF as a byte[] instead of writing a file.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Bytes
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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
Type: System.Object
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

### -Force

Create the parent directory of -Path when it does not exist (without it a
missing directory is an error).

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
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
same document object must be inspected after the file is written.
The
document cannot be saved a second time.

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

### -PassThru

Return the live document instead of the written file, and keep it open
(implies -KeepOpen).
The caller disposes it.
The document still cannot be
saved a second time; use it to read TextEncodingWarnings or BandTruncations.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Stream
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Path
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
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Stream

Write the PDF to this writable stream instead of a file (for example a
response or blob stream).
The PDF is rendered in memory first, so a failure
never leaves a partial PDF in the stream.
Nothing is returned.

```yaml
Type: System.IO.Stream
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Stream
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Validate

Run the in-process preflight (see Test-VellumPdfConformance) on the rendered
PDF against the document's own conformance level (PdfA2b/2u/2a/PdfUA1) and
fail with the first findings - writing nothing - when it is not compliant.
The document is then unusable, like after any failed save.
Not available
for encrypted documents.

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

### System.Object


## OUTPUTS

### System.IO.FileInfo for the written file (VellumPdf.Layout.Document with
-PassThru)


### System.IO.FileInfo


### System.Byte


### VellumPdf.Layout.Document


### VellumPdf.Document.PdfDocument


## NOTES

## RELATED LINKS


