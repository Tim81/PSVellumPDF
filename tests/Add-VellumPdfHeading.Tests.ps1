#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    if (-not (Test-Path $script:fontPath)) {
        throw "Test font asset not found at '$($script:fontPath)'. Cannot run embedded-font tests."
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfHeading' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "heading-$([guid]::NewGuid()).pdf"
    }

    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'Add-VellumPdfHeading'
    }

    It 'produces a non-empty PDF with valid %PDF- header' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Hello World' -Level 1 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF for each supported heading level' {
        foreach ($level in 1..6) {
            $path = Join-Path $TestDrive "heading-level$level-$([guid]::NewGuid()).pdf"
            New-VellumPdfDocument |
                Add-VellumPdfHeading -Text "Level $level Heading" -Level $level |
                Save-VellumPdfDocument -Path $path

            $head = [System.Text.Encoding]::ASCII.GetString(
                [System.IO.File]::ReadAllBytes($path)[0..4])
            $head | Should -Be '%PDF-'
        }
    }

    It 'produces a valid PDF with -Color as an RGB triple' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Red Heading' -Level 1 -Color 1,0,0 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        # Decompress every FlateDecode stream in the PDF and confirm that the
        # non-stroking RGB colour operator 'rg' appears (set by the colour style).
        # PDF content streams are compressed; we must inflate them to read operators.
        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $latin1 = [System.Text.Encoding]::Latin1.GetString($bytes)
        $foundRg = $false
        $flateStreams = [regex]::Matches($latin1, '(?s)/Filter\s*/FlateDecode[^>]*>>\s*stream\r?\n(.*?)endstream')
        foreach ($m in $flateStreams) {
            $raw = [System.Text.Encoding]::Latin1.GetBytes($m.Groups[1].Value)
            $ms = [System.IO.MemoryStream]::new($raw, 2, $raw.Length - 2)
            $ds = [System.IO.Compression.DeflateStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = [System.IO.MemoryStream]::new()
            $ds.CopyTo($out)
            $ds.Dispose()
            $text = [System.Text.Encoding]::Latin1.GetString($out.ToArray())
            if ($text -match '\brg\b') { $foundRg = $true; break }
        }
        $foundRg | Should -BeTrue -Because 'a coloured heading must emit an rg colour operator in the content stream'
    }

    It 'produces a valid PDF with -Color as a hex string' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Navy Heading' -Level 2 -Color '#003366' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $latin1 = [System.Text.Encoding]::Latin1.GetString($bytes)
        $foundRg = $false
        $flateStreams = [regex]::Matches($latin1, '(?s)/Filter\s*/FlateDecode[^>]*>>\s*stream\r?\n(.*?)endstream')
        foreach ($m in $flateStreams) {
            $raw = [System.Text.Encoding]::Latin1.GetBytes($m.Groups[1].Value)
            $ms = [System.IO.MemoryStream]::new($raw, 2, $raw.Length - 2)
            $ds = [System.IO.Compression.DeflateStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = [System.IO.MemoryStream]::new()
            $ds.CopyTo($out)
            $ds.Dispose()
            $text = [System.Text.Encoding]::Latin1.GetString($out.ToArray())
            if ($text -match '\brg\b') { $foundRg = $true; break }
        }
        $foundRg | Should -BeTrue -Because 'a coloured heading must emit an rg colour operator in the content stream'
    }

    It 'produces a valid PDF with -Color as a colour name' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Blue Heading' -Level 2 -Color 'blue' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'produces a valid PDF with -Color combined with -FontHandle' {
        $doc = New-VellumPdfDocument
        $handle = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $doc |
            Add-VellumPdfHeading -Text 'Coloured embedded heading' -Level 1 `
                -FontHandle $handle -Color 0,0.5,0 |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/FontFile2'

        # Decompress content streams to verify the colour operator is present.
        $bytes = [System.IO.File]::ReadAllBytes($script:outPath)
        $latin1 = [System.Text.Encoding]::Latin1.GetString($bytes)
        $foundRg = $false
        $streamMatches = [regex]::Matches($latin1, '(?s)/Filter\s*/FlateDecode[^>]*>>\s*stream\r?\n(.*?)endstream')
        foreach ($m in $streamMatches) {
            $raw2 = [System.Text.Encoding]::Latin1.GetBytes($m.Groups[1].Value)
            $ms = [System.IO.MemoryStream]::new($raw2, 2, $raw2.Length - 2)
            $ds = [System.IO.Compression.DeflateStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = [System.IO.MemoryStream]::new()
            $ds.CopyTo($out)
            $ds.Dispose()
            $text = [System.Text.Encoding]::Latin1.GetString($out.ToArray())
            if ($text -match '\brg\b') { $foundRg = $true; break }
        }
        $foundRg | Should -BeTrue -Because 'a coloured heading with FontHandle must emit an rg colour operator'
    }

    It 'produces a valid PDF with -Language and asserts /Lang in the output' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfHeading -Text 'Tagged heading' -Level 1 -Language 'en-US' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'

        $raw = [System.Text.Encoding]::Latin1.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath))
        $raw | Should -Match '/Lang'
    }

    It 'produces a valid PDF with -Language combined with -Color' {
        New-VellumPdfDocument -Tagged |
            Add-VellumPdfHeading -Text 'Deutsch' -Level 2 -Color '#cc0000' -Language 'de-DE' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'chains with other Add-VellumPdf* functions' {
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Chapter One' -Level 1 -Color 0,0,0.8 |
            Add-VellumPdfParagraph -Text 'Body text follows.' |
            Save-VellumPdfDocument -Path $script:outPath

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'returns the document for pipeline chaining (passthrough)' {
        $doc = New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Test' -Color 1,0,0
        $doc | Should -BeOfType 'VellumPdf.Layout.Document'
        $doc.Dispose()
    }
}
