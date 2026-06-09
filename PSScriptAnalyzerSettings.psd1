@{
    # Lint gate for PSVellumPDF. Fail the build on Errors and Warnings;
    # Information-level findings (e.g. positional Join-Path) are advisory.
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # build.ps1 intentionally writes human-facing progress to the host.
        # Module code under Public/ and Private/ must not use Write-Host.
        'PSAvoidUsingWriteHost'
    )
}
