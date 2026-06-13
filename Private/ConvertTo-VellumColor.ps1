function ConvertTo-VellumColor {
    <#
    .SYNOPSIS
        Normalises a colour value to a [double[3]] of 0..1 RGB components.
    .DESCRIPTION
        Internal helper so every public colour parameter (-Color, -BorderColor,
        -HeaderBackground, -AlternateRowBackground, and rich-cell backgrounds)
        accepts the same set of forms:

          - an R,G,B array of three numbers in 0..1 (the original contract);
          - a hex string '#RRGGBB', 'RRGGBB', '#RGB', or 'RGB';
          - a known colour name (the 16 HTML basic colours plus a few aliases).

        Returns the normalised triple, or $null when the input is $null (callers
        treat $null as "not specified"). Throws a clear error on anything else.
        Named colours are kept to a small curated table on purpose: System.Drawing
        colour parsing is not dependable cross-platform on .NET 10.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Pure conversion; no state change.')]
    [CmdletBinding()]
    [OutputType([double[]])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Color
    )

    if ($null -eq $Color) { return $null }

    # Already an array of components.
    if ($Color -is [System.Array]) {
        $vals = @($Color)
        if ($vals.Count -ne 3) {
            throw "ConvertTo-VellumColor: an RGB array must have exactly 3 components; got $($vals.Count)."
        }
        $triple = foreach ($v in $vals) {
            # Cast straight to [double] (PowerShell converts numbers and numeric
            # strings invariantly). Avoid [string]+TryParse: that round-trips
            # through the current culture and misreads '0.2' as 2 where '.' is a
            # thousands separator.
            try { $d = [double]$v }
            catch { throw "ConvertTo-VellumColor: RGB component '$v' is not a number." }
            if ($d -lt 0 -or $d -gt 1) {
                throw "ConvertTo-VellumColor: RGB components must be between 0 and 1; got $d."
            }
            $d
        }
        return [double[]]$triple
    }

    $text = ([string]$Color).Trim()

    # Hex: #RRGGBB / RRGGBB, or shorthand #RGB / RGB.
    $hex = $text.TrimStart('#')
    if ($hex -match '^[0-9a-fA-F]{6}$') {
        return [double[]]@(
            [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
            [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
            [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0
        )
    }
    if ($hex -match '^[0-9a-fA-F]{3}$') {
        # Each nibble doubles: 'abc' -> 'aabbcc'.
        return [double[]]@(
            [Convert]::ToInt32("$($hex[0])$($hex[0])", 16) / 255.0
            [Convert]::ToInt32("$($hex[1])$($hex[1])", 16) / 255.0
            [Convert]::ToInt32("$($hex[2])$($hex[2])", 16) / 255.0
        )
    }

    # Curated named colours (HTML basic 16 plus common aliases).
    $named = @{
        black = @(0, 0, 0);            white  = @(1, 1, 1)
        red   = @(1, 0, 0);            lime   = @(0, 1, 0)
        green = @(0, 0.5, 0);          blue   = @(0, 0, 1)
        yellow = @(1, 1, 0);           cyan   = @(0, 1, 1)
        aqua  = @(0, 1, 1);            magenta = @(1, 0, 1)
        fuchsia = @(1, 0, 1);          silver = @(0.7529, 0.7529, 0.7529)
        gray  = @(0.5, 0.5, 0.5);      grey   = @(0.5, 0.5, 0.5)
        maroon = @(0.5, 0, 0);         olive  = @(0.5, 0.5, 0)
        navy  = @(0, 0, 0.5);          teal   = @(0, 0.5, 0.5)
        purple = @(0.5, 0, 0.5);       orange = @(1, 0.6471, 0)
    }
    $key = $text.ToLowerInvariant()
    if ($named.ContainsKey($key)) {
        return [double[]]$named[$key]
    }

    throw ("ConvertTo-VellumColor: unrecognised colour '$Color'. Use an R,G,B array of three " +
        "numbers in 0..1, a hex string like '#3366cc' or '#36c', or a known name " +
        '(black, white, red, lime, green, blue, yellow, cyan, magenta, silver, gray, ' +
        'maroon, olive, navy, teal, purple, orange).')
}
