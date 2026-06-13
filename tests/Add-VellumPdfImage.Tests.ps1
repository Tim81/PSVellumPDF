#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    # A verified valid 1x1 grayscale PNG produced by the VellumPdf PngImageLoader.
    # Decoded bytes were confirmed to load successfully via PngImageLoader::Load().
    $script:Png1x1Base64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAAEElEQVR4nGI4AQAAAP//AwAAygDJDlGudwAAAABJRU5ErkJggg=='

    $script:PngPath = Join-Path $TestDrive 'sample.png'
    [System.IO.File]::WriteAllBytes(
        $script:PngPath,
        [System.Convert]::FromBase64String($script:Png1x1Base64)
    )
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfImage' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "img-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfImage'
    }

    It 'produces a non-empty PDF with valid %PDF- header for a PNG image' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:PngPath |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Width, Height, Alignment, and AltText set' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:PngPath `
                -Width 100 -Height 100 -Alignment Center -AltText 'Accessibility text' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Right alignment' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:PngPath -Alignment Right |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with Width-only set (no Height)' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:PngPath -Width 200 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with AltText for accessibility' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:PngPath -AltText 'Logo image' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'throws a clear error for an unsupported file extension' {
        $badPath = Join-Path $TestDrive 'bad.webp'
        [System.IO.File]::WriteAllBytes($badPath, [byte[]](0, 1, 2, 3))
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $badPath } |
            Should -Throw -ExpectedMessage '*unsupported image extension*'
    }

    It 'routes .jp2 to the JPEG 2000 loader (load failure, not unsupported-extension)' {
        # A valid JPEG 2000 asset is impractical to vendor; feeding garbage with
        # a .jp2 extension proves the extension reaches JpxImageLoader, because
        # the error is the loader rejecting the bytes rather than the cmdlet
        # rejecting the extension.
        $jp2 = Join-Path $TestDrive 'sample.jp2'
        [System.IO.File]::WriteAllBytes($jp2, [byte[]](1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))
        # A "failed to load" error (not "unsupported image extension") means the
        # .jp2 extension was routed to JpxImageLoader, which then rejected the bytes.
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $jp2 } |
            Should -Throw -ExpectedMessage '*failed to load*'
    }

    It 'routes .jb2 to the JBIG2 loader (load failure, not unsupported-extension)' {
        $jb2 = Join-Path $TestDrive 'sample.jb2'
        [System.IO.File]::WriteAllBytes($jb2, [byte[]](1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))
        # A "failed to load" error (not "unsupported image extension") means the
        # .jb2 extension was routed to Jbig2ImageLoader, which then rejected the bytes.
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $jb2 } |
            Should -Throw -ExpectedMessage '*failed to load*'
    }

    It 'throws a clear error when the file does not exist' {
        $missing = Join-Path $TestDrive 'nonexistent.png'
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $missing } |
            Should -Throw -ExpectedMessage '*file not found*'
    }

    It 'chains with other Add-VellumPdf* functions' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Image Report' -Level 1 |
            Add-VellumPdfImage -Path $script:PngPath -Width 50 -Height 50 |
            Add-VellumPdfParagraph -Text 'Figure 1: sample image.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the Document instance for pipeline passthrough' {
        $doc = New-VellumPdfDocument | Add-VellumPdfImage -Path $script:PngPath
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }
}
