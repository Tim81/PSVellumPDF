function Expand-VellumPdfTab {
    <#
    .SYNOPSIS
        Replaces every tab in page text with four spaces.
    .DESCRIPTION
        A tab has no glyph in a PDF font: an embedded font draws glyph 0 (.notdef, which PDF/A forbids) and
        a base-14 font draws a zero-width character, so the text silently collapses. Page text cmdlets
        (Add-VellumPdfText, Add-VellumPdfTextBox, Set-VellumPdfPageBand, Measure-VellumPdfText) expand tabs
        with this one helper before measuring and drawing, so measured widths agree with what is drawn.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()] [AllowNull()] [Parameter(Mandatory)] [string]$Text
    )
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $Text.Replace("`t", '    ')
}
