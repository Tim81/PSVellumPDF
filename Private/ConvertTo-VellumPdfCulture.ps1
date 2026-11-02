function ConvertTo-VellumPdfCulture {
    <#
    .SYNOPSIS
        Turns a -Culture / -InputCulture argument (a culture name or a [cultureinfo]) into a [cultureinfo].
    .DESCRIPTION
        A name is resolved with [cultureinfo]::GetCultureInfo(name, predefinedOnly), so an unknown name fails
        with a clear error instead of silently producing a placeholder culture. An empty name is the
        invariant culture.
    #>
    [CmdletBinding()]
    [OutputType([cultureinfo])]
    param(
        [Parameter(Mandatory)] [AllowNull()] $Value,
        [Parameter(Mandatory)] [string]$CommandName,
        [string]$ParameterName = 'Culture'
    )
    if ($Value -is [cultureinfo]) { return $Value }
    $name = [string]$Value
    try { [cultureinfo]::GetCultureInfo($name, $true) }
    catch { throw "${CommandName}: -$ParameterName '$name' is not a known culture name (for example en-US, de-DE or nl-NL); pass a name or a [cultureinfo]." }
}
