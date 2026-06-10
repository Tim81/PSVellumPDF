#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Large mixed-content document' -Tag Stress {
    It 'paginates a 200+ page document with mixed content in reasonable time' {
        $outPath = Join-Path $TestDrive 'stress.pdf'
        $rows = @(
            [object[]]@('item', 'qty', 'state'),
            [object[]]@('widget', '7', 'ok')
        )

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $doc = New-VellumPdfDocument -Margin 60 |
            Set-VellumPdfHeader -Template 'Stress Document' -FontSize 9 |
            Set-VellumPdfFooter -Template 'Page {page} of {pages}' -FontSize 9
        foreach ($section in 1..240) {
            $doc = $doc |
                Add-VellumPdfHeading -Text "Section $section" -Level 1 -BookmarkTitle "Section $section" |
                Add-VellumPdfTable -Header 'Col1', 'Col2', 'Col3' -Row $rows -BorderWidth 0.5 |
                Add-VellumPdfList -Item 'alpha', 'beta', 'gamma' -Style OrderedDecimal
            foreach ($p in 1..12) {
                $doc = $doc | Add-VellumPdfParagraph -Text (
                    "Section $section paragraph ${p}: " +
                    'the quick brown fox jumps over the lazy dog and keeps running. ' * 4)
            }
        }
        $doc | Save-VellumPdfDocument -Path $outPath
        $sw.Stop()

        # Completes without hanging (generous bound; CI runners are slow).
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 120

        $bytes = [System.IO.File]::ReadAllBytes($outPath)
        [System.Text.Encoding]::ASCII.GetString($bytes[0..4]) | Should -Be '%PDF-'
        $bytes.Length | Should -BeGreaterThan 50kb

        # Count real page objects (not the /Pages tree node).
        $raw = [System.Text.Encoding]::Latin1.GetString($bytes)
        $pages = [regex]::Matches($raw, '/Type\s*/Page[^s]').Count
        $pages | Should -BeGreaterThan 200

        # All 240 bookmarks made it into the outline.
        [regex]::Matches($raw, '/Title').Count | Should -Be 240
    }
}
