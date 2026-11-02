function Measure-VellumPdfTextWidth {
    <#
    .SYNOPSIS
        Width in points of a string in a resolved page font, including text-state spacing.
    .DESCRIPTION
        $Resolved comes from Get-VellumPdfPageFont (an object with Handle for an embedded font or
        Resource for a base-14 font). The engine measures plain text; this adds character spacing
        (per character), word spacing (per space) and horizontal scaling, exactly as a PDF viewer
        applies them: width = (glyph widths + Tc * characters + Tw * spaces) * Th / 100.

        That is the PDF advance width: a viewer adds Tc after every character, the last one included, so
        the text cursor ends Tc * Th / 100 past the last glyph. -VisibleExtent leaves that trailing Tc out
        and returns the width of what is actually inked, which is what right and centre alignment need.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)] $Resolved,
        [AllowEmptyString()] [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [double]$FontSize,
        [double]$CharSpacing = 0,
        [double]$WordSpacing = 0,
        [double]$HorizontalScale = 100,
        [switch]$VisibleExtent
    )
    if ($Text.Length -eq 0) { return 0.0 }
    $base = if ($Resolved.Handle) { $Resolved.Handle.MeasureString($Text, $FontSize) } else { $Resolved.Resource.MeasureString($Text, $FontSize) }
    $characters = 0
    foreach ($rune in $Text.EnumerateRunes()) { $characters++ }
    $spaces = 0
    foreach ($ch in $Text.ToCharArray()) { if ($ch -eq ' ') { $spaces++ } }
    $trailing = if ($VisibleExtent) { $CharSpacing } else { 0.0 }
    ($base + $CharSpacing * $characters - $trailing + $WordSpacing * $spaces) * $HorizontalScale / 100
}
