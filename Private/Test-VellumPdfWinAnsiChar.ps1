function Test-VellumPdfWinAnsiChar {
    <#
    .SYNOPSIS
        Tells whether a UTF-16 code unit can be drawn with the base-14 fonts.
    .DESCRIPTION
        VellumPdf encodes base-14 text as Windows-1252: ASCII, U+00A0..U+00FF, and the
        27 typographic characters Windows-1252 places in 0x80..0x9F (euro sign, curly
        quotes, bullet, dashes, ellipsis, trademark, ...). The C1 controls
        U+0080..U+009F and everything else cannot be encoded. Tab and line breaks count
        as encodable because the layout engine handles them itself. One definition for
        Write-VellumPdfEncodingWarning and Add-VellumPdfFormField.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [int]$CodeUnit)

    if (-not (Test-Path variable:script:VellumWinAnsiExtras)) {
        $script:VellumWinAnsiExtras = [System.Collections.Generic.HashSet[int]]::new(
            [int[]](0x20AC, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160,
                0x2039, 0x0152, 0x017D, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x017E, 0x0178))
    }
    if ($CodeUnit -le 0xFF) { return ($CodeUnit -lt 0x80 -or $CodeUnit -gt 0x9F) }
    $script:VellumWinAnsiExtras.Contains($CodeUnit)
}
