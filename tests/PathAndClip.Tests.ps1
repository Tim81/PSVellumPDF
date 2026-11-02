#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    function script:Save-Page([scriptblock]$Build, [string]$Name = ([guid]::NewGuid().ToString('N')), [hashtable]$DocParams = @{ Language = 'en' }) {
        $path = Join-Path $TestDrive "$Name.pdf"
        $doc = New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage
        $doc = & $Build $doc
        $doc | Save-VellumPdfDocument -Path $path | Out-Null
        $path
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfPath' {
    It 'writes lines, curves and a close as path operators and fills with the non-zero rule by default' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPath 'M 10 20 L 110 20 C 120 30 120 60 110 70 Z' -FillColor red }
        $c = Get-PdfContentText $path
        $c | Should -Match '(?m)^10 20 m$'
        $c | Should -Match '(?m)^110 20 l$'
        $c | Should -Match '(?m)^120 30 120 60 110 70 c$'
        $c | Should -Match '(?m)^h$'
        $c | Should -Match '(?m)^f$'
        $c | Should -Not -Match '(?m)^f\*$'
    }

    It 'fills with the even-odd rule and strokes the same outline afterwards' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPath 'M 0 0 L 50 0 L 50 50 Z' -FillRule EvenOdd -FillColor red -StrokeColor black }
        $c = Get-PdfContentText $path
        $c | Should -Match '(?m)^f\*$'
        $c | Should -Match '(?m)^S$'
        ([regex]::Matches($c, '(?m)^50 50 l$')).Count | Should -Be 2
    }

    It 'uses a single B operator for non-zero fill plus stroke, and strokes alone when no fill is given' {
        $c = Get-PdfContentText (Save-Page { param($d) $d | Add-VellumPdfPath 'M 0 0 L 50 0 L 50 50 Z' -FillColor red -StrokeColor black })
        $c | Should -Match '(?m)^B$'
        $c = Get-PdfContentText (Save-Page { param($d) $d | Add-VellumPdfPath 'M 0 0 L 50 0' } 'stroke-only')
        $c | Should -Match '(?m)^S$'
        $c | Should -Not -Match '(?m)^f$'
    }

    It 'holds several sub-paths and treats extra pairs after M and L as further line-tos' {
        $path = Save-Page { param($d) $d | Add-VellumPdfPath 'M 0 0 10 0 10 10 Z M 20 20 L 30 20 40 30 Z' -FillColor blue }
        $c = Get-PdfContentText $path
        $c | Should -Match '(?m)^20 20 m$'
        $c | Should -Match '(?m)^40 30 l$'
        ([regex]::Matches($c, '(?m)^h$')).Count | Should -Be 2
    }

    It 'draws a polygon from points' {
        $c = Get-PdfContentText (Save-Page { param($d) $d | Add-VellumPdfPath -Point (1, 2), (30, 2), (15, 40) -Close -FillColor green })
        $c | Should -Match '(?m)^1 2 m$'
        $c | Should -Match '(?m)^15 40 l$'
        $c | Should -Match '(?m)^h$'
    }

    It 'applies dash, caps, joins, opacity and CMYK' {
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfPath 'M 10 10 L 100 100' -StrokeCmyk 0, 1, 1, 0 -StrokeWidth 3 -Dash 4, 2 -LineCap Round -LineJoin Bevel -StrokeOpacity 0.5
        }
        $c = Get-PdfContentText $path
        $c | Should -Match '(?m)^0 1 1 0 K$'
        $c | Should -Match '(?m)^3 w$'
        $c | Should -Match '\[4 2\] 0 d'
        $c | Should -Match '(?m)^1 J$'
        $c | Should -Match '(?m)^2 j$'
        (Get-PdfText $path) | Should -Match '/CA 0\.5'
    }

    It 'rejects malformed path data with a clear message' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Add-VellumPdfPath 'L 10 10' -ErrorAction Stop } | Should -Throw '*must start with M*'
            { $doc | Add-VellumPdfPath 'M 0 0 l 10 10' -ErrorAction Stop } | Should -Throw '*absolute M, L, C and Z*'
            { $doc | Add-VellumPdfPath 'M 0 0 C 1 2 3' -ErrorAction Stop } | Should -Throw "*'C' needs 6 numbers*"
            { $doc | Add-VellumPdfPath 'M 0 0' -ErrorAction Stop } | Should -Throw '*at least a move and one segment*'
            { $doc | Add-VellumPdfPath 'M 0 0 L 1 x' -ErrorAction Stop } | Should -Throw '*expected a number*'
            { $doc | Add-VellumPdfPath -Point @(,@(1, 2)) -ErrorAction Stop } | Should -Throw '*at least two points*'
            { $doc | Add-VellumPdfPath -Point (1, 2), (3) -ErrorAction Stop } | Should -Throw '*x,y pair*'
            { $doc | Add-VellumPdfPath 'M 0 0 L 1 1' -FillColor red -FillCmyk 0, 0, 0, 1 -ErrorAction Stop } | Should -Throw '*not several*'
            { $doc | Add-VellumPdfPath 'M 0 0 L 1 1' -FillIcc 0.1, 0.2, 0.3 -ErrorAction Stop } | Should -Throw '*go together*'
        }
        finally { $doc.Dispose() }
    }

    It 'passes the PDF/A-2b preflight, with an ICC fill and a Figure alt text in tagged documents' {
        $srgb = Join-Path $TestDrive 'srgb.icc'
        [System.IO.File]::WriteAllBytes($srgb, [VellumPdf.Document.IccProfiles]::Srgb)
        $path = Save-Page {
            param($d)
            $d | Add-VellumPdfPath 'M 10 10 L 90 10 L 50 80 Z' -IccProfilePath $srgb -FillIcc 0.2, 0.4, 0.6 -StrokeColor black
        } 'a2b' @{ Conformance = 'PdfA2b'; Language = 'en' }
        (Test-VellumPdfConformance -Path $path -Profile PdfA2b).IsCompliant | Should -BeTrue

        $ua = Join-Path $TestDrive 'ua.pdf'
        New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US | Add-VellumPdfPage |
            Set-VellumPdfDocumentInfo -Title 'Path' |
            Add-VellumPdfPath 'M 10 10 L 90 10 L 50 80 Z' -FillColor navy -AltText 'A navy triangle' |
            Add-VellumPdfPath 'M 100 10 L 190 10' |
            Save-VellumPdfDocument -Path $ua | Out-Null
        (Test-VellumPdfConformance -Path $ua -Profile PdfUA1).IsCompliant | Should -BeTrue
        $t = Get-PdfText $ua
        $t | Should -Match '/S /Figure'
        (Get-PdfContentText $ua) | Should -Match '/Artifact BMC'
    }
}

Describe 'Use-VellumPdfClip' {
    It 'clips with W n inside a balanced q/Q scope and draws the block inside it' {
        $path = Save-Page {
            param($d)
            $d | Use-VellumPdfClip -X 10 -Y 10 -Width 50 -Height 40 -ScriptBlock {
                $_ | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 200 -Height 200 -FillColor green
            }
        }
        $c = Get-PdfContentText $path
        $c | Should -Match '(?s)10 10 m\r?\n60 10 l\r?\n60 50 l\r?\n10 50 l\r?\nh\r?\nW\r?\nn.*0 0 200 200 re'
        ([regex]::Matches($c, '(?m)^q$')).Count | Should -Be ([regex]::Matches($c, '(?m)^Q$')).Count
    }

    It 'supports ellipse, polygon, path data, even-odd and nesting' {
        $c = Get-PdfContentText (Save-Page {
                param($d)
                $d | Use-VellumPdfClip -X 0 -Y 0 -Width 100 -Height 60 -Ellipse -ScriptBlock {
                    $_ | Use-VellumPdfClip -Point (10, 10), (90, 10), (50, 50) -ScriptBlock {
                        $_ | Use-VellumPdfClip -Data 'M 0 0 L 100 0 L 100 100 L 0 100 Z M 20 20 L 80 20 L 80 80 L 20 80 Z' -FillRule EvenOdd -ScriptBlock {
                            $_ | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 100 -Height 100 -FillColor red
                        }
                    }
                }
            })
        ([regex]::Matches($c, '(?m)^W$')).Count | Should -Be 2
        ([regex]::Matches($c, '(?m)^W\*$')).Count | Should -Be 1
        ([regex]::Matches($c, ' c$', 'Multiline')).Count | Should -Be 4
    }

    It 'lifts the clip even when the block throws' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            { $doc | Use-VellumPdfClip -X 0 -Y 0 -Width 10 -Height 10 -ScriptBlock { throw 'boom' } } | Should -Throw '*boom*'
            $doc | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 5 -Height 5 -FillColor red | Out-Null
            $p = Join-Path $TestDrive 'throw.pdf'
            $doc | Save-VellumPdfDocument -Path $p | Out-Null
        }
        finally { if (-not $doc.PSObject.Properties['PSVellumSaved']) { $doc.Dispose() } }
        $c = Get-PdfContentText $p
        ([regex]::Matches($c, '(?m)^q$')).Count | Should -Be ([regex]::Matches($c, '(?m)^Q$')).Count
    }

    It 'returns the document so calls chain, and drops the block output' {
        $doc = New-VellumPdfPageDocument | Add-VellumPdfPage
        try {
            $out = @($doc | Use-VellumPdfClip -X 0 -Y 0 -Width 10 -Height 10 -ScriptBlock { 'noise'; 42 })
            $out.Count | Should -Be 1
            $out[0] | Should -BeOfType ([VellumPdf.Document.PdfDocument])
        }
        finally { $doc.Dispose() }
    }

    It 'passes the PDF/UA-1 preflight with tagged content inside a clip' {
        $ua = Join-Path $TestDrive 'clip-ua.pdf'
        New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US | Add-VellumPdfPage |
            Set-VellumPdfDocumentInfo -Title 'Clip' |
            Use-VellumPdfClip -X 50 -Y 50 -Width 200 -Height 100 -Ellipse -ScriptBlock {
                $_ | Add-VellumPdfGradient -X 50 -Y 50 -Width 200 -Height 100 -StartColor red -EndColor blue -AltText 'A clipped gradient'
            } |
            Save-VellumPdfDocument -Path $ua | Out-Null
        (Test-VellumPdfConformance -Path $ua -Profile PdfUA1).IsCompliant | Should -BeTrue
    }
}
