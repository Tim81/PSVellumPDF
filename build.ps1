#requires -Version 7.6
<#
.SYNOPSIS
    Build tasks for the PSVellumPDF module.

.DESCRIPTION
    Restores the VellumPdf .NET 10 assemblies into ./lib (the module loads them at
    import time), then optionally imports the module and runs the Pester test suite.

    ./lib is generated output and is git-ignored. Run `./build.ps1 Restore` after a
    fresh clone, or any time the VellumPdf package version changes.

.PARAMETER Task
    Restore  - publish dependencies/Dependencies.csproj and copy the assemblies to ./lib.
    Lint     - run PSScriptAnalyzer with PSScriptAnalyzerSettings.psd1 (fails on any finding).
    Test     - Restore (if lib is missing) then run Pester with code coverage (fails below target).
    Clean    - remove ./lib and dependencies build output.

.EXAMPLE
    ./build.ps1 Restore

.EXAMPLE
    ./build.ps1 Test
#>
[CmdletBinding()]
param(
    [ValidateSet('Restore', 'Lint', 'Test', 'Clean')]
    [string]$Task = 'Restore'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$libDir = Join-Path $root 'lib'
$depProj = Join-Path $root 'dependencies' 'Dependencies.csproj'
$publishDir = Join-Path $root 'dependencies' 'bin' 'publish'

# Code-coverage floor enforced by the Test task (and CI). Raise toward 100 as
# feature cmdlets and their tests land (see issue #11).
$script:CoverageTarget = 70

function Invoke-Restore {
    Write-Host '==> Publishing VellumPdf dependencies...' -ForegroundColor Cyan
    dotnet publish $depProj -c Release -o $publishDir | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)." }

    if (Test-Path $libDir) { Remove-Item $libDir -Recurse -Force }
    New-Item -ItemType Directory -Path $libDir | Out-Null

    # Copy only the VellumPdf assemblies; framework assemblies ship with PowerShell 7.6.
    Get-ChildItem $publishDir -Filter 'VellumPdf*.dll' |
        Copy-Item -Destination $libDir -Force

    $copied = Get-ChildItem $libDir -Filter '*.dll'
    Write-Host "==> lib/ now contains:" -ForegroundColor Green
    $copied | ForEach-Object { Write-Host "    $($_.Name)" }
    if (-not $copied) { throw 'No VellumPdf assemblies were copied into lib/.' }
}

function Invoke-Lint {
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
        Write-Host '==> Installing PSScriptAnalyzer...' -ForegroundColor Cyan
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
    }
    Import-Module PSScriptAnalyzer
    Write-Host '==> Running PSScriptAnalyzer...' -ForegroundColor Cyan
    $settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
    $findings = Invoke-ScriptAnalyzer -Path $root -Recurse -Settings $settings
    if ($findings) {
        $findings | Format-Table Severity, RuleName, ScriptName, Line, Message -AutoSize | Out-Host
        throw "PSScriptAnalyzer reported $($findings.Count) issue(s)."
    }
    Write-Host '==> Lint clean.' -ForegroundColor Green
}

function Invoke-Test {
    if (-not (Test-Path $libDir)) { Invoke-Restore }
    if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge '5.0')) {
        Write-Host '==> Installing Pester...' -ForegroundColor Cyan
        Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
    }
    Import-Module Pester -MinimumVersion 5.0

    $resultsDir = Join-Path $root 'testResults'
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

    # Coverage instruments the PowerShell wrappers (not the VellumPdf DLL).
    $covered = @(
        Get-ChildItem (Join-Path $root 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
        Get-ChildItem (Join-Path $root 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
    ).FullName

    $cfg = New-PesterConfiguration
    $cfg.Run.Path = Join-Path $root 'tests'
    $cfg.Run.PassThru = $true
    $cfg.Output.Verbosity = 'Detailed'
    $cfg.TestResult.Enabled = $true
    $cfg.TestResult.OutputFormat = 'NUnitXml'
    $cfg.TestResult.OutputPath = Join-Path $resultsDir 'testResults.xml'
    $cfg.CodeCoverage.Enabled = $true
    $cfg.CodeCoverage.Path = $covered
    $cfg.CodeCoverage.OutputPath = Join-Path $resultsDir 'coverage.xml'
    $cfg.CodeCoverage.CoveragePercentTarget = $script:CoverageTarget

    Write-Host '==> Running Pester...' -ForegroundColor Cyan
    $result = Invoke-Pester -Configuration $cfg

    if ($result.Result -ne 'Passed') {
        throw "Pester run failed: $($result.FailedCount) test(s) failed."
    }
    $pct = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
    Write-Host "==> Code coverage: $pct% (target $script:CoverageTarget%)" -ForegroundColor Cyan
    if ($result.CodeCoverage.CoveragePercent -lt $script:CoverageTarget) {
        throw "Code coverage $pct% is below the $script:CoverageTarget% target."
    }
}

function Invoke-Clean {
    foreach ($p in @($libDir, (Join-Path $root 'dependencies' 'bin'), (Join-Path $root 'dependencies' 'obj'))) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "Removed $p" }
    }
}

switch ($Task) {
    'Restore' { Invoke-Restore }
    'Lint'    { Invoke-Lint }
    'Test'    { Invoke-Test }
    'Clean'   { Invoke-Clean }
}
