function Get-VellumPdfPageFont {
    <#
    .SYNOPSIS
        Resolves the font for page text: an embedded handle, a base-14 resource, or
        (in PDF/A documents) an automatically embedded substitute.
    .DESCRIPTION
        PDF/A forbids non-embedded fonts. For a conformant page document a base-14
        name is therefore mapped to the metric-compatible Liberation font shipped in
        VellumPdf.Fonts.Standard14 and embedded once per document. Returns an object
        with Handle (embedded) or Resource (base-14), exactly one non-null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,
        [string]$Font = 'Helvetica',
        [Parameter(Mandatory)] [string]$CommandName
    )

    if ($FontHandle) {
        Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName $CommandName
        return [pscustomobject]@{ Handle = $FontHandle; Resource = $null }
    }
    $std = [VellumPdf.Fonts.Standard14]::$Font
    if ($Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None) {
        $cacheProp = $Document.PSObject.Properties['PSVellumEmbeddedStd14']
        if (-not $cacheProp) {
            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumEmbeddedStd14', @{}))
            $cacheProp = $Document.PSObject.Properties['PSVellumEmbeddedStd14']
        }
        if (-not $cacheProp.Value.ContainsKey($Font)) {
            try {
                $handle = [VellumPdf.Fonts.Standard14FontExtensions]::EmbedStandard14Font($Document, $std)
            }
            catch {
                throw ("${CommandName}: PDF/A needs an embedded font and no substitute exists for '$Font' " +
                    "($($_.Exception.Message)). Pass -FontHandle from Register-VellumPdfFont.")
            }
            $handle.PSObject.Properties.Add([psnoteproperty]::new('PSVellumOwner', $Document))
            $cacheProp.Value[$Font] = $handle
        }
        return [pscustomobject]@{ Handle = $cacheProp.Value[$Font]; Resource = $null }
    }
    [pscustomobject]@{ Handle = $null; Resource = $Document.UseFont($std) }
}
