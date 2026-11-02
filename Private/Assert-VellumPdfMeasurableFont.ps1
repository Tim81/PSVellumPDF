function Assert-VellumPdfMeasurableFont {
    <#
    .SYNOPSIS
        Refuses the Symbol and ZapfDingbats fonts where text has to be measured.
    .DESCRIPTION
        VellumPdf's built-in metrics cover the Windows-1252 text fonts only; Symbol and ZapfDingbats measure
        every string as 0 pt wide. Wrapping, alignment and table or list layout would silently collapse, so the
        cmdlets that measure refuse these two fonts. Plain left-aligned Add-VellumPdfText still draws them.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [string]$Font,
        [Parameter(Mandatory)] [string]$CommandName,
        [string]$Reason = 'needs to measure text'
    )
    if ($Font -in 'Symbol', 'ZapfDingbats') {
        throw (New-VellumPdfErrorRecord InvalidArgument "${CommandName}: -Font $Font has no width table in VellumPdf, so this cmdlet cannot measure it ($Reason). Use an embedded TrueType font (-FontHandle) or a text font.")
    }
}
