function Test-VellumPdfLinkUri {
    <#
    .SYNOPSIS
        Validates a hyperlink target and returns it in normalised form.
    .DESCRIPTION
        Only http, https and mailto URLs are allowed in generated documents, so a
        file cannot carry an unexpected protocol-handler link. Whitespace, control
        and format characters are stripped before the scheme is checked and from
        the stored value, which defeats 'java<TAB>script:' smuggling. Throws on a
        relative, scheme-less or disallowed-scheme URI. Shared by the text-link
        parameters and Add-VellumPdfLink.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Uri,
        [string]$Name = '-LinkUri'
    )

    $normalized = $Uri.Trim() -replace '[\s\p{Cc}\p{Cf}]', ''
    $scheme = [regex]::Match($normalized, '^(?<s>[a-zA-Z][a-zA-Z0-9+.-]*):').Groups['s'].Value
    if ($scheme.ToLowerInvariant() -notin @('http', 'https', 'mailto')) {
        $what = if ($scheme) { "scheme '$scheme'" } else { 'a relative or scheme-less URI' }
        throw ("$Name uses $what; only http, https, and mailto URLs are allowed in " +
            "generated documents (got '$Uri').")
    }
    $normalized
}
