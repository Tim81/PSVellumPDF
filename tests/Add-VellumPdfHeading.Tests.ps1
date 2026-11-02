#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfHeading level mapping' {
    It 'tags -Level 1..3 as H1..H3 (the engine counts levels from 0)' {
        $path = Join-Path $TestDrive 'levels.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfHeading -Text 'One' -Level 1 |
            Add-VellumPdfHeading -Text 'Two' -Level 2 |
            Add-VellumPdfHeading -Text 'Three' -Level 3 |
            Save-VellumPdfDocument -Path $path | Out-Null
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::Latin1)
        ([regex]::Matches($text, '/S\s*/H(\d)') | ForEach-Object { $_.Groups[1].Value }) -join ',' | Should -Be '1,2,3'
        $text | Should -Not -Match '/S\s*/H4'
    }

    It 'defaults to H1' {
        $path = Join-Path $TestDrive 'default.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfHeading -Text 'Top' |
            Save-VellumPdfDocument -Path $path | Out-Null
        [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::Latin1) | Should -Match '/S\s*/H1'
    }
}
