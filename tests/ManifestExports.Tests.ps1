#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    $script:manifestPath = Join-Path $script:root 'PSVellumPDF.psd1'
    Import-Module $script:manifestPath -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'exports exactly the functions defined in Public/' {
        $manifest = Import-PowerShellDataFile $script:manifestPath
        $public = Get-ChildItem (Join-Path $script:root 'Public') -Filter '*.ps1' | ForEach-Object BaseName
        $manifest.FunctionsToExport | Sort-Object | Should -Be ($public | Sort-Object)
    }

    It 'exports every function it lists' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $manifest = Import-PowerShellDataFile $script:manifestPath
        foreach ($name in $manifest.FunctionsToExport) { $exported | Should -Contain $name }
    }
}
