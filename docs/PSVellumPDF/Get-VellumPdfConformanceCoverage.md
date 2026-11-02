---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Get-VellumPdfConformanceCoverage
---

# Get-VellumPdfConformanceCoverage

## SYNOPSIS

Lists which PDF/A and PDF/UA checks the in-process preflight performs.

## SYNTAX

### __AllParameterSets

```
Get-VellumPdfConformanceCoverage [[-Profile] <string[]>] [[-Status] <string[]>] [-Summary]
 [<CommonParameters>]
```

## DESCRIPTION

Test-VellumPdfConformance covers the checks that can be decided in-process, and
the engine publishes exactly which: for every clause of PDF/A-2 and PDF/UA-1 a
status of Implemented, Partial, Deferred or OutOfScope.
This cmdlet returns that
catalog, so you can see what a passing result does - and does not - tell you
before relying on it, or decide when a certified validator (veraPDF) is still
needed.
With -Summary it returns the counts and percentage instead.

## EXAMPLES

### EXAMPLE 1

Get-VellumPdfConformanceCoverage -Summary

### EXAMPLE 2

Get-VellumPdfConformanceCoverage -Profile PdfUA1 -Status Deferred, Partial | Format-Table Clause, Status, Note

## PARAMETERS

### -Profile

Limit to one profile: PdfA2b, PdfA2u, PdfA2a or PdfUA1.
Default: all checks.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Status

Limit to checks with this status.

```yaml
Type: System.String[]
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

### -Summary

Return one summary object per profile (counts and percentage implemented).

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSVellumPDF.ConformanceCheck (TestId


### PSVellumPDF.ConformanceCheck


### PSVellumPDF.ConformanceCoverage


## NOTES

## RELATED LINKS


