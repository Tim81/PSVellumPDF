function Add-VellumPdfLink {
    <#
    .SYNOPSIS
        Makes a rectangle on a page a clickable link to a URL or to another page.
    .DESCRIPTION
        Adds a link annotation over the rectangle (-X, -Y, -Width, -Height), in
        points from the page's bottom-left. With -Uri the link opens a web address
        (http, https or mailto only). With -TargetPage it jumps to another page of
        the document, optionally to the point (-DestLeft, -DestTop) on it - something
        the flow-layout document cannot do.

        The link rectangle is invisible; draw something under it (text, a shape) or
        use -Border to show a thin frame. Annotation flags default to Print.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page that carries the link. Default 1.
    .PARAMETER X
        Left edge in points.
    .PARAMETER Y
        Bottom edge in points.
    .PARAMETER Width
        Width in points.
    .PARAMETER Height
        Height in points.
    .PARAMETER Uri
        The web address: http, https or mailto.
    .PARAMETER TargetPage
        The 1-based page to jump to.
    .PARAMETER DestLeft
        Horizontal position on the target page in points (default 0).
    .PARAMETER DestTop
        Vertical position on the target page in points (default the top of the page).
    .PARAMETER Flags
        Annotation flags (Print, Hidden, NoView, ReadOnly, ...); default Print.
    .EXAMPLE
        $doc | Add-VellumPdfLink -X 72 -Y 700 -Width 120 -Height 14 -Uri https://example.com
    .EXAMPLE
        $doc | Add-VellumPdfLink -Page 1 -X 72 -Y 650 -Width 90 -Height 14 -TargetPage 3
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,
        [Parameter(Mandatory)] [ValidateRange(0.01, 1000000.0)] [double]$Width,
        [Parameter(Mandatory)] [ValidateRange(0.01, 1000000.0)] [double]$Height,

        [string]$Uri,

        [ValidateRange(1, 1000000)]
        [int]$TargetPage,

        [double]$DestLeft = 0,
        [double]$DestTop,

        [VellumPdf.Annotations.PdfAnnotationFlags]$Flags = [VellumPdf.Annotations.PdfAnnotationFlags]::Print
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfLink'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfLink'
            $hasUri = $PSBoundParameters.ContainsKey('Uri')
            $hasTarget = $PSBoundParameters.ContainsKey('TargetPage')
            if ($hasUri -eq $hasTarget) { throw 'Add-VellumPdfLink: give exactly one of -Uri or -TargetPage.' }
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfLink'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfLink'; Assert-VellumPdfCoordinate $Width 'Width' 'Add-VellumPdfLink'; Assert-VellumPdfCoordinate $Height 'Height' 'Add-VellumPdfLink'
            if ($hasUri -and ($PSBoundParameters.ContainsKey('DestLeft') -or $PSBoundParameters.ContainsKey('DestTop'))) {
                throw 'Add-VellumPdfLink: -DestLeft/-DestTop apply to -TargetPage only.'
            }
            $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfLink'
            Write-VellumPdfUntaggedWarning -Document $Document -CommandName 'Add-VellumPdfLink' -What 'a link annotation'

            $link = [VellumPdf.Annotations.PdfLinkAnnotation]::new()
            $link.Rect = [VellumPdf.Document.PdfRectangle]::new($X, $Y, $X + $Width, $Y + $Height)
            $link.Flags = $Flags
            if ($hasUri) {
                $link.Uri = Test-VellumPdfLinkUri -Uri $Uri -Name '-Uri'
            }
            else {
                $target = Get-VellumPdfPage -Document $Document -Page $TargetPage -CommandName 'Add-VellumPdfLink'
                Assert-VellumPdfCoordinate $DestLeft 'DestLeft' 'Add-VellumPdfLink'
                if ($PSBoundParameters.ContainsKey('DestTop')) { Assert-VellumPdfCoordinate $DestTop 'DestTop' 'Add-VellumPdfLink' }
                $link.DestPage = $target
                $link.DestLeft = $DestLeft
                $link.DestTop = if ($PSBoundParameters.ContainsKey('DestTop')) { $DestTop } else { $target.MediaBox.UrY }
            }
            $Document.RegisterLinkAnnotation($pdfPage, $link)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
