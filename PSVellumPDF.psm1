#requires -Version 7.6
Set-StrictMode -Version Latest

# --- Load the VellumPdf .NET 10 assemblies bundled in ./lib ------------------
# ./lib is produced by `./build.ps1 Restore`. If it is missing, fail loudly with
# a directly actionable message rather than letting later type calls NRE.
$script:ModuleRoot = $PSScriptRoot
$script:LibPath = Join-Path $script:ModuleRoot 'lib'

$requiredAssemblies = @('VellumPdf.Kernel.dll', 'VellumPdf.Layout.dll')
foreach ($name in $requiredAssemblies) {
    $dll = Join-Path $script:LibPath $name
    if (-not (Test-Path $dll)) {
        throw "PSVellumPDF: missing '$name' in '$script:LibPath'. Run './build.ps1 Restore' to fetch the VellumPdf assemblies."
    }
    Add-Type -Path $dll
}

# --- Dot-source private helpers then public functions -----------------------
$private = @(Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName
