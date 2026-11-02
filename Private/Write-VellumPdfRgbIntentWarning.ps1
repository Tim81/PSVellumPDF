function Write-VellumPdfRgbIntentWarning {
    <#
    .SYNOPSIS
        Warns once per document when RGB content is drawn into a PDF/A document whose output intent is CMYK.
    .DESCRIPTION
        PDF/A 6.2.4.3 allows DeviceRGB only with an RGB output intent (or a default RGB space). After
        Set-VellumPdfOutputIntent -Cmyk (or a 4-component profile) RGB colour or an RGB image makes the
        saved file fail validation, the mirror image of the CMYK-without-CMYK-intent warning in
        Add-VellumPdfShape. Does nothing for other documents; the warning is raised once per intent
        (Set-VellumPdfOutputIntent resets it).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Document,
        [Parameter(Mandatory)] [string]$CommandName,
        [string]$What = 'RGB colour',

        # An image instead of a colour: only a DeviceRGB image counts.
        [VellumPdf.Images.PdfImageXObject]$Image
    )

    if (-not (Get-VellumPdfConformanceRequirement -Document $Document).IsPdfA) { return }
    if (-not $Document.PSObject.Properties['PSVellumCmykIntent']) { return }
    if ($Document.PSObject.Properties['PSVellumRgbIntentWarned']) { return }
    if ($Image) {
        $space = $null
        try { [void]$Image.BuildStream().Dictionary.TryGet([VellumPdf.Core.PdfName]::new('ColorSpace'), [ref]$space) }
        catch { Write-Verbose "The image colour space could not be read: $_" }
        if ("$space" -ne '/DeviceRGB') { return }
        $What = 'an RGB image'
    }
    $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumRgbIntentWarned', $true))
    Write-Warning ("${CommandName}: $What is drawn in a PDF/A document whose output intent is CMYK; PDF/A allows DeviceRGB only " +
        'with an RGB output intent, so the saved file will fail validation (6.2.4.3). Use CMYK colours, or give the ' +
        'document an RGB intent with Set-VellumPdfOutputIntent -IccProfilePath.')
}
