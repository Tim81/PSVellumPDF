#requires -Version 7.6
Set-StrictMode -Version Latest

# --- Load the VellumPdf .NET 10 assemblies bundled in ./lib ------------------
# ./lib is produced by `./build.ps1 Restore`. If it is missing, fail loudly with
# a directly actionable message rather than letting later type calls NRE.
$script:ModuleRoot = $PSScriptRoot
$script:LibPath = Join-Path $script:ModuleRoot 'lib'

# Dependency order: Kernel first, then the packages that reference it. Signing
# references Reader (PAdES long-term validation), so Reader must precede it.
$requiredAssemblies = @(
    'VellumPdf.Kernel.dll'
    'VellumPdf.Layout.dll'
    'VellumPdf.Reader.dll'
    'VellumPdf.Signing.dll'
    'VellumPdf.Barcodes.dll'
    'VellumPdf.Conformance.dll'
    'VellumPdf.Fonts.Standard14.dll'
    'PSVellumPDF.Interop.dll'
)

# VellumPdf 2.x assemblies are strong-named with a fixed AssemblyVersion for the
# whole 2.x line. Check identity BEFORE loading so a stale 1.x ./lib (or another
# copy already loaded into this session) fails with an actionable message
# instead of a confusing type-load error later.
$script:VellumPdfAssemblyVersion = [version]'2.0.0.0'
$script:VellumPdfPublicKeyToken = 'b2757187a6d18ae5'

foreach ($name in $requiredAssemblies) {
    $dll = Join-Path $script:LibPath $name
    if (-not (Test-Path $dll)) {
        throw "PSVellumPDF: missing '$name' in '$script:LibPath'. Run './build.ps1 Restore' to fetch the VellumPdf assemblies."
    }
    $identity = [System.Reflection.AssemblyName]::GetAssemblyName($dll)
    if ($name -like 'VellumPdf.*') {
        $token = [System.BitConverter]::ToString($identity.GetPublicKeyToken()).Replace('-', '').ToLowerInvariant()
        if ($identity.Version -ne $script:VellumPdfAssemblyVersion -or $token -ne $script:VellumPdfPublicKeyToken) {
            throw ("PSVellumPDF: '$name' in '$script:LibPath' is version $($identity.Version) (token '$token'); " +
                "this release needs VellumPdf 2.x ($script:VellumPdfAssemblyVersion, token '$script:VellumPdfPublicKeyToken'). " +
                "Run './build.ps1 Restore' to refresh ./lib.")
        }
    }
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq $identity.Name } | Select-Object -First 1
    if ($loaded -and $loaded.Location -and ($loaded.GetName().FullName -ne $identity.FullName)) {
        throw ("PSVellumPDF: a different build of '$($identity.Name)' is already loaded in this session " +
            "($($loaded.GetName().FullName) from '$($loaded.Location)'). Start a new PowerShell session to load this version.")
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
