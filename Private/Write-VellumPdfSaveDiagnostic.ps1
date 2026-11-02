function Write-VellumPdfSaveDiagnostic {
    <#
    .SYNOPSIS
        Reports what the VellumPdf engine says it had to alter while saving.
    .DESCRIPTION
        Layout only knows about unencodable text and over-long headers/footers
        once it has laid the document out, which happens inside Save. After a
        successful save this helper reads the engine's own lists and:

        * emits ONE warning for Document.TextEncodingWarnings - characters that
          the base-14 fonts could not encode and that were written as '?'
          (authoritative, unlike the per-cmdlet pre-check, which is a heuristic);
        * emits one warning per Document.BandTruncations entry - a header or
          footer whose resolved text was cut at a word boundary to fit the page;
        * returns both lists as plain objects, so Save-VellumPdfDocument can attach
          them to the file object it returns for scripted checks.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [VellumPdf.Layout.Document]$Document
    )

    $encoding = @(foreach ($w in $Document.TextEncodingWarnings) {
            [pscustomobject]@{
                PSTypeName = 'PSVellumPDF.TextEncodingWarning'
                CodePoint  = $w.CodePoint
                Character  = $w.Character.ToString()
            }
        })
    $bands = @(foreach ($b in $Document.BandTruncations) {
            [pscustomobject]@{
                PSTypeName         = 'PSVellumPDF.BandTruncation'
                Band               = [string]$b.Band
                PageNumber         = $b.PageNumber
                DrawnCharacters    = $b.DrawnCharacters
                ResolvedCharacters = $b.ResolvedCharacters
                DroppedCharacters  = $b.DroppedCharacters
            }
        })

    if ($encoding.Count -gt 0) {
        $distinct = @($encoding | Sort-Object CodePoint -Unique | Select-Object -First 8 |
                ForEach-Object { 'U+{0:X4}' -f $_.CodePoint })
        $more = if (($encoding | Sort-Object CodePoint -Unique).Count -gt 8) { ', ...' } else { '' }
        Write-Warning ("Save-VellumPdfDocument: $($encoding.Count) character(s) could not be encoded by the " +
            "base-14 fonts and were written as '?' ($($distinct -join ', ')$more). Embed a TrueType font with " +
            'Register-VellumPdfFont and pass its handle via -FontHandle.')
    }
    foreach ($b in $bands) {
        Write-Warning ("Save-VellumPdfDocument: the $($b.Band.ToLowerInvariant()) text on page $($b.PageNumber) was " +
            "too wide for the page and was truncated ($($b.DroppedCharacters) of $($b.ResolvedCharacters) " +
            'characters dropped). Shorten the template or the font size.')
    }

    [pscustomobject]@{ TextEncodingWarnings = $encoding; BandTruncations = $bands }
}
