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
        fail-fast check here gives an earlier, more actionable message. A PDF/UA-1
        document, in contrast, may be encrypted as long as -Permission includes
        Extract, so assistive technology can still read the content.

        OTHER CONSTRAINTS (VellumPdf 2.x): an empty -OwnerPassword beside a
        non-empty -UserPassword is refused (such a file would open with full owner
        access and no password), and encryption cannot be combined with
        New-VellumPdfDocument -UseObjectStreams.

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
        Defaults to All. Note that an owner password with the default All and no
        user password leaves the document fully open (the cmdlet warns in that
        case). PDF permission flags are advisory: a reader may ignore them, and
        anyone with the owner password can remove them.
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
    [OutputType([VellumPdf.Layout.Document], [VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Document,

        [securestring]$UserPassword,

        [securestring]$OwnerPassword,

        [ValidateSet('None', 'Print', 'Modify', 'Copy', 'Annotate',
            'FillForms', 'Extract', 'Assemble', 'PrintHighRes', 'All')]
        [string[]]$Permission = @('All'),

        [switch]$EncryptMetadata
    )

    process {
        try {
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

            # Owner-password-only protection with the default (All) permission set
            # opens the document with no password and grants every permission - i.e.
            # nothing is actually restricted. That is rarely the intent of "protect
            # with an owner password", so warn the caller to narrow -Permission.
            if ($PSBoundParameters.ContainsKey('OwnerPassword') -and
                -not $PSBoundParameters.ContainsKey('UserPassword') -and
                -not $PSBoundParameters.ContainsKey('Permission')) {
                Write-Warning ('Protect-VellumPdfDocument: an owner password with no user password and the ' +
                    'default -Permission All opens the document without a password and grants every ' +
                    'permission, so nothing is restricted. Pass -Permission to limit operations. PDF ' +
                    'permission flags are advisory - a reader may ignore them, and the owner password removes them.')
            }

            # Build combined permissions flags.
            $flags = [VellumPdf.Encryption.PdfPermissions]::None
            foreach ($p in $Permission) {
                $flags = $flags -bor [VellumPdf.Encryption.PdfPermissions]$p
            }

            # Fail fast on the combinations the engine rejects at Save time.
            # PDF/A forbids encryption (ISO 19005-2 section 6.3.1). PDF/UA-1 allows it
            # only while the permissions keep content extraction for assistive
            # technology (ISO 14289-1, 7.16): VellumPdf 2.x accepts PDF/UA-1 + encryption
            # exactly when the Extract permission is present.
            $conformance = $Document.Conformance
            if ($conformance -eq [VellumPdf.Document.PdfConformance]::PdfUA1) {
                if (-not ($flags -band [VellumPdf.Encryption.PdfPermissions]::Extract)) {
                    throw ('Protect-VellumPdfDocument: a PDF/UA-1 document may be encrypted only when -Permission ' +
                        'includes Extract (assistive technology must be able to read the content).')
                }
            }
            elseif ($conformance -ne [VellumPdf.Document.PdfConformance]::None) {
                throw ("Protect-VellumPdfDocument: PDF/A conformance ($conformance) does not allow " +
                    'encryption. Remove -Conformance or use a non-conformant document.')
            }

            # A linearized ("fast web view") file cannot be encrypted (page documents only).
            if ($Document -is [VellumPdf.Document.PdfDocument] -and $Document.Linearize) {
                throw ('Protect-VellumPdfDocument: encryption cannot be combined with a linearized document ' +
                    '(New-VellumPdfPageDocument -Linearize). Create the document without -Linearize.')
            }

            # The engine cannot write encrypted files with object streams.
            if ($Document.UseObjectStreams) {
                throw ('Protect-VellumPdfDocument: encryption cannot be combined with object streams ' +
                    '(New-VellumPdfDocument -UseObjectStreams). Create the document without -UseObjectStreams.')
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

            # VellumPdf 2.2 refuses an empty owner password beside a real user
            # password: such a file opens with owner access and no password at all.
            if ($settings.OwnerPassword -eq '' -and $settings.UserPassword) {
                throw ('Protect-VellumPdfDocument: an empty -OwnerPassword with a non-empty -UserPassword would ' +
                    'let anyone open the file with full owner access. Pass a real owner password or omit -OwnerPassword.')
            }

            if ($PSBoundParameters.ContainsKey('EncryptMetadata')) {
                $settings.EncryptMetadata = $EncryptMetadata.IsPresent
            }

            [void]$Document.Encrypt($settings)
            $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumProtected', $true))
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
