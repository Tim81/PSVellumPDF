function Add-VellumPdfDrawing {
    <#
    .SYNOPSIS
        Reserves a block in the page flow and draws into it with a script block.
    .DESCRIPTION
        Gives you the full VellumPdf canvas (PdfCanvas) for free-form vector
        drawing - shapes, gradients, transparency, CMYK colour, clipping, dashes,
        arcs, text - inside the normal flow of a Layout document. The script block
        receives:

          $canvas  the VellumPdf.Canvas.PdfCanvas, already in PDF page space
          $box     a record with X, Y (bottom-left corner), Width and Height in
                   points: the area reserved for the drawing
          $ctx     the VellumPdf.Layout.Core.DrawContext, for fonts:
                   $font = $ctx.GetFont([VellumPdf.Fonts.Standard14]::Helvetica)
                   $canvas.SetFont($font, 12) ; embedded fonts: $ctx.UseEmbeddedFont($handle)

        Coordinates are PDF points with the origin at the page's bottom-left. The
        canvas state is saved before and restored after your script, so you cannot
        leak colours or transforms into later content.

        PowerShell cannot pass arrays to the canvas operators that take spans
        (dash patterns, raw colour components, glyph ids); use the helpers in
        [PSVellumPDF.Interop.CanvasHelpers] (SetLineDash, SetFillColor,
        SetStrokeColor, ShowGlyphs) instead.

        The script block runs while the document is saved, on the PowerShell
        thread. The variables it reads (such as a loop variable or a function's
        locals) are captured when Add-VellumPdfDrawing is called, so the block
        draws with the values they had then; $script: and $global: variables and
        functions stay live, and assignments to a captured variable stay inside
        the block. SaveState/RestoreState must balance inside the block: an
        uneven block makes the save fail with an error naming Add-VellumPdfDrawing.
        In a PDF/A or PDF/UA document draw text with an embedded font
        ($ctx.UseEmbeddedFont), since $ctx.GetFont uses a non-embedded base-14 font.
        Because it runs at save time it works with Save-VellumPdfDocument but not with an
        asynchronous save or an external asynchronous signer. In a tagged document
        the drawing is a Figure with -AltText (or the text 'Drawing'); pass
        -Decorative for purely decorative graphics.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline.
    .PARAMETER Height
        Height in points of the block to reserve. It spans the content width.
    .PARAMETER ScriptBlock
        Draws into the block: param($canvas, $box, $ctx).
    .PARAMETER AltText
        Alternate text for a tagged document.
    .PARAMETER Decorative
        Mark the drawing as an artifact (not read by screen readers).
    .PARAMETER MarginTop
        Extra spacing in points above the block.
    .PARAMETER MarginBottom
        Extra spacing in points below the block.
    .EXAMPLE
        $doc | Add-VellumPdfDrawing -Height 60 -AltText 'A red box with a blue border' -ScriptBlock {
            param($canvas, $box)
            $canvas.SetFillColorRgb(1, 0, 0).SetStrokeColorRgb(0, 0, 1).SetLineWidth(2)
            $canvas.Rectangle($box.X + 5, $box.Y + 5, 100, $box.Height - 10).FillAndStroke() | Out-Null
        }
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [ValidateRange(1.0, 100000.0)]
        [double]$Height,

        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) }, ErrorMessage = '-AltText must not be empty or whitespace.')]

        [string]$AltText,

        [switch]$Decorative,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfDrawing'
            if ($Decorative -and $AltText) {
                throw 'Add-VellumPdfDrawing: -AltText and -Decorative cannot be combined.'
            }
            $staged = $Document.PSObject.Properties['PSVellumSignature']
            if ($staged -and $staged.Value.ExternalSigner) {
                throw ('Add-VellumPdfDrawing: this document is staged for signing with an -ExternalSigner, which signs ' +
                    'asynchronously and cannot run drawing script blocks. Sign with the certificate or an -ExternalPrivateKey instead.')
            }

            # Space deferred by the previous element's -MarginBottom goes above this block.
            $top = if ($PSBoundParameters.ContainsKey('MarginTop')) { $MarginTop } else { 0.0 }
            $pending = $Document.PSObject.Properties['PSVellumPendingSpace']
            if ($pending -and $pending.Value) {
                $top += [double]$pending.Value
                $pending.Value = 0.0
            }

            # The block runs at save time: hand it the values its variables have now (a loop variable, a
            # function's locals), not whatever they hold when the document is saved.
            $captured = [System.Collections.Generic.List[System.Management.Automation.PSVariable]]::new()
            foreach ($variable in @(Get-VellumPdfBlockVariable -ScriptBlock $ScriptBlock)) { $captured.Add($variable) }
            $renderer = [PSVellumPDF.Interop.ScriptBlockRenderer]::new($Height, $ScriptBlock, $AltText, [bool]$Decorative, $top, $MarginBottom, $captured)
            [void]$Document.Add($renderer)
            # Remember that the document holds script-block content: a signature
            # produced asynchronously (external signer) cannot run it.
            if (-not $Document.PSObject.Properties['PSVellumHasDrawing']) {
                $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumHasDrawing', $true))
            }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfDrawing'))
        }
    }
}
