<#
    Page documents beyond rectangles: a free-form path with the even-odd fill rule
    (a ring and a star), a gradient clipped to an ellipse, wrapped and justified
    text boxes in two columns, and a repeated header and "Page x of y" footer.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/10-paths-clipping-and-text-boxes.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'paths-and-text-boxes.pdf'

# A circle of radius r as four Bezier curves (k is the usual circle constant). Interpolation writes
# numbers with a dot in every culture; -f would use a decimal comma in, for example, de-DE or nl-NL.
function Get-CirclePath([double]$Cx, [double]$Cy, [double]$R) {
    $k = 0.5522847498 * $R
    "M $($Cx + $R) $Cy C $($Cx + $R) $($Cy + $k) $($Cx + $k) $($Cy + $R) $Cx $($Cy + $R) " +
    "C $($Cx - $k) $($Cy + $R) $($Cx - $R) $($Cy + $k) $($Cx - $R) $Cy " +
    "C $($Cx - $R) $($Cy - $k) $($Cx - $k) $($Cy - $R) $Cx $($Cy - $R) " +
    "C $($Cx + $k) $($Cy - $R) $($Cx + $R) $($Cy - $k) $($Cx + $R) $Cy Z"
}

# A five-pointed star whose lines cross itself: the even-odd rule leaves the middle empty.
$star = (0..4 | ForEach-Object {
        $angle = [math]::PI / 2 + $_ * 4 * [math]::PI / 5
        , @((420 + 70 * [math]::Cos($angle)), (640 + 70 * [math]::Sin($angle)))
    })

$text = 'VellumPdf measures text with the real font metrics, so a text box can break lines exactly where a word ' +
    'no longer fits. Justified text widens the gaps between the words of every line except the last one of a paragraph.'

New-VellumPdfPageDocument -Language 'en-US' |
    Set-VellumPdfDocumentInfo -Title 'Paths, clipping and text boxes' |
    Add-VellumPdfPage |
    Set-VellumPdfPageBand Header 'PSVellumPDF example' -Align Left -Font HelveticaBold |
    Set-VellumPdfPageBand Footer 'Page {page} of {pages}' -Align Right |
    Add-VellumPdfText 'Paths, clipping and text boxes' -X 54 -Y 770 -FontSize 22 -Font HelveticaBold |
    # Ring: outer and inner circle in one path, the inner one cut out by the even-odd rule.
    Add-VellumPdfPath -Data ((Get-CirclePath 130 640 70) + ' ' + (Get-CirclePath 130 640 40)) -FillRule EvenOdd `
        -FillColor '#2b5fb4' -StrokeColor navy -StrokeWidth 2 -AltText 'A blue ring' |
    Add-VellumPdfPath -Point $star -Close -FillRule EvenOdd -FillColor '#f4b400' -StrokeColor '#8a6400' -LineJoin Round `
        -AltText 'A yellow star with a hollow centre' |
    # A gradient clipped to an ellipse.
    Use-VellumPdfClip -X 54 -Y 440 -Width 200 -Height 110 -Ellipse -ScriptBlock {
        $_ | Add-VellumPdfGradient -X 54 -Y 440 -Width 200 -Height 110 -StartColor '#d9480f' -EndColor '#ffd43b' -AltText 'An orange gradient in an ellipse'
    } |
    Add-VellumPdfTextBox $text -X 54 -Y 400 -Width 230 -Align Justify |
    Add-VellumPdfTextBox $text -X 311 -Y 400 -Width 230 -Align Left |
    Save-VellumPdfDocument -Path $out

"Wrote $out"
