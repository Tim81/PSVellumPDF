function Get-VellumPdfEmbeddedStandard14 {
    <#
    .SYNOPSIS
        Embeds (once per document) the metric-compatible Liberation substitute for a base-14 font name.
    .DESCRIPTION
        PDF/A and PDF/UA-1 forbid non-embedded fonts. VellumPdf.Fonts.Standard14 ships Liberation
        Sans, Serif and Mono (metric-compatible with Helvetica, Times and Courier, regular, bold,
        italic and bold italic), so a conformant document draws a base-14 name in the matching
        Liberation face instead. Works for both document kinds (page documents through
        EmbedStandard14Font, flow documents by registering the font resource). The handle is cached
        on the document, so each substitute is embedded once. Symbol and ZapfDingbats have no
        substitute and are refused with a pointer to -FontHandle.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Fonts.EmbeddedFontHandle])]
    param(
        [Parameter(Mandatory)] $Document,
        [Parameter(Mandatory)] [string]$Font,
        [Parameter(Mandatory)] [string]$CommandName
    )

    $cacheProp = $Document.PSObject.Properties['PSVellumEmbeddedStd14']
    if (-not $cacheProp) {
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumEmbeddedStd14', @{}))
        $cacheProp = $Document.PSObject.Properties['PSVellumEmbeddedStd14']
    }
    if (-not $cacheProp.Value.ContainsKey($Font)) {
        try {
            $std = [VellumPdf.Fonts.Standard14]::$Font
            if ($Document -is [VellumPdf.Document.PdfDocument]) {
                $handle = [VellumPdf.Fonts.Standard14FontExtensions]::EmbedStandard14Font($Document, $std)
            }
            else {
                # Same Liberation faces EmbedStandard14Font uses, read from the Standard14 assembly.
                $family = switch -Wildcard ($Font) {
                    'Helvetica*' { 'LiberationSans' }
                    'Times*'     { 'LiberationSerif' }
                    'Courier*'   { 'LiberationMono' }
                    default      { throw "'$Font' has no metric-compatible Liberation face" }
                }
                $face = if ($Font -like '*Bold*' -and ($Font -like '*Oblique' -or $Font -like '*Italic')) { 'BoldItalic' }
                        elseif ($Font -like '*Bold') { 'Bold' }
                        elseif ($Font -like '*Oblique' -or $Font -like '*Italic') { 'Italic' }
                        else { 'Regular' }
                $assembly = [VellumPdf.Fonts.Standard14FontExtensions].Assembly
                $stream = $assembly.GetManifestResourceStream("$family-$face.ttf")
                if (-not $stream) { throw "the resource $family-$face.ttf is missing from $($assembly.GetName().Name)" }
                try {
                    $buffer = [System.IO.MemoryStream]::new()
                    $stream.CopyTo($buffer)
                    $handle = $Document.UseTrueTypeFont($buffer.ToArray())
                }
                finally { $stream.Dispose() }
            }
        }
        catch {
            throw ("${CommandName}: this document needs embedded fonts (PDF/A, PDF/UA-1) and no embeddable substitute exists for '$Font' " +
                "($($_.Exception.Message)). Pass -FontHandle from Register-VellumPdfFont.")
        }
        $handle.PSObject.Properties.Add([psnoteproperty]::new('PSVellumOwner', $Document))
        $cacheProp.Value[$Font] = $handle
    }
    $cacheProp.Value[$Font]
}
