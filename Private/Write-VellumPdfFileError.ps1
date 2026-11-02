function Write-VellumPdfFileError {
    <#
    .SYNOPSIS
        Reports the failure of one input file: a non-terminating error, or a terminating one under -ErrorAction Stop.
    .DESCRIPTION
        The reader cmdlets go on with the next file after a bad one, so the error is written with
        $PSCmdlet.WriteError. Under -ErrorAction Stop PowerShell would turn that into a terminating error
        itself, but when the exception is an ItemNotFoundException (a missing file) it then replaces the record
        in `catch [System.Management.Automation.ItemNotFoundException]` by the exception's own
        (id SessionStateException), losing PSVellumPDF.FileNotFound. Throwing the record ourselves when the
        preference is Stop keeps the id; the effect for the caller (stop at the first bad file) is the same.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Cmdlet,
        [Parameter(Mandatory)] [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(Mandatory)] [string]$ErrorActionPreferenceValue
    )
    if ($ErrorActionPreferenceValue -eq 'Stop') { $Cmdlet.ThrowTerminatingError($ErrorRecord) }
    else { $Cmdlet.WriteError($ErrorRecord) }
}
