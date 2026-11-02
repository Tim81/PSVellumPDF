#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Add-VellumPdfDrawing' {
    It 'runs the script block with canvas, box and context, drawing real operators' {
        $out = Join-Path $TestDrive 'draw.pdf'
        $script:seen = $null
        New-VellumPdfDocument | Add-VellumPdfDrawing -Height 80 -ScriptBlock {
            param($canvas, $box, $ctx)
            $script:seen = @($canvas.GetType().Name, $box.Height, $ctx.GetType().Name)
            $canvas.SetFillColorRgb(1, 0, 0).Rectangle($box.X, $box.Y, 50, $box.Height).Fill() | Out-Null
        } | Save-VellumPdfDocument -Path $out | Out-Null
        $script:seen | Should -Be @('PdfCanvas', 80, 'DrawContext')
        Get-PdfContentText $out | Should -Match '1 0 0 rg'
    }

    It 'supports gradients, alpha, CMYK, arcs and dashes via the canvas and interop helpers' {
        $out = Join-Path $TestDrive 'fancy.pdf'
        New-VellumPdfDocument | Add-VellumPdfDrawing -Height 120 -ScriptBlock {
            param($canvas, $box)
            $canvas.SetFillAlpha(0.5) | Out-Null
            $canvas.SetFillColorCmyk(0, 1, 1, 0).Rectangle($box.X, $box.Y, 40, 40).Fill() | Out-Null
            [PSVellumPDF.Interop.CanvasHelpers]::SetLineDash($canvas, [double[]](4, 2), 0) | Out-Null
            $canvas.MoveTo($box.X, $box.Y).LineTo($box.X + 100, $box.Y + 50).Stroke() | Out-Null
            $canvas.SetSolidLine().AppendArc($box.X + 150, $box.Y + 40, 30, 0, 3.14).Stroke() | Out-Null
            [PSVellumPDF.Interop.CanvasHelpers]::SetFillColor($canvas, [double[]](0.2, 0.4, 0.6)) | Out-Null
            $canvas.Rectangle($box.X + 200, $box.Y, 20, 20).Fill() | Out-Null
        } | Save-VellumPdfDocument -Path $out | Out-Null
        $c = Get-PdfContentText $out
        $c | Should -Match '0 1 1 0 k'
        $c | Should -Match '\[4 2\] 0 d'
        $c | Should -Match '0\.2 0\.4 0\.6 scn'
    }

    It 'draws text through a context font' {
        $out = Join-Path $TestDrive 'text.pdf'
        New-VellumPdfDocument | Add-VellumPdfDrawing -Height 30 -ScriptBlock {
            param($canvas, $box, $ctx)
            $font = $ctx.GetFont([VellumPdf.Fonts.Standard14]::Helvetica)
            $canvas.BeginText().SetFont($font, 14).MoveTextPosition($box.X, $box.Y + 5).ShowText('Hello drawing').EndText() | Out-Null
        } | Save-VellumPdfDocument -Path $out | Out-Null
        Get-PdfContentText $out | Should -Match '\(Hello drawing\) Tj'
    }

    It 'keeps canvas state from leaking into later content' {
        $out = Join-Path $TestDrive 'leak.pdf'
        New-VellumPdfDocument |
            Add-VellumPdfDrawing -Height 20 -ScriptBlock { param($canvas) $canvas.SetFillColorRgb(1, 0, 0) | Out-Null } |
            Add-VellumPdfParagraph -Text 'after' | Save-VellumPdfDocument -Path $out | Out-Null
        $c = Get-PdfContentText $out
        $c | Should -Match '(?s)\bq\b.*1 0 0 rg.*\bQ\b'
    }

    It 'writes a Figure with alternate text in a tagged document and an artifact when decorative' {
        $a = Join-Path $TestDrive 'alt.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfDrawing -Height 20 -AltText 'A red square' -ScriptBlock { param($canvas, $box) $canvas.Rectangle($box.X, $box.Y, 10, 10).Fill() | Out-Null } |
            Save-VellumPdfDocument -Path $a | Out-Null
        Get-PdfText $a | Should -Match (Get-Utf16Pattern 'A red square')
        Get-PdfText $a | Should -Match '/S\s*/Figure'

        $d = Join-Path $TestDrive 'deco.pdf'
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfDrawing -Height 20 -Decorative -ScriptBlock { param($canvas, $box) $canvas.Rectangle($box.X, $box.Y, 10, 10).Fill() | Out-Null } |
            Save-VellumPdfDocument -Path $d | Out-Null
        Get-PdfText $d | Should -Not -Match '/S\s*/Figure'
    }

    It 'honours margins, including space deferred from the previous element' {
        $doc = New-VellumPdfDocument
        try {
            $doc | Add-VellumPdfParagraph -Text 'x' -MarginBottom 25 | Out-Null
            $doc | Add-VellumPdfDrawing -Height 10 -MarginTop 5 -MarginBottom 7 -ScriptBlock { param($canvas, $box) $null = $canvas; $script:boxY = $box.Y } | Out-Null
            $doc.PSVellumPendingSpace | Should -Be 0
            $doc.PSVellumHasDrawing | Should -BeTrue
        }
        finally { $doc.Dispose() }
    }

    It 'reports a failing script block clearly from Save' {
        $doc = New-VellumPdfDocument | Add-VellumPdfDrawing -Height 10 -ScriptBlock { throw 'boom' }
        try {
            { $doc | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'fail.pdf') } | Should -Throw '*boom*'
        }
        finally { try { $doc.Dispose() } catch { Write-Verbose "disposed: $_" } }
    }

    It 'refuses to run off the pipeline thread (asynchronous save)' {
        $doc = New-VellumPdfDocument | Add-VellumPdfDrawing -Height 10 -ScriptBlock { param($canvas) $canvas.SaveState() | Out-Null; $canvas.RestoreState() | Out-Null }
        try {
            { $doc.SaveAsync((Join-Path $TestDrive 'async.pdf')).GetAwaiter().GetResult() } | Should -Throw '*synchronous save*'
        }
        finally { try { $doc.Dispose() } catch { Write-Verbose "disposed: $_" } }
    }

    It 'validates its parameters' {
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfDrawing -Height 0 -ScriptBlock { } } | Should -Throw
            { $doc | Add-VellumPdfDrawing -Height 10 -AltText 'a' -Decorative -ScriptBlock { } } | Should -Throw '*cannot be combined*'
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Add-VellumPdfElement' {
    It 'adds any IRenderer, such as a barcode renderer' {
        $out = Join-Path $TestDrive 'element.pdf'
        $qr = [VellumPdf.Barcodes.QrCode]::new('hello')
        $qr.ModuleSize = 2
        New-VellumPdfDocument | Add-VellumPdfElement -Renderer ([VellumPdf.Barcodes.BarcodeRenderer]::new($qr)) |
            Save-VellumPdfDocument -Path $out | Out-Null
        (Get-Item $out).Length | Should -BeGreaterThan 400
    }

    It 'places the space a previous -MarginBottom deferred in front of the element' {
        $y = {
            param($mb, $name)
            $qr = [VellumPdf.Barcodes.QrCode]::new('hello'); $qr.ModuleSize = 2
            $out = Join-Path $TestDrive "$name.pdf"
            New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'First' -MarginBottom $mb |
                Add-VellumPdfElement -Renderer ([VellumPdf.Barcodes.BarcodeRenderer]::new($qr)) |
                Save-VellumPdfDocument -Path $out | Out-Null
            [double][regex]::Match((Get-PdfContentText $out), '[\d.]+ ([\d.]+) [\d.]+ [\d.]+ re').Groups[1].Value
        }
        $base = & $y 0 'sp0'
        $spaced = & $y 40 'sp40'
        $base - $spaced | Should -Be 40
    }

    It 'requires an IRenderer' {
        $doc = New-VellumPdfDocument
        try { { $doc | Add-VellumPdfElement -Renderer 'nope' } | Should -Throw }
        finally { $doc.Dispose() }
    }
}
