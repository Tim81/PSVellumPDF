function Add-VellumPdfFormField {
    <#
    .SYNOPSIS
        Adds a fillable AcroForm field (text, check box, choice, radio group, button) to a page.
    .DESCRIPTION
        Places an interactive form field on a page of a page-based document, at the
        rectangle (-X, -Y, -Width, -Height) in points from the page's bottom-left.
        Types:

          Text        a text box; -Value is the initial text, -Multiline allows several lines
          CheckBox    -Checked sets the initial state
          Choice      a combo box (drop-down, default) or, with -List, a list box;
                      -Option lists the entries and -Selected the initial one
          Radio       a group of mutually exclusive buttons; -RadioOption describes the
                      buttons (page, rectangle and export value of each) and -Selected
                      the export value that starts selected
          PushButton  a button labelled -Caption

        -Name is the field's unique name (what a form processor reads); for Radio it
        names the group. Field names, values and captions may be Unicode, but the
        text drawn in the field's appearance supports Latin-1 and the Windows-1252
        punctuation (euro, curly quotes, dashes, ...) only; anything else is refused
        here rather than failing when the file is saved. Field appearances use
        Helvetica (and ZapfDingbats for check marks), which VellumPdf does not embed;
        ISO 19005-2 requires every font to be embedded, so a PDF/A page document
        cannot contain form fields and the cmdlet refuses them there. (The in-process
        preflight does not inspect fonts used only by form fields, so it will not
        flag such a file; a certified validator such as veraPDF does.)
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Type
        Text, CheckBox, Choice, Radio or PushButton.
    .PARAMETER Name
        The field name (unique within the document).
    .PARAMETER Page
        The 1-based page number (Text, CheckBox, Choice, PushButton). Default 1.
    .PARAMETER X
        Left edge in points.
    .PARAMETER Y
        Bottom edge in points.
    .PARAMETER Width
        Width in points.
    .PARAMETER Height
        Height in points.
    .PARAMETER Value
        Text: the initial text.
    .PARAMETER Checked
        CheckBox: start checked.
    .PARAMETER Option
        Choice: the list of entries.
    .PARAMETER Selected
        Choice: the initially selected entry. Radio: the initially selected export value.
    .PARAMETER List
        Choice: a list box instead of a drop-down combo box.
    .PARAMETER RadioOption
        Radio: one hashtable per button: @{ Page = 1; X = 100; Y = 500; Width = 14; Height = 14; ExportValue = 'yes' }
    .PARAMETER Caption
        PushButton: the label.
    .PARAMETER FontSize
        Text size in the field (default 12). Must be a finite number greater than 0.
    .PARAMETER ReadOnly
        The user cannot change the field.
    .PARAMETER Required
        The field must be filled in before submitting.
    .PARAMETER Multiline
        Text: allow several lines.
    .EXAMPLE
        $doc | Add-VellumPdfFormField Text -Name email -X 72 -Y 700 -Width 250 -Height 20 -Value 'you@example.com'
    .EXAMPLE
        $doc | Add-VellumPdfFormField Radio -Name plan -Selected basic -RadioOption @(
            @{ X = 72; Y = 650; Width = 14; Height = 14; ExportValue = 'basic' },
            @{ X = 72; Y = 625; Width = 14; Height = 14; ExportValue = 'pro' })
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Text', 'CheckBox', 'Choice', 'Radio', 'PushButton')]
        [string]$Type,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [double]$X, [double]$Y,
        [ValidateRange(0.01, 1000000.0)] [double]$Width,
        [ValidateRange(0.01, 1000000.0)] [double]$Height,

        [string]$Value = '',
        [switch]$Checked,
        [string[]]$Option,
        [string]$Selected,
        [switch]$List,
        [hashtable[]]$RadioOption,
        [string]$Caption,

        [double]$FontSize = 12,
        [switch]$ReadOnly,
        [switch]$Required,
        [switch]$Multiline
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfFormField'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfFormField'
            $bound = $PSBoundParameters

            if ($Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None) {
                throw ('Add-VellumPdfFormField: form fields draw with the non-embedded Helvetica font, which PDF/A forbids. ' +
                    'Create the page document without -Conformance to use forms.')
            }
            Write-VellumPdfUntaggedWarning -Document $Document -CommandName 'Add-VellumPdfFormField' -What 'a form field'
            if (-not [double]::IsFinite($FontSize) -or $FontSize -le 0) {
                throw "Add-VellumPdfFormField: -FontSize must be a finite number greater than 0; got $FontSize."
            }

            # Options that belong to one field type only.
            $only = @{
                Value = 'Text'; Multiline = 'Text'; Checked = 'CheckBox'; Option = 'Choice'; List = 'Choice'
                RadioOption = 'Radio'; Caption = 'PushButton'
            }
            foreach ($n in $only.Keys) {
                if ($bound.ContainsKey($n) -and $only[$n] -ne $Type) { throw "Add-VellumPdfFormField: -$n applies to -Type $($only[$n]) only." }
            }
            if ($bound.ContainsKey('Selected') -and $Type -notin 'Choice', 'Radio') {
                throw 'Add-VellumPdfFormField: -Selected applies to -Type Choice and Radio only.'
            }

            # The appearance stream can draw Latin-1 and the Windows-1252 punctuation; anything else makes Save fail
            # (after the document is spent), so check here.
            $assertDrawable = {
                param([string]$What, [string]$Text)
                foreach ($ch in $Text.ToCharArray()) {
                    $code = [int]$ch
                    if (-not (Test-VellumPdfWinAnsiChar -CodeUnit $code)) {
                        throw ("Add-VellumPdfFormField: $What contains U+$($code.ToString('X4')), which the field appearance cannot draw " +
                            '(Latin-1 and Windows-1252 punctuation only).')
                    }
                }
            }

            $fieldOptions = [VellumPdf.Forms.FormFieldOptions]::new()
            $fieldOptions.FontSize = $FontSize
            if ($ReadOnly) { $fieldOptions.ReadOnly = $true }
            if ($Required) { $fieldOptions.Required = $true }
            if ($Multiline) { $fieldOptions.Multiline = $true }

            $rect = {
                param($x, $y, $w, $h, $what)
                foreach ($v in $x, $y, $w, $h) {
                    if ($null -eq $v -or -not [double]::IsFinite([double]$v)) { throw "Add-VellumPdfFormField: $what needs finite X, Y, Width and Height." }
                }
                if ([double]$w -le 0 -or [double]$h -le 0) { throw "Add-VellumPdfFormField: $what needs a positive Width and Height." }
                [VellumPdf.Document.PdfRectangle]::new([double]$x, [double]$y, [double]$x + [double]$w, [double]$y + [double]$h)
            }

            if ($Type -eq 'Radio') {
                foreach ($n in 'Page', 'X', 'Y', 'Width', 'Height') {
                    if ($bound.ContainsKey($n)) {
                        throw "Add-VellumPdfFormField: -$n does not apply to -Type Radio; give each button's own Page/X/Y/Width/Height in -RadioOption."
                    }
                }
            }
            else {
                foreach ($req in 'X', 'Y', 'Width', 'Height') {
                    if (-not $bound.ContainsKey($req)) { throw "Add-VellumPdfFormField: -Type $Type needs -$req." }
                }
                $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfFormField'
                $box = & $rect $X $Y $Width $Height "-Type $Type"
            }

            switch ($Type) {
                'Text' {
                    & $assertDrawable '-Value' $Value
                    $Document.AddTextField($pdfPage, $Name, $box, $Value, $fieldOptions)
                }
                'CheckBox' { $Document.AddCheckBox($pdfPage, $Name, $box, [bool]$Checked, $fieldOptions) }
                'Choice' {
                    if (-not $Option -or $Option.Count -eq 0) { throw 'Add-VellumPdfFormField: -Type Choice needs -Option.' }
                    foreach ($o in $Option) { & $assertDrawable "option '$o'" $o }
                    if ($bound.ContainsKey('Selected') -and $Selected -notin $Option) {
                        throw "Add-VellumPdfFormField: -Selected '$Selected' is not one of the -Option entries."
                    }
                    $sel = if ($bound.ContainsKey('Selected')) { $Selected } else { $null }
                    $Document.AddChoiceField($pdfPage, $Name, $box, [string[]]$Option, $sel, (-not $List), $fieldOptions)
                }
                'PushButton' {
                    if (-not $bound.ContainsKey('Caption')) { throw 'Add-VellumPdfFormField: -Type PushButton needs -Caption.' }
                    & $assertDrawable '-Caption' $Caption
                    $Document.AddPushButton($pdfPage, $Name, $box, $Caption, $fieldOptions)
                }
                'Radio' {
                    if (-not $RadioOption -or $RadioOption.Count -eq 0) { throw 'Add-VellumPdfFormField: -Type Radio needs -RadioOption.' }
                    $buttons = [System.Collections.Generic.List[VellumPdf.Forms.RadioOption]]::new()
                    $i = 0
                    foreach ($ro in $RadioOption) {
                        $i++
                        if (-not $ro.ContainsKey('ExportValue') -or [string]::IsNullOrEmpty([string]$ro['ExportValue'])) {
                            throw "Add-VellumPdfFormField: radio button $i needs an ExportValue."
                        }
                        $roPage = Get-VellumPdfPage -Document $Document -Page $(if ($ro.ContainsKey('Page')) { [int]$ro['Page'] } else { $Page }) -CommandName 'Add-VellumPdfFormField'
                        $roBox = & $rect $ro['X'] $ro['Y'] $ro['Width'] $ro['Height'] "radio button $i"
                        $buttons.Add([VellumPdf.Forms.RadioOption]::new($roPage, $roBox, [string]$ro['ExportValue']))
                    }
                    if ($bound.ContainsKey('Selected') -and $Selected -notin $buttons.ExportValue) {
                        throw "Add-VellumPdfFormField: -Selected '$Selected' is not an ExportValue of any radio button."
                    }
                    $sel = if ($bound.ContainsKey('Selected')) { $Selected } else { $null }
                    $Document.AddRadioButtonGroup($Name, $buttons, $sel, $fieldOptions)
                }
            }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
