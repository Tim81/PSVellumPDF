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

    if ($Bytes) {
        [pscustomobject]@{ Name = '<bytes>'; Data = $Bytes }
        return
    }
    $files = if ($LiteralPath) {
        foreach ($lp in $LiteralPath) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($lp) }
    }
    else {
        foreach ($p in $Path) {
            $found = @($ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($p, [ref]$null))
            if (-not $found) { throw "${CommandName}: no file matches '$p'." }
            $found
        }
    }
    foreach ($file in $files) {
        if (-not [System.IO.File]::Exists($file)) { throw "${CommandName}: file not found: '$file'." }
        [pscustomobject]@{ Name = $file; Data = [System.IO.File]::ReadAllBytes($file) }
    }
}
