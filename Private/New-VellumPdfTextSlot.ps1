function New-VellumPdfTextSlot {
    <#
    .SYNOPSIS
        Creates the slot object Convert-VellumPdfSlotText works on (one table cell or list item).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    param(
        [AllowNull()] $Value,
        [AllowNull()] [string]$Format,
        [bool]$Parse = $true,
        $Group = 0,
        [string]$What = 'the value'
    )
    [pscustomobject]@{ Value = $Value; Format = $Format; Parse = $Parse; Group = $Group; What = $What; Parsed = $null; Text = $null }
}
