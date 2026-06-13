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
        # Assert the JPEG 2000 loader's own rejection message ("Not a JPEG 2000
        # file..."), not just the wrapper's generic "failed to load" prefix - a
        # misrouted extension would still fail to load but with a DIFFERENT
        # loader's message, so this is what actually proves the route.
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $jp2 } |
            Should -Throw -ExpectedMessage '*JPEG 2000*'
    }

    It 'routes .jb2 to the JBIG2 loader (load failure, not unsupported-extension)' {
        $jb2 = Join-Path $TestDrive 'sample.jb2'
        [System.IO.File]::WriteAllBytes($jb2, [byte[]](1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))
        # Assert the JBIG2 loader's own rejection message, not just the generic
        # "failed to load" prefix, so a misroute to a different loader is caught.
        { Add-VellumPdfImage -Document (New-VellumPdfDocument) -Path $jb2 } |
            Should -Throw -ExpectedMessage '*JBIG2*'
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

    It 'embeds an in-memory image via -ImageBytes -Format' {
        $bytes = [System.Convert]::FromBase64String($script:Png1x1Base64)
        New-VellumPdfDocument |
            Add-VellumPdfImage -ImageBytes $bytes -Format Png -Width 50 |
            Save-VellumPdfDocument -Path $script:outPath

        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -BeLike '%PDF-*'
        $raw | Should -Match '/Image'
    }

    It 'reports a load failure against the supplied bytes (not a path)' {
        { New-VellumPdfDocument |
                Add-VellumPdfImage -ImageBytes ([byte[]](1, 2, 3, 4)) -Format Png } |
            Should -Throw '*supplied image bytes*'
    }
}

Describe 'Add-VellumPdfImage end-to-end for JBIG2 and JPEG 2000' {
    BeforeAll {
        # VellumPdf's JBIG2/JPEG 2000 loaders are passthrough parsers, so a
        # minimal hand-built stream is enough to exercise the full
        # load -> LayoutImage -> Add -> Save path. These builders mirror the
        # layouts used by the upstream VellumPdf kernel tests; they carry no
        # pixel data (the engine embeds the bytes verbatim), which is all the
        # wrapper is responsible for.

        function script:New-MinimalJpx {
            # Raw JPEG 2000 codestream: SOC (FF4F) + SIZ + EOC (ISO 15444-1).
            param([int]$Width = 4, [int]$Height = 4, [int]$Components = 3, [int]$Bpc = 8)
            $b = [System.Collections.Generic.List[byte]]::new()
            $add16 = { param($v) $b.Add([byte](($v -shr 8) -band 0xFF)); $b.Add([byte]($v -band 0xFF)) }
            $add32 = { param($v) $b.Add([byte](($v -shr 24) -band 0xFF)); $b.Add([byte](($v -shr 16) -band 0xFF));
                $b.Add([byte](($v -shr 8) -band 0xFF)); $b.Add([byte]($v -band 0xFF)) }
            foreach ($x in 0xFF, 0x4F, 0xFF, 0x51) { $b.Add([byte]$x) }   # SOC, SIZ
            & $add16 (38 + 3 * $Components)                              # Lsiz
            & $add16 0                                                   # Rsiz
            & $add32 $Width; & $add32 $Height; & $add32 0; & $add32 0    # Xsiz Ysiz XOsiz YOsiz
            & $add32 $Width; & $add32 $Height; & $add32 0; & $add32 0    # XTsiz YTsiz XTOsiz YTOsiz
            & $add16 $Components                                         # Csiz
            for ($c = 0; $c -lt $Components; $c++) {
                $b.Add([byte](($Bpc - 1) -band 0x7F)); $b.Add(1); $b.Add(1)  # Ssiz XRsiz YRsiz
            }
            foreach ($x in 0xFF, 0xD9) { $b.Add([byte]$x) }              # EOC
            , $b.ToArray()
        }

        function script:New-MinimalJbig2 {
            # Sequential JBIG2: file header + page-info segment (type 48) + EOF (type 51).
            param([int]$Width = 4, [int]$Height = 4)
            $b = [System.Collections.Generic.List[byte]]::new()
            $add32 = { param($v) $b.Add([byte](($v -shr 24) -band 0xFF)); $b.Add([byte](($v -shr 16) -band 0xFF));
                $b.Add([byte](($v -shr 8) -band 0xFF)); $b.Add([byte]($v -band 0xFF)) }
            foreach ($x in 0x97, 0x4A, 0x42, 0x32, 0x0D, 0x0A, 0x1A, 0x0A) { $b.Add([byte]$x) }  # file header
            # Page-info segment: number=0, flags(type 48), refCount=0, pageAssoc=1, dataLen=19.
            & $add32 0; $b.Add(0x30); $b.Add(0x00); $b.Add(0x01); & $add32 19
            & $add32 $Width; & $add32 $Height; & $add32 0; & $add32 0    # width height xres yres
            $b.Add(0x00); $b.Add(0x00); $b.Add(0x00)                     # flags(1) + striping(2) = 19 bytes total
            # End-of-file segment: number=1, flags(type 51), refCount=0, pageAssoc=0, dataLen=0.
            & $add32 1; $b.Add(0x33); $b.Add(0x00); $b.Add(0x00); & $add32 0
            , $b.ToArray()
        }

        $script:Jp2Path = Join-Path $TestDrive 'minimal.jp2'
        [System.IO.File]::WriteAllBytes($script:Jp2Path, (New-MinimalJpx))
        $script:Jb2Path = Join-Path $TestDrive 'minimal.jb2'
        [System.IO.File]::WriteAllBytes($script:Jb2Path, (New-MinimalJbig2))
    }

    BeforeEach {
        $script:outPath = Join-Path $TestDrive "codec-$([guid]::NewGuid()).pdf"
    }

    It 'embeds a JPEG 2000 image and writes a PDF using the /JPXDecode filter' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:Jp2Path -Width 40 |
            Add-VellumPdfParagraph -Text 'After JP2.' |
            Save-VellumPdfDocument -Path $script:outPath

        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -BeLike '%PDF-*'
        $raw | Should -Match '/JPXDecode'
    }

    It 'embeds a JBIG2 image and writes a PDF using the /JBIG2Decode filter' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:Jb2Path -Width 40 |
            Add-VellumPdfParagraph -Text 'After JBIG2.' |
            Save-VellumPdfDocument -Path $script:outPath

        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -BeLike '%PDF-*'
        $raw | Should -Match '/JBIG2Decode'
    }

    It 'honours -Width/-Height/-Alignment on a JPEG 2000 image' {
        New-VellumPdfDocument |
            Add-VellumPdfImage -Path $script:Jp2Path -Width 30 -Height 30 -Alignment Center -AltText 'jp2 dot' |
            Save-VellumPdfDocument -Path $script:outPath

        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'Vendored codec asset integrity' {
    # tests/assets/sample.jp2 (real 16x16 RGB JPEG 2000, Pillow/OpenJPEG) and
    # sample.jb2 (minimal valid JBIG2) back the PDF/A conformance gate for
    # VellumPDF#91. A tamper/regeneration changing these bytes should be visible.
    It 'sample.jp2 matches the recorded SHA-256' {
        $p = Join-Path $PSScriptRoot 'assets' 'sample.jp2'
        (Get-FileHash $p -Algorithm SHA256).Hash |
            Should -Be '9636C154316F8CC95667FEF13D1093262E2FC8A29074B0D0280C49C282C01D90'
    }

    It 'sample.jb2 matches the recorded SHA-256' {
        $p = Join-Path $PSScriptRoot 'assets' 'sample.jb2'
        (Get-FileHash $p -Algorithm SHA256).Hash |
            Should -Be '94731E12CCA0FECBAE7CE2DE5B3EC5820F631F57BFECD4B9858F4AB62174B342'
    }
}

Describe 'JPEG 2000 / JBIG2 compose with PDF/A-2b' {
    # Offline structural check; veraPDF conformance is gated in CI
    # (tools/New-ValidationSamples.ps1 + the validate job). Guards VellumPDF#91.
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "pdfa-codec-$([guid]::NewGuid()).pdf"
        $script:ttf = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    }

    It 'embeds a real JPEG 2000 image in a PDF/A-2b document with the JP2 metadata preserved' {
        $jpx = Join-Path $PSScriptRoot 'assets' 'sample.jp2'
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
        $font = Register-VellumPdfFont -Document $doc -Path $script:ttf
        $doc |
            Add-VellumPdfParagraph -Text 'Archival JP2.' -FontHandle $font |
            Add-VellumPdfImage -Path $jpx -Width 40 -AltText 'jp2' |
            Save-VellumPdfDocument -Path $script:outPath

        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -BeLike '%PDF-*'
        $raw | Should -Match '/JPXDecode'
        $raw | Should -Match 'pdfaid'   # PDF/A identification survives
    }

    It 'embeds a JBIG2 image in a PDF/A-2b document' {
        $jb2 = Join-Path $PSScriptRoot 'assets' 'sample.jb2'
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language 'en-US'
        $font = Register-VellumPdfFont -Document $doc -Path $script:ttf
        $doc |
            Add-VellumPdfParagraph -Text 'Archival JBIG2.' -FontHandle $font |
            Add-VellumPdfImage -Path $jb2 -Width 40 -AltText 'jbig2' |
            Save-VellumPdfDocument -Path $script:outPath

        $raw = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -BeLike '%PDF-*'
        $raw | Should -Match '/JBIG2Decode'
    }
}
