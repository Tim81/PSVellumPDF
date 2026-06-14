#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'New-VellumPdfDocument' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "new-doc-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'New-VellumPdfDocument'
    }

    Describe 'Feature 6: PdfUA1 conformance' {
        It 'accepts PdfUA1 in the -Conformance ValidateSet and produces a valid PDF' {
            New-VellumPdfDocument -Conformance PdfUA1 -Tagged |
                Add-VellumPdfParagraph -Text 'PDF/UA document.' |
                Save-VellumPdfDocument -Path $script:outPath

            Test-Path $script:outPath | Should -BeTrue
            (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
            $head | Should -Be '%PDF-'
        }

        It 'produces a valid PDF with PdfUA1 and -Language' {
            New-VellumPdfDocument -Conformance PdfUA1 -Tagged -Language 'en-US' |
                Add-VellumPdfHeading -Text 'Accessible Heading' -Level 1 |
                Add-VellumPdfParagraph -Text 'Accessible content.' |
                Save-VellumPdfDocument -Path $script:outPath

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
            $head | Should -Be '%PDF-'

            $raw = [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath))
            $raw | Should -Match '/Lang'
        }

        It 'rejects an invalid -Conformance value' {
            { New-VellumPdfDocument -Conformance NotAValue } | Should -Throw
        }
    }

    Describe 'Feature 7: custom page size in mm' {
        It 'produces a valid PDF with -PageWidthMm and -PageHeightMm' {
            New-VellumPdfDocument -PageWidthMm 200 -PageHeightMm 150 |
                Add-VellumPdfParagraph -Text 'Custom size.' |
                Save-VellumPdfDocument -Path $script:outPath

            Test-Path $script:outPath | Should -BeTrue
            (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
            $head | Should -Be '%PDF-'
        }

        It 'encodes the expected /MediaBox points for 200x150 mm' {
            # 1 mm = 2.834645669 pt; the library may emit fractional point values.
            # Expected width = 200 * 2.834645669 = 566.929... pt; height = 425.196... pt.
            # We extract the actual numbers from the /MediaBox entry and check
            # that they fall within 1 pt of the expected conversion.
            $widthExpect  = 200 * 2.834645669   # ~566.93
            $heightExpect = 150 * 2.834645669   # ~425.20

            New-VellumPdfDocument -PageWidthMm 200 -PageHeightMm 150 |
                Add-VellumPdfParagraph -Text 'MediaBox check.' |
                Save-VellumPdfDocument -Path $script:outPath

            $raw = [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath))

            # The PDF /MediaBox is [0 0 width height]; present as floats or ints.
            $raw | Should -Match '/MediaBox'

            # Extract the width and height values from /MediaBox [0 0 W H].
            $m = [regex]::Match($raw, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)')
            $m.Success | Should -BeTrue -Because 'expected /MediaBox [0 0 W H] to be parseable'

            $actualW = [double]$m.Groups[1].Value
            $actualH = [double]$m.Groups[2].Value

            [math]::Abs($actualW - $widthExpect)  | Should -BeLessThan 1 `
                -Because "MediaBox width should be within 1 pt of $widthExpect (200 mm)"
            [math]::Abs($actualH - $heightExpect) | Should -BeLessThan 1 `
                -Because "MediaBox height should be within 1 pt of $heightExpect (150 mm)"
        }

        It 'encodes the expected /MediaBox points for A5 equivalent (148x210 mm)' {
            # Standard A5 is 148 x 210 mm.
            $widthPt  = 148 * 2.834645669
            $heightPt = 210 * 2.834645669

            New-VellumPdfDocument -PageWidthMm 148 -PageHeightMm 210 |
                Add-VellumPdfParagraph -Text 'A5 custom.' |
                Save-VellumPdfDocument -Path $script:outPath

            $raw = [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath))

            $m = [regex]::Match($raw, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)')
            $m.Success | Should -BeTrue -Because 'expected /MediaBox [0 0 W H] to be parseable'
            [math]::Abs([double]$m.Groups[1].Value - $widthPt)  | Should -BeLessThan 1 `
                -Because 'MediaBox width should be within 1 pt of 148 mm'
            [math]::Abs([double]$m.Groups[2].Value - $heightPt) | Should -BeLessThan 1 `
                -Because 'MediaBox height should be within 1 pt of 210 mm'
        }

        It 'throws when only -PageWidthMm is supplied' {
            { New-VellumPdfDocument -PageWidthMm 200 |
                Add-VellumPdfParagraph -Text 'x' |
                Save-VellumPdfDocument -Path $script:outPath
            } | Should -Throw '*-PageWidthMm and -PageHeightMm must be supplied together*'
        }

        It 'throws when only -PageHeightMm is supplied' {
            { New-VellumPdfDocument -PageHeightMm 150 |
                Add-VellumPdfParagraph -Text 'x' |
                Save-VellumPdfDocument -Path $script:outPath
            } | Should -Throw '*-PageWidthMm and -PageHeightMm must be supplied together*'
        }

        It 'throws when -PageWidthMm/-PageHeightMm are combined with -PageSize' {
            { New-VellumPdfDocument -PageWidthMm 200 -PageHeightMm 150 -PageSize A4 |
                Add-VellumPdfParagraph -Text 'x' |
                Save-VellumPdfDocument -Path $script:outPath
            } | Should -Throw '*mutually exclusive*'
        }

        It 'rejects a -PageWidthMm below the valid range' {
            { New-VellumPdfDocument -PageWidthMm 0 -PageHeightMm 100 } | Should -Throw
        }

        It 'rejects a -PageHeightMm below the valid range' {
            { New-VellumPdfDocument -PageWidthMm 100 -PageHeightMm 0 } | Should -Throw
        }

        It 'rejects a page larger than the 5080 mm (14400 pt) implementation limit' {
            { New-VellumPdfDocument -PageWidthMm 5081 -PageHeightMm 100 } | Should -Throw
            { New-VellumPdfDocument -PageWidthMm 100 -PageHeightMm 5081 } | Should -Throw
        }

        It 'accepts a page at the 5080 mm ceiling and emits a MediaBox near 14400 pt' {
            New-VellumPdfDocument -PageWidthMm 5080 -PageHeightMm 5080 |
                Add-VellumPdfParagraph -Text 'Max page.' |
                Save-VellumPdfDocument -Path $script:outPath

            $raw = [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($script:outPath))
            $m = [regex]::Match($raw, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)')
            $m.Success | Should -BeTrue
            [math]::Abs([double]$m.Groups[1].Value - 14400) | Should -BeLessThan 1
            [math]::Abs([double]$m.Groups[2].Value - 14400) | Should -BeLessThan 1
        }
    }
}
