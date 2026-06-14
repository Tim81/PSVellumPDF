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

    # Hex MUST be #-prefixed: #RRGGBB or #RGB shorthand. Requiring the '#' avoids
    # the trap where a bare number like '255' parses as hex (-> '225555') instead
    # of being rejected; a caller meaning an 8-bit channel would get a silently
    # wrong colour.
    if ($text.StartsWith('#')) {
        $hex = $text.Substring(1)
        if ($hex -match '^[0-9a-fA-F]{6}$') {
            return [double[]]@(
                [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
                [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
                [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0
            )
        }
        if ($hex -match '^[0-9a-fA-F]{3}$') {
            # Each nibble doubles: '#abc' -> 'aabbcc'.
            return [double[]]@(
                [Convert]::ToInt32("$($hex[0])$($hex[0])", 16) / 255.0
                [Convert]::ToInt32("$($hex[1])$($hex[1])", 16) / 255.0
                [Convert]::ToInt32("$($hex[2])$($hex[2])", 16) / 255.0
            )
        }
        throw "ConvertTo-VellumColor: '$Color' is not a valid hex colour. Use #RRGGBB or #RGB."
    }

    # Curated named colours (HTML basic 16 plus common CSS/X11 aliases).
    $named = @{
        # HTML basic 16
        black = @(0, 0, 0);            white     = @(1, 1, 1)
        red   = @(1, 0, 0);            lime      = @(0, 1, 0)
        green = @(0, 0.5, 0);          blue      = @(0, 0, 1)
        yellow = @(1, 1, 0);           cyan      = @(0, 1, 1)
        aqua  = @(0, 1, 1);            magenta   = @(1, 0, 1)
        fuchsia = @(1, 0, 1);          silver    = @(0.7529, 0.7529, 0.7529)
        gray  = @(0.5, 0.5, 0.5);     grey      = @(0.5, 0.5, 0.5)
        maroon = @(0.5, 0, 0);        olive     = @(0.5, 0.5, 0)
        navy  = @(0, 0, 0.5);         teal      = @(0, 0.5, 0.5)
        purple = @(0.5, 0, 0.5);      orange    = @(1, 0.6471, 0)
        # Blues
        darkblue  = @(0, 0, 0.5451);  lightblue  = @(0.6784, 0.8471, 0.9020)
        royalblue = @(0.2549, 0.4118, 0.8824); steelblue = @(0.2745, 0.5098, 0.7059)
        # Greens
        darkgreen   = @(0, 0.3922, 0);     forestgreen = @(0.1333, 0.5451, 0.1333)
        seagreen    = @(0.1804, 0.5451, 0.3412)
        # Reds / pinks
        darkred  = @(0.5451, 0, 0);        crimson  = @(0.8627, 0.0784, 0.2353)
        coral    = @(1, 0.4980, 0.3137);   salmon   = @(0.9804, 0.5020, 0.4471)
        pink     = @(1, 0.7529, 0.7961)
        # Yellows / browns
        gold      = @(1, 0.8431, 0);       khaki     = @(0.9412, 0.9020, 0.5490)
        brown     = @(0.6471, 0.1647, 0.1647)
        chocolate = @(0.8235, 0.4118, 0.1176)
        tan       = @(0.8235, 0.7059, 0.5490)
        beige     = @(0.9608, 0.9608, 0.8627)
        # Purples
        indigo  = @(0.2941, 0, 0.5098);    violet  = @(0.9333, 0.5098, 0.9333)
        lavender = @(0.9020, 0.9020, 0.9804)
        # Whites / grays
        ivory     = @(1, 1, 0.9412)
        lightgray = @(0.8275, 0.8275, 0.8275)
        lightgrey = @(0.8275, 0.8275, 0.8275)
        darkgray  = @(0.6627, 0.6627, 0.6627)
        darkgrey  = @(0.6627, 0.6627, 0.6627)
        slategray = @(0.4392, 0.5020, 0.5647)
        slategrey = @(0.4392, 0.5020, 0.5647)
        # Cyans
        turquoise = @(0.2510, 0.8784, 0.8157)
    }
    $key = $text.ToLowerInvariant()
    if ($named.ContainsKey($key)) {
        return [double[]]$named[$key]
    }

    throw ("ConvertTo-VellumColor: unrecognised colour '$Color'. Use an R,G,B array of three " +
        "numbers in 0..1, a hex string like '#3366cc' or '#36c', or a known name " +
        '(black, white, red, lime, green, blue, yellow, cyan, magenta, silver, gray, ' +
        'maroon, olive, navy, teal, purple, orange, and many more CSS/X11 names).')
}
