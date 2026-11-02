---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Unprotect-VellumPdfDocument
---

# Unprotect-VellumPdfDocument

## SYNOPSIS

Writes a decrypted copy of a password-protected PDF.

## SYNTAX

### Path (Default)

```
Unprotect-VellumPdfDocument [-Path] <string> -DestinationPath <string> [-Password <securestring>]
 [-AllowInvalidatingSignatures] [-Force] [-AllowReconstruction] [-MaxDecodedStreamBytes <long>]
 [-MaxDiagnostics <int>] [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Unprotect-VellumPdfDocument -LiteralPath <string> -DestinationPath <string>
 [-Password <securestring>] [-AllowInvalidatingSignatures] [-Force] [-AllowReconstruction]
 [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>] [-MaxFormXObjectDepth <int>]
 [-ReconstructionBudgetMultiplier <int>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

Opens an encrypted PDF with its password and writes an unencrypted copy to
-DestinationPath; the original is never modified.
Use it to remove the
password from files you are entitled to open, for example before handing
them to a tool that cannot read encrypted PDFs.

A digitally signed PDF cannot be decrypted without invalidating its
signatures (they cover the encrypted bytes).
The cmdlet refuses by default;
pass -AllowInvalidatingSignatures to accept that.

One file at a time: a path that matches several files is refused (counted before any
file is read).
A failure for the file itself (not found, unreadable, not encrypted,
wrong or missing password, malformed) is a non-terminating error with the file as
TargetObject, so it follows -ErrorAction (use -ErrorAction Stop to throw).
Invalid
parameters (a destination equal to the source, an existing destination without -Force)
terminate.

## EXAMPLES

### EXAMPLE 1

Unprotect-VellumPdfDocument ./locked.pdf -DestinationPath ./open.pdf -Password (Read-Host -AsSecureString)

## PARAMETERS

### -AllowInvalidatingSignatures

Decrypt even though existing digital signatures become invalid.

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

### -AllowReconstruction

Try to recover a damaged file (missing or broken cross-reference table) by
scanning for objects before decrypting it.

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

### -DestinationPath

The decrypted copy to write.
Must differ from the source.

```yaml
Type: System.String
DefaultValue: ''
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

### -Force

Overwrite an existing destination file.

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

### -LiteralPath

The encrypted PDF, taken literally.
Aliases PSPath and FullName, so objects with either property bind by name.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
- FullName
ParameterSets:
- Name: LiteralPath
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MaxDecodedStreamBytes

Refuse to decode any stream larger than this many bytes (1 MiB to 512 MiB, the
default ceiling).
Lower it for untrusted files.

```yaml
Type: System.Int64
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

### -MaxDiagnostics

Stop collecting reader diagnostics after this many (1 to 1000).

```yaml
Type: System.Int32
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

### -MaxFormXObjectDepth

Deepest nesting of form XObjects followed while reading content (1 to 32).

```yaml
Type: System.Int32
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

### -Password

The user or owner password (a SecureString).

```yaml
Type: System.Security.SecureString
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

### -Path

The encrypted PDF.
Accepts wildcards, but the path must match exactly one file.
Piped strings bind here, and so do
piped objects with a Path property; piped FileInfo objects bind to -LiteralPath through their PSPath.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ReconstructionBudgetMultiplier

How many times the file size reconstruction may scan (1 to 8); used with
-AllowReconstruction.

```yaml
Type: System.Int32
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

### System.String


## OUTPUTS

### System.IO.FileInfo for the decrypted copy.


### System.IO.FileInfo


## NOTES

## RELATED LINKS


