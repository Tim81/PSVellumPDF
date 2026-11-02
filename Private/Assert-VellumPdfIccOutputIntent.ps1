function Assert-VellumPdfIccOutputIntent {
    <#
    .SYNOPSIS
        Refuses an ICC profile that PDF/A does not accept as an output intent.
    .DESCRIPTION
        ISO 19005-2 (6.2.3) wants an output intent profile of device class 'prtr', 'mntr', 'scnr' or
        'spac' (header bytes 12..15) and a major version of 4 or lower (byte 8). Get-VellumPdfIccComponentCount
        only checks the colour space, which is all an ICC colour space for drawing needs
        (Register-VellumPdfIccSpace keeps those rules), so output intents get this extra check.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [Parameter(Mandatory)] [string]$CommandName
    )
    if ($Bytes.Length -lt 128) { return }   # Get-VellumPdfIccComponentCount reports the malformed file
    $class = [System.Text.Encoding]::ASCII.GetString($Bytes, 12, 4)
    if ($class -notin 'prtr', 'mntr', 'scnr', 'spac') {
        throw ("${CommandName}: the ICC profile has device class '$($class.Trim())', which PDF/A does not accept for an output intent " +
            "(printer, display, scanner or colour-space-conversion profiles only: 'prtr', 'mntr', 'scnr', 'spac').")
    }
    if ($Bytes[8] -ge 5) {
        throw "${CommandName}: the ICC profile is version $($Bytes[8]).x; PDF/A accepts output intent profiles up to version 4."
    }
}
