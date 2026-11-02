function Get-VellumPdfIccComponentCount {
    <#
    .SYNOPSIS
        Reads the number of colour components from an ICC profile header.
    .DESCRIPTION
        The profile's colour space signature sits at bytes 16..19 of the 128-byte header:
        'GRAY' (1 component), 'RGB ' and 'Lab ' (3), 'CMYK' (4). Anything else, or a file
        that is not an ICC profile (the 'acsp' signature at bytes 36..39), is refused.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [Parameter(Mandatory)] [string]$CommandName
    )
    if ($Bytes.Length -lt 128 -or [System.Text.Encoding]::ASCII.GetString($Bytes, 36, 4) -ne 'acsp') {
        throw (New-VellumPdfErrorRecord InvalidArgument "${CommandName}: the file is not an ICC profile (no 'acsp' header signature).")
    }
    switch ([System.Text.Encoding]::ASCII.GetString($Bytes, 16, 4)) {
        'GRAY' { 1 }
        'RGB ' { 3 }
        'Lab ' { 3 }
        'CMYK' { 4 }
        default { throw (New-VellumPdfErrorRecord InvalidArgument "${CommandName}: ICC colour space '$([System.Text.Encoding]::ASCII.GetString($Bytes, 16, 4).Trim())' is not supported (use a Gray, RGB, Lab or CMYK profile).") }
    }
}
