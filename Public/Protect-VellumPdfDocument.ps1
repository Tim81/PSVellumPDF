function Protect-VellumPdfDocument {
    <#
    .SYNOPSIS
        Applies password protection and usage permissions to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Encrypt(PdfEncryptionSettings). Encryption is staged in memory
        and takes effect when the document is written by Save-VellumPdfDocument. The
        same Document instance is returned so the call can be chained in a pipeline.

        At least one of -UserPassword or -OwnerPassword must be supplied. Supplying
        both is the most common configuration: the user password opens the document
        for reading and the owner password unlocks all operations regardless of the
        -Permission set.

        PDF/A CONSTRAINT: PDF/A (ISO 19005) explicitly forbids encryption. If the
        document's Conformance is anything other than None (e.g. PdfA2b, PdfA2u,
        PdfA2a) this cmdlet throws a clear terminating error before calling Encrypt().
        The VellumPdf library also enforces this constraint at Save() time, so the
        fail-fast check here gives an earlier, more actionable message.

        SIGNING CONSTRAINT: encryption and digital signatures cannot be combined
        (the library rejects the pair at save time). This cmdlet throws if a
        signature has been staged with Set-VellumPdfSignature, and vice versa.

        PASSWORDS: Both password parameters accept [securestring] to keep credentials
        out of command history and verbose output. Use Read-Host -AsSecureString for
        interactive entry, or ConvertTo-SecureString for scripts.
    .PARAMETER Document
        The VellumPdf document to protect. Accepts pipeline input.
    .PARAMETER UserPassword
        The password required to open the document. Plain-text intermediates are
        never stored in variables or written to output streams.
    .PARAMETER OwnerPassword
        The password that grants unrestricted access, overriding -Permission
        restrictions. Recommended when using -Permission to limit operations.
    .PARAMETER Permission
        One or more permission flags to allow. Valid values:
          None          - no permissions granted beyond opening
          Print         - low-resolution printing
          Modify        - modify document content
          Copy          - copy or extract text and graphics
          Annotate      - add or modify annotations and fill forms
          FillForms     - fill in existing form fields
          Extract       - extract text and graphics (accessibility)
          Assemble      - insert, rotate, or delete pages and bookmarks
          PrintHighRes  - high-resolution (faithful) printing
          All           - all of the above (default)
        Multiple values are combined as flags. Example: -Permission Print,Copy
    .PARAMETER EncryptMetadata
        When specified, document metadata (XMP) is also encrypted. When omitted the
        library default applies (metadata is encrypted by default).
    .EXAMPLE
        $pw = Read-Host -Prompt 'Password' -AsSecureString
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Confidential.' |
            Protect-VellumPdfDocument -UserPassword $pw |
            Save-VellumPdfDocument -Path ./protected.pdf
    .EXAMPLE
        $userPw  = ConvertTo-SecureString 'userpass'  -AsPlainText -Force
        $ownerPw = ConvertTo-SecureString 'ownerpass' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Restricted copy.' |
            Protect-VellumPdfDocument -UserPassword $userPw -OwnerPassword $ownerPw `
                -Permission Print,Copy |
            Save-VellumPdfDocument -Path ./restricted.pdf
    .EXAMPLE
        # Owner-only (no user password needed to open; permissions still enforced)
        $ownerPw = ConvertTo-SecureString 's3cret' -AsPlainText -Force
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Body.' |
            Protect-VellumPdfDocument -OwnerPassword $ownerPw -Permission Print |
            Save-VellumPdfDocument -Path ./owner-only.pdf
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [securestring]$UserPassword,

        [securestring]$OwnerPassword,

        [ValidateSet('None', 'Print', 'Modify', 'Copy', 'Annotate',
            'FillForms', 'Extract', 'Assemble', 'PrintHighRes', 'All')]
        [string[]]$Permission = @('All'),

        [switch]$EncryptMetadata
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Protect-VellumPdfDocument'

        # Applying encryption twice leaves an orphaned /Encrypt object in the
        # output (the second settings win, the first linger unreferenced).
        if ($Document.PSObject.Properties['PSVellumProtected']) {
            throw ('Protect-VellumPdfDocument: this document is already protected. ' +
                'Encryption can only be applied once per document.')
        }

        # The library rejects Encrypt() + Sign() at save time; fail fast here
        # with the same constraint so the error points at the right cmdlet.
        if ($Document.PSObject.Properties['PSVellumSignature']) {
            throw ('Protect-VellumPdfDocument: encryption and digital signatures cannot be combined. ' +
                'Remove the Set-VellumPdfSignature call to encrypt this document.')
        }

        # Require at least one password.
        if (-not $PSBoundParameters.ContainsKey('UserPassword') -and
            -not $PSBoundParameters.ContainsKey('OwnerPassword')) {
            throw 'Protect-VellumPdfDocument: at least one of -UserPassword or -OwnerPassword must be supplied.'
        }

        # Fail fast: PDF/A forbids encryption (ISO 19005-2 section 6.3.1).
        if ($Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None) {
            throw ("Protect-VellumPdfDocument: PDF/A conformance ($($Document.Conformance)) does not allow " +
                'encryption. Remove -Conformance or use a non-conformant document.')
        }

        # Build combined permissions flags.
        $flags = [VellumPdf.Encryption.PdfPermissions]::None
        foreach ($p in $Permission) {
            $flags = $flags -bor [VellumPdf.Encryption.PdfPermissions]$p
        }

        $settings = [VellumPdf.Encryption.PdfEncryptionSettings]::new()
        $settings.Permissions = $flags

        # Convert SecureString passwords to plain text only at the point of assignment.
        if ($PSBoundParameters.ContainsKey('UserPassword')) {
            $settings.UserPassword = [System.Net.NetworkCredential]::new('', $UserPassword).Password
        }
        if ($PSBoundParameters.ContainsKey('OwnerPassword')) {
            $settings.OwnerPassword = [System.Net.NetworkCredential]::new('', $OwnerPassword).Password
        }

        if ($PSBoundParameters.ContainsKey('EncryptMetadata')) {
            $settings.EncryptMetadata = $EncryptMetadata.IsPresent
        }

        [void]$Document.Encrypt($settings)
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumProtected', $true))
        $Document
    }
}
