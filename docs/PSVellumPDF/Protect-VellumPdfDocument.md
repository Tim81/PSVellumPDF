---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 06-10-2026
PlatyPS schema version: 2024-05-01
title: Protect-VellumPdfDocument
---

# Protect-VellumPdfDocument

## SYNOPSIS

Applies password protection and usage permissions to a VellumPdf document.

## SYNTAX

### __AllParameterSets

```
Protect-VellumPdfDocument [-Document] <Document> [[-UserPassword] <securestring>]
 [[-OwnerPassword] <securestring>] [[-Permission] <string[]>] [-EncryptMetadata]
 [<CommonParameters>]
```

## DESCRIPTION

Wraps Document.Encrypt(PdfEncryptionSettings).
Encryption is staged in memory
and takes effect when the document is written by Save-VellumPdfDocument.
The
same Document instance is returned so the call can be chained in a pipeline.

At least one of -UserPassword or -OwnerPassword must be supplied.
Supplying
both is the most common configuration: the user password opens the document
for reading and the owner password unlocks all operations regardless of the
-Permission set.

PDF/A CONSTRAINT: PDF/A (ISO 19005) explicitly forbids encryption.
If the
document's Conformance is anything other than None (e.g.
PdfA2b, PdfA2u,
PdfA2a) this cmdlet throws a clear terminating error before calling Encrypt().
The VellumPdf library also enforces this constraint at Save() time, so the
fail-fast check here gives an earlier, more actionable message.

PASSWORDS: Both password parameters accept [securestring] to keep credentials
out of command history and verbose output.
Use Read-Host -AsSecureString for
interactive entry, or ConvertTo-SecureString for scripts.

## EXAMPLES

### EXAMPLE 1

$pw = Read-Host -Prompt 'Password' -AsSecureString
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Confidential.' |
    Protect-VellumPdfDocument -UserPassword $pw |
    Save-VellumPdfDocument -Path ./protected.pdf

### EXAMPLE 2

$userPw  = ConvertTo-SecureString 'userpass'  -AsPlainText -Force
$ownerPw = ConvertTo-SecureString 'ownerpass' -AsPlainText -Force
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Restricted copy.' |
    Protect-VellumPdfDocument -UserPassword $userPw -OwnerPassword $ownerPw `
        -Permission Print,Copy |
    Save-VellumPdfDocument -Path ./restricted.pdf

### EXAMPLE 3

# Owner-only (no user password needed to open; permissions still enforced)
$ownerPw = ConvertTo-SecureString 's3cret' -AsPlainText -Force
New-VellumPdfDocument |
    Add-VellumPdfParagraph -Text 'Body.' |
    Protect-VellumPdfDocument -OwnerPassword $ownerPw -Permission Print |
    Save-VellumPdfDocument -Path ./owner-only.pdf

## PARAMETERS

### -Document

The VellumPdf document to protect.
Accepts pipeline input.

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

### -EncryptMetadata

When specified, document metadata (XMP) is also encrypted.
When omitted the
library default applies (metadata is encrypted by default).

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

### -OwnerPassword

The password that grants unrestricted access, overriding -Permission
restrictions.
Recommended when using -Permission to limit operations.

```yaml
Type: System.Security.SecureString
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

### -Permission

One or more permission flags to allow.
Valid values:
  None          - no permissions granted beyond opening
  Print         - low-resolution printing
  Modify        - modify document content
  Copy          - copy or extract text and graphics
  Annotate      - add or modify annotations and fill forms
  FillForms     - fill in existing form fields
  Extract       - extract text and graphics (accessibility)
  Assemble      - insert, rotate, or delete pages and bookmarks
  PrintHighRes  - high-resolution (faithful) printing
  All           - all of the above (default)
Multiple values are combined as flags.
Example: -Permission Print,Copy

```yaml
Type: System.String[]
DefaultValue: "@('All')"
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

### -UserPassword

The password required to open the document.
Plain-text intermediates are
never stored in variables or written to output streams.

```yaml
Type: System.Security.SecureString
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

