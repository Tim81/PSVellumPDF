function Get-VellumPdfPropertyValue {
    <#
    .SYNOPSIS
        Reads a named value from a dictionary or an object, returning $null when it is absent.
    .DESCRIPTION
        The module runs under strict mode, where $object.Missing throws. Input records
        (ConvertFrom-Json, Import-Csv, hashtables) often differ in which properties they carry,
        so reads go through here instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] $InputObject,
        [Parameter(Mandatory)] [string]$Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { $property.Value }
}
