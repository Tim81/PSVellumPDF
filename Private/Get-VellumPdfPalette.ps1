function Get-VellumPdfPalette {
    <#
    .SYNOPSIS
        Returns the default categorical colour palette as hex strings.
    .DESCRIPTION
        Ten distinguishable colours (Okabe-Ito based, readable for most colour
        vision deficiencies), used for chart slices that have no explicit colour.
        Index with modulo to cycle.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    @('#0072B2', '#E69F00', '#009E73', '#D55E00', '#CC79A7', '#56B4E9', '#F0E442', '#999999', '#882255', '#44AA99')
}
