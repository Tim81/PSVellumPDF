function Assert-VellumPdfCoordinate {
    <#
    .SYNOPSIS
        Throws unless a page coordinate or size is a finite number within the page limit.
    .DESCRIPTION
        The largest page VellumPdf and this module allow is 5080 mm, which is 14,400 points.
        Larger values are almost always mistakes and, written into content streams, can exceed the
        number limits PDF/A imposes (ISO 19005-2, 6.1.13), so they are refused up front. Each value
        is checked against +-14,400 points, and the error names the cmdlet and the parameter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] $Value,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$CommandName,
        [double]$Limit = 14400
    )
    $number = $Value -as [double]
    if ($null -eq $Value -or $null -eq $number -or -not [double]::IsFinite($number) -or [math]::Abs($number) -gt $Limit) {
        throw "${CommandName}: -$Name must be a finite number between -$Limit and $Limit points; got '$Value'."
    }
}
