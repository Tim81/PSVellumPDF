@{
    # Lint gate for PSVellumPDF module code (Public/, Private/, psm1, tests).
    # Fail the build on Errors and Warnings; Information-level findings
    # (e.g. positional Join-Path) are advisory.
    #
    # No rule exclusions here: module code must not use Write-Host. build.ps1
    # (a developer tool that writes host progress) is linted separately by the
    # Lint task with PSAvoidUsingWriteHost excluded for that one file.
    Severity = @('Error', 'Warning')
}
