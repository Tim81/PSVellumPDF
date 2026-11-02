#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Export-VellumPdfImage writes compressed images as files other tools can open: CCITT fax data in a TIFF,
# JBIG2 segments (with their shared "globals") as a standalone JBIG2 file, JPEG and JPEG 2000 as they are.

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:assets = Join-Path $PSScriptRoot 'assets'
    $script:render = [bool]((Get-Command pdftoppm -ErrorAction SilentlyContinue) -and (Get-Command convert -ErrorAction SilentlyContinue) -and ((& convert -version 2>&1 | Out-String) -match 'ImageMagick'))   # Windows has its own unrelated convert.exe

    # A PDF whose only content is the image, placed 1 point per pixel so that a 72 dpi render is the image.
    function script:New-ImagePdf([string]$ImagePath, [string]$Name, [int]$Width, [int]$Height) {
        $pdf = Join-Path $TestDrive "$Name.pdf"
        $mmW = $Width * 25.4 / 72
        $mmH = $Height * 25.4 / 72
        New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -PageWidthMm $mmW -PageHeightMm $mmH |
            Add-VellumPdfPageImage $ImagePath -X 0 -Y 0 -Width $Width -AltText 'sample' |
            Save-VellumPdfDocument -Path $pdf | Out-Null
        $pdf
    }
    # Renders page 1 to a grey PNG at the given resolution and returns its path.
    function script:Convert-PdfToPng([string]$Pdf, [int]$Dpi) {
        $base = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & pdftoppm -r $Dpi -gray -aa no -aaVector no -png $Pdf $base
        (Get-ChildItem "$base*.png" | Select-Object -First 1).FullName
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'CCITT fax images' {
    It 'are written as a TIFF that renders pixel for pixel like the PDF (<Sample>)' -ForEach @(
        @{ Sample = 'sample-g4.tif'; Compression = 4 }
        @{ Sample = 'sample-g3.tif'; Compression = 3 }
    ) {
        $source = New-ImagePdf (Join-Path $script:assets $Sample) "ccitt-$Compression" 64 48
        $out = Join-Path $TestDrive "out-$Compression"
        $files = @(Export-VellumPdfImage $source -DestinationPath $out)
        $files.Count | Should -Be 1
        $files[0].Extension | Should -Be '.tif'
        $files[0].Encoding | Should -Be 'CcittFax'
        $files[0].Width | Should -Be 64
        $files[0].BitsPerComponent | Should -Be 1
        $bytes = [System.IO.File]::ReadAllBytes($files[0].FullName)
        [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2) | Should -Be 'II'
        [BitConverter]::ToUInt16($bytes, 2) | Should -Be 42

        if ($script:render) {
            # Render the PDF at 4x and compare with the TIFF enlarged by pixel replication: identical or the polarity is wrong.
            $reference = Convert-PdfToPng $source 288
            $exported = Join-Path $TestDrive "export-$Compression.png"
            & convert $files[0].FullName -colorspace Gray -filter point -resize 400% $exported
            (& compare -metric AE -fuzz 20% $reference $exported null: 2>&1) | Should -Be '0'
        }
    }

    It 'skips byte-aligned Group 4 data, which a TIFF cannot describe' {
        [PSVellumPDF.Interop.ImageContainers]::BuildCcittTiff(64, 48, -1, $true, $true, [byte[]]@(1, 2, 3)) | Should -BeNullOrEmpty
        [PSVellumPDF.Interop.ImageContainers]::BuildCcittTiff(0, 48, -1, $true, $false, [byte[]]@(1)) | Should -BeNullOrEmpty
    }

    It 'writes the Group 3 options into the TIFF tags' {
        $tiff = [PSVellumPDF.Interop.ImageContainers]::BuildCcittTiff(64, 48, 4, $false, $true, [byte[]]@(1, 2, 3))
        $count = [BitConverter]::ToUInt16($tiff, 8)
        $tags = @{}
        for ($i = 0; $i -lt $count; $i++) { $o = 10 + 12 * $i; $tags[[int][BitConverter]::ToUInt16($tiff, $o)] = [BitConverter]::ToUInt16($tiff, $o + 8) }
        $tags[259] | Should -Be 3          # Group 3
        $tags[262] | Should -Be 0          # WhiteIsZero for BlackIs1 = false
        [BitConverter]::ToUInt32($tiff, 10 + 12 * ($tags.Keys | Sort-Object).IndexOf(292) + 8) | Should -Be 5   # 2-D coding + fill bits
    }
}

Describe 'JBIG2 images' {
    It 'are written as a standard sequential file: ID string, flags, page count, then the segments' {
        $source = New-ImagePdf (Join-Path $script:assets 'sample.jb2') 'jbig2' 16 16
        $files = @(Export-VellumPdfImage $source -DestinationPath (Join-Path $TestDrive 'out-jbig2'))
        $files.Count | Should -Be 1
        $files[0].Extension | Should -Be '.jb2'
        $files[0].Encoding | Should -Be 'Jbig2'
        $bytes = [System.IO.File]::ReadAllBytes($files[0].FullName)
        [System.BitConverter]::ToString($bytes, 0, 8) | Should -Be '97-4A-42-32-0D-0A-1A-0A'
        $bytes[8] | Should -Be 1
        [System.BitConverter]::ToString($bytes, 9, 4) | Should -Be '00-00-00-01'
        # page information (48), then the end-of-page (49) and end-of-file (51) segments
        $bytes[13 + 4] -band 0x3F | Should -Be 48
        $bytes[$bytes.Length - 11 - 11 + 4] -band 0x3F | Should -Be 49
        $bytes[$bytes.Length - 11 + 4] -band 0x3F | Should -Be 51
        # VellumPdf's own JBIG2 loader reads only the 8-byte ID string and then expects segments, so this standard
        # file (with flags and a page count) cannot be embedded again by Add-VellumPdfPageImage; the segments are
        # the ones the source PDF stored, so other JBIG2 tools (jbig2dec, pdfimages -jbig2) open the file.
    }

    It 'joins shared segments, page segments and end segments in order' {
        # Global segment 0 (page association 0) and page segments 1 and 2 (page association 1), without EOP/EOF.
        $segment = { param($n, $type, $page, [byte[]]$data)
            $h = [System.Collections.Generic.List[byte]]::new()
            $h.AddRange([byte[]]@(0, 0, 0, $n, $type, 0, $page, 0, 0, 0, $data.Length)); $h.AddRange($data); , $h.ToArray() }
        $be32 = { param([byte[]]$b, [int]$o) ([uint32]$b[$o] -shl 24) -bor ([uint32]$b[$o + 1] -shl 16) -bor ([uint32]$b[$o + 2] -shl 8) -bor [uint32]$b[$o + 3] }
        $globals = & $segment 0 0 0 ([byte[]]@(9, 9))
        $page = [byte[]]((& $segment 1 48 1 ([byte[]]@(1, 2, 3))) + (& $segment 2 38 1 ([byte[]]@(4))))
        $file = [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File($page, $globals)
        [System.BitConverter]::ToString($file, 0, 8) | Should -Be '97-4A-42-32-0D-0A-1A-0A'
        $file[8] | Should -Be 1                                   # sequential, page count known
        (& $be32 $file 9) | Should -Be 1
        # Segment types in file order after the 13-byte header: 0 (global), 48, 38, then the added 49 and 51.
        $types = [System.Collections.Generic.List[int]]::new()
        $i = 13
        while ($i -lt $file.Length) {
            $types.Add($file[$i + 4] -band 0x3F)
            $length = & $be32 $file ($i + 7)
            $i += 11 + $length
        }
        $types | Should -Be 0, 48, 38, 49, 51
        $i | Should -Be $file.Length
    }

    It 'does not add end segments twice, and refuses data it cannot parse' {
        $end = [byte[]]@(0, 0, 0, 5, 49, 0, 1, 0, 0, 0, 0, 0, 0, 0, 6, 51, 0, 0, 0, 0, 0, 0)
        $page = [byte[]]@(0, 0, 0, 1, 38, 0, 1, 0, 0, 0, 1, 7) + $end
        $file = [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File($page, $null)
        $file.Length | Should -Be (13 + 12 + 22)
        [PSVellumPDF.Interop.ImageContainers]::BuildJbig2File([byte[]]@(1, 2, 3), $null) | Should -BeNullOrEmpty
    }
}

Describe 'Other images' {
    It 'writes a JPEG exactly as stored, a PNG for raw samples, and describes each file' {
        $jpeg = New-ImagePdf (Join-Path $script:assets 'photo.jpg') 'jpeg' 24 16
        $png = New-ImagePdf (Join-Path $script:assets 'gray16.png') 'png16' 16 16
        $jpegFile = @(Export-VellumPdfImage $jpeg -DestinationPath (Join-Path $TestDrive 'o-jpeg'))[0]
        $jpegFile.Extension | Should -Be '.jpg'
        $jpegFile.Encoding | Should -Be 'Jpeg'
        [System.IO.File]::ReadAllBytes($jpegFile.FullName) | Should -Be ([System.IO.File]::ReadAllBytes((Join-Path $script:assets 'photo.jpg')))
        $pngFile = @(Export-VellumPdfImage $png -DestinationPath (Join-Path $TestDrive 'o-png'))[0]
        $pngFile.Extension | Should -Be '.png'
        $pngFile.Page | Should -Be 1
        $pngFile.IsInline | Should -BeFalse
        $pngFile.ComponentCount | Should -BeGreaterThan 0
        $pngFile.PSObject.Properties.Name | Should -Contain 'HasSoftMask'
    }

    It 'writes JPEG 2000 as a .jp2 file' {
        $source = New-ImagePdf (Join-Path $script:assets 'sample.jp2') 'jp2' 16 16
        $file = @(Export-VellumPdfImage $source -DestinationPath (Join-Path $TestDrive 'o-jp2'))[0]
        $file.Extension | Should -BeIn '.jp2', '.j2k'
        $file.Encoding | Should -Be 'Jpx'
    }
}
