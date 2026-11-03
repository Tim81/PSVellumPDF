function Resolve-VellumPdfCulture {
    <#
    .SYNOPSIS
        Returns the culture and the input culture a cmdlet should use: the per-call argument, else the document's, else the default.
    .DESCRIPTION
        New-VellumPdfDocument and New-VellumPdfPageDocument store -Culture and -InputCulture as the note
        properties PSVellumCulture and PSVellumInputCulture. A per-call argument (bound) wins; otherwise the
        document's value is used; a document without the properties (created elsewhere) gets the invariant
        culture and no input culture. A bound -InputCulture of $null switches input-culture reading off for the
        call (number auto-detection applies).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Document,
        [AllowNull()] $Culture,
        [switch]$CultureBound,
        [AllowNull()] $InputCulture,
        [switch]$InputCultureBound,
        [Parameter(Mandatory)] [string]$CommandName
    )

    $stashed = $Document.PSObject.Properties['PSVellumCulture']
    $resolvedCulture = if ($CultureBound) { ConvertTo-VellumPdfCulture -Value $Culture -CommandName $CommandName }
    elseif ($stashed -and $stashed.Value -is [cultureinfo]) { $stashed.Value }
    else { [cultureinfo]::InvariantCulture }

    $stashedInput = $Document.PSObject.Properties['PSVellumInputCulture']
    $resolvedInput = if ($InputCultureBound) { if ($null -ne $InputCulture) { ConvertTo-VellumPdfCulture -Value $InputCulture -CommandName $CommandName -ParameterName 'InputCulture' } }
    elseif ($stashedInput -and $stashedInput.Value -is [cultureinfo]) { $stashedInput.Value }

    [pscustomobject]@{ Culture = $resolvedCulture; InputCulture = $resolvedInput }
}
