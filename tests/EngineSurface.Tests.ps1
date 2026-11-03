#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Guards the seam between this module and the VellumPdf engine. The module names
# engine types as [VellumPdf.X.Y] and calls static members as [VellumPdf.X.Y]::Member;
# this test reads the module's own source and fails if any of them no longer exists,
# so a VellumPdf upgrade that removes or renames something is caught here, by name,
# instead of surfacing as a runtime error in one rarely used cmdlet.

BeforeDiscovery {
    $root = Split-Path $PSScriptRoot -Parent
    $files = @(Get-ChildItem (Join-Path $root 'Public'), (Join-Path $root 'Private') -Filter '*.ps1') + @(Get-Item (Join-Path $root 'PSVellumPDF.psm1'))
    $pattern = '\[(?<type>(?:VellumPdf|PSVellumPDF)\.[A-Za-z0-9_.]+?)(?<array>\[\])?\](?:::(?<member>[A-Za-z_]\w*))?'
    $seenTypes = [System.Collections.Generic.SortedSet[string]]::new()
    $seenMembers = [System.Collections.Generic.SortedSet[string]]::new()
    foreach ($f in $files) {
        foreach ($line in Get-Content $f.FullName) {
            if ($line -match '^\s*#') { continue }   # skip comment lines
            foreach ($m in [regex]::Matches($line, $pattern)) {
                [void]$seenTypes.Add($m.Groups['type'].Value)
                if ($m.Groups['member'].Success) { [void]$seenMembers.Add("$($m.Groups['type'].Value)::$($m.Groups['member'].Value)") }
            }
        }
    }
    $typeCases = @($seenTypes | ForEach-Object { @{ Name = $_ } })
    $memberCases = @($seenMembers | ForEach-Object { @{ Spec = $_ } })
    # The scan itself must work, or this whole file would pass vacuously.
    if ($typeCases.Count -lt 40 -or $memberCases.Count -lt 40) {
        throw "EngineSurface scan found only $($typeCases.Count) types / $($memberCases.Count) members; the pattern is broken."
    }
}

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Engine surface used by the module' {
    It 'type [<Name>] exists' -ForEach $typeCases {
        $resolved = $Name -as [type]
        $resolved | Should -Not -BeNullOrEmpty -Because "the module refers to [$Name]"
    }

    It 'static member <Spec> exists' -ForEach $memberCases {
        $typeName, $memberName = $Spec -split '::'
        $type = $typeName -as [type]
        $found = if ($memberName -eq 'new') { @($type.GetConstructors()).Count }
        else { @($type.GetMember($memberName, [System.Reflection.BindingFlags]'Public,Static,FlattenHierarchy')).Count }
        $found | Should -BeGreaterThan 0 -Because "[$typeName]::$memberName is used by the module"
    }

    It 'the engine assemblies have the identity the loader demands' {
        foreach ($asm in 'VellumPdf.Kernel', 'VellumPdf.Layout', 'VellumPdf.Signing', 'VellumPdf.Barcodes', 'VellumPdf.Conformance', 'VellumPdf.Reader', 'VellumPdf.Fonts.Standard14') {
            $name = [System.AppDomain]::CurrentDomain.GetAssemblies().GetName() | Where-Object Name -EQ $asm
            $name.Version | Should -Be ([version]'2.0.0.0')
            [System.BitConverter]::ToString($name.GetPublicKeyToken()).Replace('-', '').ToLowerInvariant() | Should -Be 'b2757187a6d18ae5'
        }
    }
}
