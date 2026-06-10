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
    Docs     - regenerate docs/ markdown reference from comment-based help (PlatyPS).
    Clean    - remove ./lib and dependencies build output.

.EXAMPLE
    ./build.ps1 Restore

.EXAMPLE
    ./build.ps1 Test
#>
[CmdletBinding()]
param(
    [ValidateSet('Restore', 'Lint', 'Test', 'Docs', 'Clean')]
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

# Pinned tool versions: CI installs exactly these, so a freshly published (or
# tampered) PSGallery release cannot silently enter the build.
$script:PSScriptAnalyzerVersion = '1.25.0'
$script:PesterVersion = '5.7.1'

function Invoke-Restore {
    Write-Host '==> Publishing VellumPdf dependencies...' -ForegroundColor Cyan
    # RestoreLockedMode: fail if the resolved package graph deviates from the
    # committed dependencies/packages.lock.json (supply-chain drift guard).
    dotnet publish $depProj -c Release -o $publishDir '/p:RestoreLockedMode=true' | Out-Host
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
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer | Where-Object Version -ge $PSScriptAnalyzerVersion)) {
        Write-Host '==> Installing PSScriptAnalyzer...' -ForegroundColor Cyan
        Install-Module PSScriptAnalyzer -RequiredVersion $PSScriptAnalyzerVersion -Scope CurrentUser -Force
    }
    Import-Module PSScriptAnalyzer -MinimumVersion $PSScriptAnalyzerVersion
    Write-Host '==> Running PSScriptAnalyzer...' -ForegroundColor Cyan
    $settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'

    # Pass 1: module + test code under full rules (Write-Host IS flagged here).
    $moduleTargets = @('Public', 'Private', 'tests', 'PSVellumPDF.psm1', 'PSVellumPDF.psd1') |
        ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ }
    $findings = @($moduleTargets | ForEach-Object {
            Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings $settings
        })

    # Pass 2: build.ps1 alone - a dev tool allowed to write host progress.
    $findings += @(Invoke-ScriptAnalyzer -Path $PSCommandPath -Settings $settings -ExcludeRule PSAvoidUsingWriteHost)

    # Pass 3: examples - documentation scripts; the encryption demo hard-codes
    # a sample password on purpose (with an inline warning not to).
    $examplesDir = Join-Path $root 'examples'
    if (Test-Path $examplesDir) {
        $findings += @(Invoke-ScriptAnalyzer -Path $examplesDir -Recurse -Settings $settings `
                -ExcludeRule PSAvoidUsingConvertToSecureStringWithPlainText)
    }

    if ($findings) {
        $findings | Format-Table Severity, RuleName, ScriptName, Line, Message -AutoSize | Out-Host
        throw "PSScriptAnalyzer reported $($findings.Count) issue(s)."
    }
    Write-Host '==> Lint clean.' -ForegroundColor Green
}

function Invoke-Test {
    if (-not (Test-Path $libDir)) { Invoke-Restore }
    if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge $PesterVersion)) {
        Write-Host '==> Installing Pester...' -ForegroundColor Cyan
        # SkipPublisherCheck: Windows ships an inbox Pester 3.x signed by
        # Microsoft; Pester 5 has a different publisher, which would otherwise
        # block the side-by-side install. The exact version is pinned above.
        Install-Module Pester -RequiredVersion $PesterVersion -Scope CurrentUser -Force -SkipPublisherCheck
    }
    Import-Module Pester -MinimumVersion $PesterVersion

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

function Invoke-DocBuild {
    if (-not (Test-Path $libDir)) { Invoke-Restore }
    if (-not (Get-Module -ListAvailable Microsoft.PowerShell.PlatyPS)) {
        Write-Host '==> Installing Microsoft.PowerShell.PlatyPS...' -ForegroundColor Cyan
        Install-Module Microsoft.PowerShell.PlatyPS -Scope CurrentUser -Force
    }
    Import-Module Microsoft.PowerShell.PlatyPS
    Import-Module (Join-Path $root 'PSVellumPDF.psd1') -Force

    $docsDir = Join-Path $root 'docs'
    if (Test-Path $docsDir) { Remove-Item $docsDir -Recurse -Force }

    Write-Host '==> Generating markdown command help...' -ForegroundColor Cyan
    $module = Get-Module PSVellumPDF
    # PlatyPS 1.0.1 trips over this script's StrictMode in its internal
    # help-object property probing; disable it for the generation scope only.
    & {
        Set-StrictMode -Off
        New-MarkdownCommandHelp -ModuleInfo $module -OutputFolder $docsDir `
            -HelpVersion $module.Version.ToString() | Out-Null
    }

    # Post-process generator artifacts: machine locale and template placeholders.
    foreach ($md in Get-ChildItem $docsDir -Recurse -Filter '*.md') {
        $text = Get-Content $md.FullName -Raw
        $text = $text -replace 'Locale: [a-z]{2}-[A-Z]{2}', 'Locale: en-US'
        $text = $text -replace '(?s)## ALIASES\r?\n.*?\{\{Insert list of aliases\}\}\r?\n\r?\n', ''
        Set-Content -Path $md.FullName -Value $text -NoNewline
    }
    Write-Host "==> Docs written to $docsDir" -ForegroundColor Green
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
    'Docs'    { Invoke-DocBuild }
    'Clean'   { Invoke-Clean }
}
