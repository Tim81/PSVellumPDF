function Get-VellumPdfInput {
    <#
    .SYNOPSIS
        Resolves -Path / -LiteralPath / -Bytes parameters to input items, without reading any file.
    .DESCRIPTION
        Shared by the cmdlets that read an existing PDF. Returns one item per input with
        Name (the resolved file path, or '<bytes>'), Data (the bytes for -Bytes, otherwise
        $null until Read-VellumPdfInput fills it) and Error (a ready-made message when the
        input could not be resolved, such as a path that matches no file, otherwise $null).

        Only paths are resolved here, so a long list of large files costs no memory.
        The caller reads one item at a time with Read-VellumPdfInput, handles a failure for
        that item (a non-terminating error) and then drops the bytes before the next one.
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
        [pscustomobject]@{
            Name       = '<bytes>'
            Data       = $Bytes
            Error      = if ($Bytes.Length -eq 0) { "${CommandName}: the byte array is empty, so it is not a PDF." }
            Command    = $CommandName
        }
        return
    }
    if ($LiteralPath) {
        foreach ($lp in $LiteralPath) {
            [pscustomobject]@{
                Name    = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($lp)
                Data    = $null
                Error   = $null
                Command = $CommandName
            }
        }
        return
    }
    foreach ($p in $Path) {
        # Resolve-Path with -ErrorAction Ignore: a path that matches nothing is reported per item below,
        # and no caught exception leaks into the caller's -ErrorVariable.
        $found = @(Resolve-Path -Path $p -ErrorAction Ignore | ForEach-Object { $_.ProviderPath })
        if (-not $found) {
            $message = if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($p)) { "${CommandName}: no file matches '$p'." }
            else { "${CommandName}: file not found: '$p'." }
            [pscustomobject]@{ Name = $p; Data = $null; Error = $message; Command = $CommandName }
            continue
        }
        foreach ($file in $found) {
            [pscustomobject]@{ Name = $file; Data = $null; Error = $null; Command = $CommandName }
        }
    }
}
