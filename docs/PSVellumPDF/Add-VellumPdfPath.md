---
document type: cmdlet
external help file: PSVellumPDF-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PSVellumPDF
ms.date: 11/02/2026
PlatyPS schema version: 2024-05-01
title: Add-VellumPdfPath
---

# Add-VellumPdfPath

## SYNOPSIS

Draws a free-form path (lines and Bezier curves) on a page of a page-based document.

## SYNTAX

### Data (Default)

```
Add-VellumPdfPath [-Data] <string> -Document <PdfDocument> [-Page <int>] [-FillRule <string>]
 [-IccProfilePath <string>] [-FillIcc <double[]>] [-StrokeIcc <double[]>] [-FillColor <Object>]
 [-FillCmyk <double[]>] [-FillGray <double>] [-StrokeColor <Object>] [-StrokeCmyk <double[]>]
 [-StrokeGray <double>] [-StrokeWidth <double>] [-Dash <double[]>] [-LineCap <string>]
 [-LineJoin <string>] [-MiterLimit <double>] [-Opacity <double>] [-StrokeOpacity <double>]
 [-AltText <string>] [<CommonParameters>]
```

### Point

```
Add-VellumPdfPath -Document <PdfDocument> -Point <Object[]> [-Close] [-Page <int>]
 [-FillRule <string>] [-IccProfilePath <string>] [-FillIcc <double[]>] [-StrokeIcc <double[]>]
 [-FillColor <Object>] [-FillCmyk <double[]>] [-FillGray <double>] [-StrokeColor <Object>]
 [-StrokeCmyk <double[]>] [-StrokeGray <double>] [-StrokeWidth <double>] [-Dash <double[]>]
 [-LineCap <string>] [-LineJoin <string>] [-MiterLimit <double>] [-Opacity <double>]
 [-StrokeOpacity <double>] [-AltText <string>] [<CommonParameters>]
```

## DESCRIPTION

Describe the outline with -Data, a small subset of SVG path syntax in PDF points
(72 pt = 1 inch, origin at the page's bottom-left).
Numbers use a dot as the decimal
mark, whatever the culture; build the string with interpolation ("$x") rather than -f or
.ToString(), which use the current culture's decimal comma:

    M x y                        move to (starts a sub-path)
    L x y                        straight line to
    C x1 y1 x2 y2 x y            cubic Bezier curve to
    Z                            close the current sub-path

Only upper-case absolute commands are accepted; numbers after a command may repeat
(L 10 10 20 20 draws two lines).
A path may hold several sub-paths, for example a
ring made of an outer and an inner circle.
Alternatively give a polyline or polygon
as x,y pairs with -Point (add -Close for a polygon).

-FillRule decides which areas count as inside when sub-paths overlap: NonZero
(default) or EvenOdd, which cuts the inner sub-path out of the outer one.
A path
with neither a fill nor a stroke is stroked in black.
The PDF operator for
"fill even-odd and stroke" does not exist in the engine, so an EvenOdd path with both
is painted as a fill followed by a stroke of the same outline; the result is the same.

Colours, dashes, caps, joins and opacity work as in Add-VellumPdfShape, including
-FillCmyk/-StrokeCmyk and ICC colours (-IccProfilePath with -FillIcc/-StrokeIcc).

## EXAMPLES

### EXAMPLE 1

$doc | Add-VellumPdfPath -Data 'M 100 100 L 200 100 L 150 180 Z' -FillColor '#f4b400' -StrokeColor black

### EXAMPLE 2

# A ring: two circles, the inner one cut out by the even-odd rule. String interpolation always
# writes numbers with a dot; -f and .ToString() would use a decimal comma in some cultures.
$circle = {
    param($cx, $cy, $r)
    $k = 0.5522847498 * $r
    "M $($cx + $r) $cy C $($cx + $r) $($cy + $k) $($cx + $k) $($cy + $r) $cx $($cy + $r) " +
    "C $($cx - $k) $($cy + $r) $($cx - $r) $($cy + $k) $($cx - $r) $cy " +
    "C $($cx - $r) $($cy - $k) $($cx - $k) $($cy - $r) $cx $($cy - $r) " +
    "C $($cx + $k) $($cy - $r) $($cx + $r) $($cy - $k) $($cx + $r) $cy Z"
}
$doc | Add-VellumPdfPath -Data ((& $circle 200 400 50) + ' ' + (& $circle 200 400 25)) -FillRule EvenOdd -FillColor navy

## PARAMETERS

### -AltText

Alternate text.
In a tagged page document the path is then a Figure with this text;
without it the path is an artifact that assistive technology skips.

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

### -Close

Close the -Point outline into a polygon.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Point
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Dash

Dash pattern in points, e.g.
4,2.

```yaml
Type: System.Double[]
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

### -Data

Path data, e.g.
'M 100 100 L 200 100 L 150 180 Z'.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Data
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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

### -FillCmyk

Fill colour as C,M,Y,K in 0..1.

```yaml
Type: System.Double[]
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

### -FillColor

Fill colour (RGB triple, hex or name).

```yaml
Type: System.Object
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

### -FillGray

Fill colour as a grey level, 0 (black) to 1 (white), written as DeviceGray.

```yaml
Type: System.Double
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

### -FillIcc

Fill colour as components of the ICC profile (1, 3 or 4 values in 0..1).

```yaml
Type: System.Double[]
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

### -FillRule

NonZero (default) or EvenOdd.

```yaml
Type: System.String
DefaultValue: NonZero
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

### -IccProfilePath

An ICC profile that -FillIcc / -StrokeIcc colours are expressed in.

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

### -LineCap

Butt (default), Round or Square.

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

### -LineJoin

Miter (default), Round or Bevel.

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

### -MiterLimit

Longest miter, as a multiple of the line width, before a Miter join is bevelled.

```yaml
Type: System.Double
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

### -Opacity

Fill opacity 0..1.

```yaml
Type: System.Double
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

The 1-based page number.
Default 1.

```yaml
Type: System.Int32
DefaultValue: 1
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

### -Point

Polyline or polygon vertices as x,y pairs, e.g.
(100,100),(200,100),(150,180).

```yaml
Type: System.Object[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Point
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -StrokeCmyk

Outline colour as C,M,Y,K in 0..1.

```yaml
Type: System.Double[]
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

### -StrokeColor

Outline colour (RGB triple, hex or name).

```yaml
Type: System.Object
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

### -StrokeGray

Outline colour as a grey level, 0 (black) to 1 (white).

```yaml
Type: System.Double
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

### -StrokeIcc

Outline colour as components of the ICC profile.

```yaml
Type: System.Double[]
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

### -StrokeOpacity

Outline opacity 0..1.

```yaml
Type: System.Double
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

### -StrokeWidth

Outline width in points (default 1).

```yaml
Type: System.Double
DefaultValue: 1
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


