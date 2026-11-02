function Get-VellumPdfInput {
    <#
    .SYNOPSIS
        Resolves -Path / -LiteralPath / -Bytes parameters to named byte arrays.
    .DESCRIPTION
        Shared by the cmdlets that read an existing PDF. Returns objects with a
        Name (the resolved file path, or '<bytes>') and the file's Data.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Path,
        [string[]]$LiteralPath,
        [byte[]]$Bytes,
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if ($null -ne $Bytes) {
        if ($Bytes.Length -eq 0) { throw "${CommandName}: the byte array is empty, so it is not a PDF." }
        [pscustomobject]@{ Name = '<bytes>'; Data = $Bytes }
        return
    }
    $files = if ($LiteralPath) {
        foreach ($lp in $LiteralPath) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($lp) }
    }
    else {
        foreach ($p in $Path) {
            $found = try { @($ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($p, [ref]$null)) }
            catch [System.Management.Automation.ItemNotFoundException] { @() }
            if (-not $found) {
                if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($p)) { throw "${CommandName}: no file matches '$p'." }
                throw "${CommandName}: file not found: '$p'."
            }
            $found
        }
    }
    foreach ($file in $files) {
        if (-not [System.IO.File]::Exists($file)) { throw "${CommandName}: file not found: '$file'." }
        $data = [System.IO.File]::ReadAllBytes($file)
        if ($data.Length -eq 0) { throw "${CommandName}: '$file' is empty, so it is not a PDF." }
        [pscustomobject]@{ Name = $file; Data = $data }
    }
}
