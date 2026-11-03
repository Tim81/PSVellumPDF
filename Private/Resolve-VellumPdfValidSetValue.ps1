function Resolve-VellumPdfValidSetValue {
    <#
    .SYNOPSIS
        Returns the canonical spelling of a parameter value from the parameter's ValidateSet list.
    .DESCRIPTION
        ValidateSet matches case-insensitively, so '-Role h1' or '-Type sect' passes validation, but
        the value is written into the PDF as a structure type name, where case matters ('sect' is not
        a standard type). This looks the value up in the command's own ValidateSet and returns the
        listed spelling. A value that is not in the list is returned unchanged.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [System.Management.Automation.CommandInfo]$Command,
        [Parameter(Mandatory)] [string]$Parameter,
        [Parameter(Mandatory)] [string]$Value
    )
    $attribute = $Command.Parameters[$Parameter].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
    if ($attribute) {
        foreach ($candidate in $attribute.ValidValues) {
            if ([string]::Equals($candidate, $Value, [System.StringComparison]::OrdinalIgnoreCase)) { return [string]$candidate }
        }
    }
    $Value
}
