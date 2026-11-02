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
          - a known colour name (the 16 HTML basic colours plus about 35 more CSS names).

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

    # More CSS colour names, as 0xRRGGBB.
    $css = @{
        pink = 0xFFC0CB; hotpink = 0xFF69B4; brown = 0xA52A2A; gold = 0xFFD700; coral = 0xFF7F50
        salmon = 0xFA8072; crimson = 0xDC143C; indigo = 0x4B0082; violet = 0xEE82EE; turquoise = 0x40E0D0
        khaki = 0xF0E68C; beige = 0xF5F5DC; ivory = 0xFFFFF0; lavender = 0xE6E6FA; tan = 0xD2B48C
        chocolate = 0xD2691E; sienna = 0xA0522D; orchid = 0xDA70D6; plum = 0xDDA0DD; skyblue = 0x87CEEB
        steelblue = 0x4682B4; royalblue = 0x4169E1; slategray = 0x708090; slategrey = 0x708090
        darkgray = 0xA9A9A9; darkgrey = 0xA9A9A9; lightgray = 0xD3D3D3; lightgrey = 0xD3D3D3
        darkgreen = 0x006400; forestgreen = 0x228B22; seagreen = 0x2E8B57; darkblue = 0x00008B
        darkred = 0x8B0000; orangered = 0xFF4500; darkorange = 0xFF8C00; lightblue = 0xADD8E6
        lightgreen = 0x90EE90; midnightblue = 0x191970; whitesmoke = 0xF5F5F5; gainsboro = 0xDCDCDC
    }
    if ($css.ContainsKey($key)) {
        $rgb = [int]$css[$key]
        return [double[]]@(
            ((($rgb -shr 16) -band 255) / 255.0),
            ((($rgb -shr 8) -band 255) / 255.0),
            (($rgb -band 255) / 255.0))
    }

    throw ("ConvertTo-VellumColor: unrecognised colour '$Color'. Use an R,G,B array of three " +
        "numbers in 0..1, a hex string like '#3366cc' or '#36c', or a known name " +
        '(black, white, red, lime, green, blue, yellow, cyan, magenta, silver, gray, ' +
        'maroon, olive, navy, teal, purple, orange, pink, brown, gold, coral, crimson, indigo, ' +
        'violet, turquoise, khaki, beige, ivory, lavender, tan, steelblue, skyblue, royalblue, ' +
        'lightgray, darkgray, lightblue, lightgreen, darkgreen, darkblue, darkred, ... - any standard CSS name).')
}
