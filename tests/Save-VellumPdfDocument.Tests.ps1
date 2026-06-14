#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Save-VellumPdfDocument' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "save-doc-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Save-VellumPdfDocument'
    }

    It 'default: returns a FileInfo and disposes the document' {
        $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Default save.'
        $result = $doc | Save-VellumPdfDocument -Path $script:outPath

        $result | Should -BeOfType 'System.IO.FileInfo'
        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        # Document should be disposed; a follow-on Save attempt must throw.
        { $doc.Save((Join-Path $TestDrive 'after-dispose.pdf')) } | Should -Throw
    }

    Describe 'Feature 8a: -Force' {
        It 'creates a missing parent directory and writes the file' {
            $nestedPath = Join-Path $TestDrive 'auto-created' 'subdir' 'out.pdf'
            $parentDir  = [System.IO.Path]::GetDirectoryName($nestedPath)

            # Confirm directory does not exist yet.
            Test-Path $parentDir | Should -BeFalse

            New-VellumPdfDocument |
                Add-VellumPdfParagraph -Text 'Force-created dir.' |
                Save-VellumPdfDocument -Path $nestedPath -Force

            Test-Path $nestedPath | Should -BeTrue
            (Get-Item $nestedPath).Length | Should -BeGreaterThan 0

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($nestedPath)[0..4])
            $head | Should -Be '%PDF-'
        }

        It 'still throws on missing directory without -Force' {
            $noForcePath = Join-Path $TestDrive 'no-force-dir' 'out.pdf'
            $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x'
            try {
                { $doc | Save-VellumPdfDocument -Path $noForcePath } |
                    Should -Throw '*directory not found*'
            }
            finally { $doc.Dispose() }
        }

        It 'works when the directory already exists (no-op, no error)' {
            New-VellumPdfDocument |
                Add-VellumPdfParagraph -Text 'Dir already exists.' |
                Save-VellumPdfDocument -Path $script:outPath -Force

            Test-Path $script:outPath | Should -BeTrue
        }
    }

    Describe 'Feature 8b: -PassThru' {
        It 'returns the live Document (not a FileInfo) and the file exists on disk' {
            $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Initial.'
            $result = $doc | Save-VellumPdfDocument -Path $script:outPath -PassThru

            # Must return the Document, not a FileInfo.
            $result | Should -BeOfType 'VellumPdf.Layout.Document'

            # The file must have been written.
            Test-Path $script:outPath | Should -BeTrue
            (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
            $head | Should -Be '%PDF-'

            # The document is not disposed; PSVellumDisposed must not be set.
            $disposed = $result.PSObject.Properties['PSVellumDisposed']
            $disposed | Should -BeNullOrEmpty -Because '-PassThru must not dispose the document'

            # Caller is responsible for Dispose.
            $result.Dispose()
        }

        It '-PassThru returned document allows follow-on Add-VellumPdf* calls' {
            # Verify that the Document returned by -PassThru is still open and
            # accepts new content via Add-VellumPdf* (not disposed / not stamped).
            $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Initial.'
            $live = $doc | Save-VellumPdfDocument -Path $script:outPath -PassThru

            # A follow-on Add must succeed (document is still open).
            { $live | Add-VellumPdfParagraph -Text 'Follow-on paragraph.' | Out-Null } |
                Should -Not -Throw

            # Caller disposes.
            $live.Dispose()
        }

        It 'default (no -PassThru) disposes the document so a follow-on Add throws' {
            $doc = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Final.'
            $doc | Save-VellumPdfDocument -Path $script:outPath | Out-Null

            # After a normal save the document is disposed;
            # PSVellumDisposed is stamped and Assert-VellumPdfDocumentOpen throws.
            { $doc | Add-VellumPdfParagraph -Text 'After dispose.' } | Should -Throw
        }
    }
}
