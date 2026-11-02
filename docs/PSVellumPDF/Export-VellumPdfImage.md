---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Export-VellumPdfImage
---

# Export-VellumPdfImage

## SYNOPSIS

Saves the images embedded in an existing PDF as files.

## SYNTAX

### Path (Default)

```
Export-VellumPdfImage [-Path] <string[]> -DestinationPath <string> [-BaseName <string>]
 [-Page <int[]>] [-ExcludeInline] [-Password <securestring>] [-Force]
 [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>] [-MaxFormXObjectDepth <int>]
 [-ReconstructionBudgetMultiplier <int>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Export-VellumPdfImage -LiteralPath <string[]> -DestinationPath <string> [-BaseName <string>]
 [-Page <int[]>] [-ExcludeInline] [-Password <securestring>] [-Force]
 [-MaxDecodedStreamBytes <long>] [-MaxDiagnostics <int>] [-MaxFormXObjectDepth <int>]
 [-ReconstructionBudgetMultiplier <int>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Bytes

```
Export-VellumPdfImage -Bytes <byte[]> -DestinationPath <string> [-BaseName <string>] [-Page <int[]>]
 [-ExcludeInline] [-Password <securestring>] [-Force] [-MaxDecodedStreamBytes <long>]
 [-MaxDiagnostics <int>] [-MaxFormXObjectDepth <int>] [-ReconstructionBudgetMultiplier <int>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

EXPERIMENTAL - built on VellumPdf.Reader, which is still a Preview package.

Extracts every image XObject (and, by default, inline images and images in
annotation appearances) and writes each to -DestinationPath.
Images the
reader can re-encode (Flate/raw samples, with their soft mask as alpha) are
written as PNG.
Compressed images keep their original data, which keeps them
lossless: JPEG (.jpg) and JPEG 2000 (.jp2, .j2k) are written as they are;
CCITT fax images are wrapped in a single-strip TIFF (.tif); JBIG2 images are
joined with their shared "global" segments into a standalone sequential JBIG2
file (.jb2).
A CCITT image TIFF cannot describe (Group 4 with byte-aligned rows,
Group 3 without end-of-line codes unless it is one-dimensional and byte-aligned) and any other image that cannot be written as a PNG (for example CMYK
or indexed samples) are skipped with a warning.
Each file object carries Page, Encoding, Width, Height, BitsPerComponent,
ColorSpace, ComponentCount, IsInline, IsStencilMask and HasSoftMask.

Files are named <pdf name>-p<page>-i<n>.<ext>.
An existing file is not
overwritten unless -Force is given.

## EXAMPLES

### EXAMPLE 1

Export-VellumPdfImage ./brochure.pdf -DestinationPath ./images

## PARAMETERS

### -BaseName

Prefix of the file names.
Default: the PDF's file name without extension.

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

### -Bytes

The PDF as a byte array (files are named 'pdf-p1-i1.png' ...; use -BaseName).

```yaml
Type: System.Byte[]
DefaultValue: ''
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

### -DestinationPath

The folder to write into.
Created if it does not exist.

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

### -ExcludeInline

Skip inline images (BI/ID/EI) and annotation-appearance images.

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

### -Force

Overwrite existing files.

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

The PDF file(s), taken literally.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
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

### -Page

1-based pages to extract from.
Default: all.

```yaml
Type: System.Int32[]
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

### -Password

Password for an encrypted PDF (a SecureString).

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

The PDF file(s).
Accepts wildcards.
Piped strings bind here; piped file objects bind to -LiteralPath.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
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

### System.String[]


## OUTPUTS

### System.IO.FileInfo for each file written


### System.IO.FileInfo


## NOTES

## RELATED LINKS


