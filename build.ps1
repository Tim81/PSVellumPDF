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
    Test     - Restore (if lib is missing) then run Pester.
    Clean    - remove ./lib and dependencies build output.

.EXAMPLE
    ./build.ps1 Restore

.EXAMPLE
    ./build.ps1 Test
#>
[CmdletBinding()]
param(
    [ValidateSet('Restore', 'Test', 'Clean')]
    [string]$Task = 'Restore'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$libDir = Join-Path $root 'lib'
$depProj = Join-Path $root 'dependencies' 'Dependencies.csproj'
$publishDir = Join-Path $root 'dependencies' 'bin' 'publish'

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

function Invoke-Test {
    if (-not (Test-Path $libDir)) { Invoke-Restore }
    if (-not (Get-Module -ListAvailable Pester | Where-Object Version -ge '5.0')) {
        Write-Host '==> Installing Pester...' -ForegroundColor Cyan
        Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
    }
    Write-Host '==> Running Pester...' -ForegroundColor Cyan
    Invoke-Pester -Path (Join-Path $root 'tests') -Output Detailed
}

function Invoke-Clean {
    foreach ($p in @($libDir, (Join-Path $root 'dependencies' 'bin'), (Join-Path $root 'dependencies' 'obj'))) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "Removed $p" }
    }
}

switch ($Task) {
    'Restore' { Invoke-Restore }
    'Test'    { Invoke-Test }
    'Clean'   { Invoke-Clean }
}
