#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    # Outline titles are written as UTF-16BE literal strings; build the needle
    # the same way to assert a title really landed in the file.
    function Get-Utf16BeNeedle([string]$Text) {
        [System.Text.Encoding]::Latin1.GetString(
            [System.Text.Encoding]::BigEndianUnicode.GetBytes($Text))
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Outline (bookmarks) and link annotations' {
    BeforeAll {
        $script:outPath = Join-Path $TestDrive 'outline-links.pdf'
        $link = New-VellumPdfTextRun -Text 'VellumPDF on GitHub' -LinkUri 'https://github.com/Tim81/VellumPDF'

        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Chapter 1' -Level 1 -BookmarkTitle 'Chapter 1' |
            Add-VellumPdfHeading -Text 'Section 1.1' -Level 2 -BookmarkTitle 'Section 1.1' |
            Add-VellumPdfHeading -Text 'Subsection 1.1.1' -Level 3 -BookmarkTitle 'Subsection 1.1.1' |
            Add-VellumPdfHeading -Text 'Chapter 2' -Level 1 -BookmarkTitle 'Chapter 2' |
            Add-VellumPdfParagraph -Run $link |
            Save-VellumPdfDocument -Path $script:outPath

        $script:raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
    }

    It 'writes a document outline tree' {
        $script:raw | Should -Match '/Outlines'
        $script:raw | Should -Match '/First'
        $script:raw | Should -Match '/Next'
        $script:raw | Should -Match '/Parent'
    }

    It 'writes one outline entry per bookmarked heading' {
        [regex]::Matches($script:raw, '/Title').Count | Should -Be 4
    }

    It 'stores the bookmark titles (UTF-16BE)' {
        foreach ($title in 'Chapter 1', 'Section 1.1', 'Subsection 1.1.1', 'Chapter 2') {
            $script:raw.Contains((Get-Utf16BeNeedle $title)) | Should -BeTrue -Because "outline should contain '$title'"
        }
    }

    It 'writes a link annotation with a URI action for -LinkUri runs' {
        $script:raw | Should -Match '/Annots'
        $script:raw | Should -Match '/URI'
        $script:raw | Should -Match 'github\.com/Tim81/VellumPDF'
    }
}
