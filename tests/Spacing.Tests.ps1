#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    # Inflates every FlateDecode content stream so tests can read operators.
    function Get-PdfContentText {
        param([string]$Path)
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $text = [System.Text.Encoding]::Latin1.GetString($bytes)
        $sb = [System.Text.StringBuilder]::new()
        foreach ($m in [regex]::Matches($text, '(?<!end)stream\r?\n')) {
            $start = $m.Index + $m.Length
            $end = $text.IndexOf('endstream', $start)
            $slice = [byte[]]$bytes[($start + 2)..($end - 1)]   # skip the 2-byte zlib header
            try {
                $ds = [System.IO.Compression.DeflateStream]::new(
                    [System.IO.MemoryStream]::new($slice), [System.IO.Compression.CompressionMode]::Decompress)
                $reader = [System.IO.StreamReader]::new($ds, [System.Text.Encoding]::Latin1)
                [void]$sb.AppendLine($reader.ReadToEnd())
            }
            catch { Write-Verbose "not a flate stream: $_" }   # trailing adler32 / non-content streams
        }
        $sb.ToString()
    }

    # Y coordinate of the first text object that shows $Needle.
    function Get-TextY {
        param([string]$Content, [string]$Needle)
        $m = [regex]::Match($Content, "1 0 0 1 [\d.]+ ([\d.]+) Tm\s*\(" + [regex]::Escape($Needle) + "\)")
        if (-not $m.Success) { throw "text '$Needle' not found in content" }
        [double]$m.Groups[1].Value
    }

    function Save-TwoBlock {
        param([scriptblock]$First, [string]$Name)
        $path = Join-Path $TestDrive "$Name.pdf"
        $doc = New-VellumPdfDocument
        $doc = & $First $doc
        $doc | Add-VellumPdfParagraph -Text 'Second' | Save-VellumPdfDocument -Path $path | Out-Null
        Get-PdfContentText $path
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe '-MarginBottom adds space before the next element' {
    It 'paragraph: 40pt of bottom margin moves the next paragraph down 40pt' {
        $base = Save-TwoBlock -Name p0 -First { param($d) $d | Add-VellumPdfParagraph -Text 'First' -MarginBottom 0 }
        $spaced = Save-TwoBlock -Name p40 -First { param($d) $d | Add-VellumPdfParagraph -Text 'First' -MarginBottom 40 }
        (Get-TextY $base 'Second') - (Get-TextY $spaced 'Second') | Should -BeExactly 40
    }

    It 'heading: bottom margin is honoured by the following element' {
        $base = Save-TwoBlock -Name h0 -First { param($d) $d | Add-VellumPdfHeading -Text 'First' -MarginBottom 0 }
        $spaced = Save-TwoBlock -Name h25 -First { param($d) $d | Add-VellumPdfHeading -Text 'First' -MarginBottom 25 }
        (Get-TextY $base 'Second') - (Get-TextY $spaced 'Second') | Should -BeExactly 25
    }

    It 'list and table: bottom margin is honoured by the following element' {
        $base = Save-TwoBlock -Name l0 -First { param($d) $d | Add-VellumPdfList -Item 'x' -MarginBottom 0 }
        $spaced = Save-TwoBlock -Name l30 -First { param($d) $d | Add-VellumPdfList -Item 'x' -MarginBottom 30 }
        (Get-TextY $base 'Second') - (Get-TextY $spaced 'Second') | Should -BeExactly 30

        $baseT = Save-TwoBlock -Name t0 -First { param($d) $d | Add-VellumPdfTable -Row @(, @('c')) -MarginBottom 0 }
        $spacedT = Save-TwoBlock -Name t20 -First { param($d) $d | Add-VellumPdfTable -Row @(, @('c')) -MarginBottom 20 }
        (Get-TextY $baseT 'Second') - (Get-TextY $spacedT 'Second') | Should -BeExactly 20
    }

    It 'the space is consumed once: a third element is not pushed again' {
        $path = Join-Path $TestDrive 'once.pdf'
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'First' -MarginBottom 40 |
            Add-VellumPdfParagraph -Text 'Second' |
            Add-VellumPdfParagraph -Text 'Third' |
            Save-VellumPdfDocument -Path $path | Out-Null
        $c = Get-PdfContentText $path
        (Get-TextY $c 'Second') - (Get-TextY $c 'Third') | Should -BeLessThan 20
    }
}
