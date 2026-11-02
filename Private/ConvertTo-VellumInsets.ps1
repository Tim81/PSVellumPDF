function ConvertTo-VellumInsets {
    <#
    .SYNOPSIS
        Converts a padding value to a VellumPdf EdgeInsets.
    .DESCRIPTION
        Accepts one number (all four sides), two numbers (top/bottom, left/right)
        or four numbers (top, right, bottom, left), in points. Every value must be
        a finite number between 0 and 1000. Internal helper for the table cell
        padding options.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Core.EdgeInsets])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Insets is the engine term (EdgeInsets): one value holding four edges, not a collection.')]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$What
    )

    $numbers = foreach ($v in @($Value)) {
        $n = $v -as [double]
        if ($null -eq $n -or -not [double]::IsFinite($n) -or $n -lt 0 -or $n -gt 1000) {
            throw (New-VellumPdfErrorRecord InvalidArgument "${What} must be numbers between 0 and 1000 points; got '$v'.")
        }
        $n
    }
    $numbers = @($numbers)
    switch ($numbers.Count) {
        1 { return [VellumPdf.Layout.Core.EdgeInsets]::new($numbers[0]) }
        2 { return [VellumPdf.Layout.Core.EdgeInsets]::new($numbers[0], $numbers[1]) }
        4 { return [VellumPdf.Layout.Core.EdgeInsets]::new($numbers[0], $numbers[1], $numbers[2], $numbers[3]) }
        default { throw (New-VellumPdfErrorRecord InvalidArgument "${What} takes 1 (all sides), 2 (top/bottom, left/right) or 4 (top, right, bottom, left) numbers; got $($numbers.Count).") }
    }
}
