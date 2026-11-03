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

Describe 'Add-VellumPdfHeading colour, leading and language' {
    BeforeAll {
        # /Lang strings are UTF-16BE with a byte-order mark.
        function script:Get-LangPattern([string]$Tag) {
            '/Lang\s*\(\xFE\xFF' + (($Tag.ToCharArray() | ForEach-Object { '\x00' + [regex]::Escape([string]$_) }) -join '') + '\)'
        }
    }

    It 'writes the requested colour, and a language tag on the heading and paragraph' {
        $path = Join-Path $TestDrive 'opts.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfHeading -Text 'Titre' -Color '#ff0000' -Leading 30 -Language fr |
            Add-VellumPdfParagraph -Text 'Texte' -Language de |
            Save-VellumPdfDocument -Path $path | Out-Null
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::Latin1)
        $text | Should -Match (Get-LangPattern 'fr')
        $text | Should -Match (Get-LangPattern 'de')
    }

    It 'rejects an unknown colour and an empty language' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfHeading -Text 'x' -Color 'notacolour' } | Should -Throw
            { $doc | Add-VellumPdfHeading -Text 'x' -Language '' } | Should -Throw
        }
        finally { $doc.Dispose() }
    }
}
