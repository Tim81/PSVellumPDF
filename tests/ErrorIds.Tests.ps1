#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Stable error ids: every error carries an id callers can filter on (PSVellumPDF.*), an exception type they can
# catch, and a category, with the message text unchanged. PowerShell appends ',<function name>' to the
# FullyQualifiedErrorId of an advanced function, so the id is compared with -BeLike 'PSVellumPDF.X*'.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    function script:New-Page { New-VellumPdfPageDocument | Add-VellumPdfPage }

    # Runs a script block and returns the error it threw (or $null).
    function script:Get-Failure([scriptblock]$Run) {
        try { & $Run | Out-Null } catch { return $_ }
        $null
    }
    # Runs a reader cmdlet over a path and returns the non-terminating errors it reported (2>&1 sees only those).
    function script:Get-ReaderError([string]$Name, [hashtable]$Arguments) {
        @(& $Name @Arguments -ErrorAction Continue 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    }

    $script:password = ConvertTo-SecureString 'secret' -AsPlainText -Force
    $script:locked = Join-Path $TestDrive 'locked.pdf'
    New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Secret' |
        Protect-VellumPdfDocument -UserPassword $script:password -OwnerPassword (ConvertTo-SecureString 'owner' -AsPlainText -Force) |
        Save-VellumPdfDocument -Path $script:locked | Out-Null
    $script:junk = Join-Path $TestDrive 'junk.pdf'
    Set-Content -LiteralPath $script:junk -Value 'this is not a PDF'
    $script:empty = Join-Path $TestDrive 'empty.pdf'
    [System.IO.File]::WriteAllBytes($script:empty, [byte[]]@())
    $script:missing = Join-Path $TestDrive 'missing.pdf'
    $script:good = Join-Path $TestDrive 'good.pdf'
    New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Good' | Save-VellumPdfDocument -Path $script:good | Out-Null
    $script:ExpectedKinds = @{
        FileNotFound     = @{ Exception = 'System.Management.Automation.ItemNotFoundException'; Category = 'ObjectNotFound' }
        InvalidArgument  = @{ Exception = 'System.ArgumentException'; Category = 'InvalidArgument' }
        PasswordRequired = @{ Exception = 'System.UnauthorizedAccessException'; Category = 'SecurityError' }
        InvalidPdf       = @{ Exception = 'System.IO.InvalidDataException'; Category = 'InvalidData' }
        NotConformant    = @{ Exception = 'System.InvalidOperationException'; Category = 'InvalidResult' }
        FileReadError    = @{ Exception = 'System.IO.IOException'; Category = 'ReadError' }
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Terminating errors carry a stable id, a typed exception and a category' {
    It '<Name>: <Id>' -ForEach @(
        @{ Name = 'Add-VellumPdfImage on a missing file'; Id = 'FileNotFound'; Message = '*Add-VellumPdfImage: file not found:*'
            Run = { New-VellumPdfDocument | Add-VellumPdfImage -Path (Join-Path $TestDrive 'nope.png') -Width 10 } }
        @{ Name = 'Add-VellumPdfPageImage on a missing file'; Id = 'FileNotFound'; Message = '*Add-VellumPdfPageImage: file not found:*'
            Run = { New-Page | Add-VellumPdfPageImage -Path (Join-Path $TestDrive 'nope.png') -X 1 -Y 1 -Width 10 -Decorative } }
        @{ Name = 'Register-VellumPdfFont on a missing file'; Id = 'FileNotFound'; Message = '*Register-VellumPdfFont: font file not found:*'
            Run = { New-VellumPdfDocument | Register-VellumPdfFont -Path (Join-Path $TestDrive 'nope.ttf') } }
        @{ Name = 'Save-VellumPdfDocument into a missing directory'; Id = 'FileNotFound'; Message = '*Save-VellumPdfDocument: directory not found:*'
            Run = { New-VellumPdfDocument | Add-VellumPdfParagraph -Text x | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'no' 'such' 'dir' 'f.pdf') } }
        @{ Name = 'a coordinate out of range'; Id = 'InvalidArgument'; Message = '*Add-VellumPdfText: -X must be a finite number between*'
            Run = { New-Page | Add-VellumPdfText -Text x -X 99999 -Y 1 } }
        @{ Name = 'a malformed language tag'; Id = 'InvalidArgument'; Message = '*New-VellumPdfDocument: -Language ''not a tag'' is not a BCP 47 language tag*'
            Run = { New-VellumPdfDocument -Language 'not a tag' } }
        @{ Name = 'an unpaired surrogate'; Id = 'InvalidArgument'; Message = '*Add-VellumPdfText: the text contains an unpaired UTF-16 surrogate*'
            Run = { New-Page | Add-VellumPdfText -Text ([string][char]0xD800) -X 10 -Y 10 } }
        @{ Name = 'an unknown colour'; Id = 'InvalidArgument'; Message = '*ConvertTo-VellumColor: unrecognised colour*'
            Run = { New-VellumPdfDocument | Add-VellumPdfParagraph -Text x -Color 'no such colour' } }
        @{ Name = 'a page out of range'; Id = 'InvalidArgument'; Message = '*is out of range; the document has 1 page(s)*'
            Run = { New-Page | Add-VellumPdfText -Text x -X 1 -Y 1 -Page 5 } }
        @{ Name = 'an unknown culture'; Id = 'InvalidArgument'; Message = '*New-VellumPdfDocument: -Culture ''xx-NOPE'' is not a known culture name*'
            Run = { New-VellumPdfDocument -Culture 'xx-NOPE' } }
        @{ Name = 'a document that was already saved'; Id = 'InvalidArgument'; Message = '*already saved*'
            Run = { $d = New-VellumPdfDocument | Add-VellumPdfParagraph -Text x; $d | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'twice.pdf') | Out-Null; $d | Add-VellumPdfParagraph -Text y } }
        @{ Name = 'Save -Validate on a document that is not conformant'; Id = 'NotConformant'; Message = '*Save-VellumPdfDocument: the rendered PDF is not * compliant*'
            Run = { New-VellumPdfDocument -Conformance PdfUA1 | Add-VellumPdfParagraph -Text x | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'nc.pdf') -Validate } }
    ) {
        $kind = $script:ExpectedKinds[$Id]
        $failure = Get-Failure $Run
        $failure | Should -Not -BeNullOrEmpty
        $failure.FullyQualifiedErrorId | Should -BeLike "PSVellumPDF.$Id*"
        $failure.CategoryInfo.Category | Should -Be $kind.Category
        $failure.Exception.GetType().FullName | Should -Be $kind.Exception
        $failure.Exception.Message | Should -BeLike $Message
    }

    It 'a failed -Validate does not write the file' {
        $path = Join-Path $TestDrive 'nv-ids.pdf'
        Get-Failure { New-VellumPdfDocument -Conformance PdfUA1 | Add-VellumPdfParagraph -Text x | Save-VellumPdfDocument -Path $path -Validate } | Out-Null
        Test-Path $path | Should -BeFalse
    }

    It 'catch [<Type>] works for <Id>' -ForEach @(
        @{ Id = 'FileNotFound'; Type = [System.Management.Automation.ItemNotFoundException]; Run = { New-VellumPdfDocument | Add-VellumPdfImage -Path (Join-Path $TestDrive 'nope.png') -Width 10 } }
        @{ Id = 'InvalidArgument'; Type = [System.ArgumentException]; Run = { New-Page | Add-VellumPdfText -Text x -X 99999 -Y 1 } }
        @{ Id = 'NotConformant'; Type = [System.InvalidOperationException]; Run = { New-VellumPdfDocument -Conformance PdfUA1 | Add-VellumPdfParagraph -Text x | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'nc2.pdf') -Validate } }
    ) {
        $caught = $null
        try { & $Run | Out-Null }
        catch [System.Management.Automation.ItemNotFoundException] { $caught = 'ItemNotFoundException' }
        catch [System.ArgumentException] { $caught = 'ArgumentException' }
        catch [System.InvalidOperationException] { $caught = 'InvalidOperationException' }
        $caught | Should -Be $Type.Name
    }

    It 'the error id survives -ErrorAction SilentlyContinue and -ErrorAction Stop (terminating either way)' {
        foreach ($action in 'SilentlyContinue', 'Stop', 'Continue') {
            $failure = Get-Failure { New-VellumPdfDocument | Add-VellumPdfImage -Path (Join-Path $TestDrive 'nope.png') -Width 10 -ErrorAction $action }
            $failure.FullyQualifiedErrorId | Should -BeLike 'PSVellumPDF.FileNotFound*'
        }
    }
}

Describe 'Every other message-only error gets PSVellumPDF.<Cmdlet> and the category InvalidOperation' {
    It '<Name>' -ForEach @(
        @{ Name = 'Add-VellumPdfTable'; Message = '*Add-VellumPdfTable: -Row mixes record rows*'
            Run = { New-VellumPdfDocument | Add-VellumPdfTable -Row @([pscustomobject]@{ A = 1 }, @('x')) } }
        @{ Name = 'Add-VellumPdfPageTable'; Message = '*Add-VellumPdfPageTable: the table has no cells*'
            Run = { New-Page | Add-VellumPdfPageTable -X 10 -Y 700 -Width 100 -Row @() } }
        @{ Name = 'Add-VellumPdfList'; Message = '*Add-VellumPdfList: a nested-item hashtable must include a ''Text'' key*'
            Run = { New-VellumPdfDocument | Add-VellumPdfList -Item @{ Children = 'x' } } }
        @{ Name = 'Protect-VellumPdfDocument'; Message = '*Protect-VellumPdfDocument: at least one of -UserPassword or -OwnerPassword*'
            Run = { New-VellumPdfDocument | Add-VellumPdfParagraph -Text x | Protect-VellumPdfDocument } }
    ) {
        $failure = Get-Failure $Run
        $failure | Should -Not -BeNullOrEmpty
        $failure.FullyQualifiedErrorId | Should -BeLike "PSVellumPDF.$Name*"
        $failure.CategoryInfo.Category | Should -Be 'InvalidOperation'
        $failure.Exception | Should -BeOfType ([System.InvalidOperationException])
        $failure.Exception.Message | Should -BeLike $Message
    }

    It 'catches as System.InvalidOperationException and keeps the original exception inside' {
        $caught = $null
        try { New-VellumPdfDocument | Add-VellumPdfTable -Row @([pscustomobject]@{ A = 1 }, @('x')) | Out-Null }
        catch [System.InvalidOperationException] { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.InnerException | Should -BeOfType ([System.Management.Automation.RuntimeException])
        $caught.Exception.InnerException.Message | Should -Be $caught.Exception.Message
    }

    It 'the id is the same for the same cmdlet whatever the message' {
        $first = Get-Failure { New-VellumPdfDocument | Add-VellumPdfTable -Row @([pscustomobject]@{ A = 1 }, @('x')) }
        $second = Get-Failure { New-VellumPdfDocument | Add-VellumPdfTable -Row @() }
        $first.Exception.Message | Should -Not -Be $second.Exception.Message
        ($first.FullyQualifiedErrorId -replace ',.*$') | Should -Be 'PSVellumPDF.Add-VellumPdfTable'
        ($second.FullyQualifiedErrorId -replace ',.*$') | Should -Be 'PSVellumPDF.Add-VellumPdfTable'
    }
}

Describe 'Errors that already have a proper record pass through unchanged' {
    It 'keeps a parameter validation error''s own id' {
        $failure = Get-Failure { New-VellumPdfDocument -Margin -5 }
        $failure.FullyQualifiedErrorId | Should -Not -BeLike 'PSVellumPDF.*'
        $failure.FullyQualifiedErrorId | Should -BeLike '*ParameterArgumentValidationError*'
    }

    It 'Resolve-VellumPdfErrorRecord returns a typed record as it is, and wraps only a message-only throw' {
        InModuleScope PSVellumPDF {
            $typed = New-VellumPdfErrorRecord InvalidPdf 'Demo: bad pdf'
            (Resolve-VellumPdfErrorRecord -ErrorRecord $typed -CommandName 'Demo') | Should -Be $typed
            $engine = [System.Management.Automation.ErrorRecord]::new([System.IO.IOException]::new('disk'), 'SomeId', 'ReadError', $null)
            (Resolve-VellumPdfErrorRecord -ErrorRecord $engine -CommandName 'Demo') | Should -Be $engine
            $messageOnly = try { throw 'Demo: plain message' } catch { $_ }
            $resolved = Resolve-VellumPdfErrorRecord -ErrorRecord $messageOnly -CommandName 'Demo'
            $resolved.FullyQualifiedErrorId | Should -Be 'PSVellumPDF.Demo'
            $resolved.CategoryInfo.Category | Should -Be 'InvalidOperation'
            $resolved.Exception.Message | Should -Be 'Demo: plain message'
        }
    }

    It 'New-VellumPdfErrorRecord builds every kind with its exception type and category' {
        InModuleScope PSVellumPDF {
            $expected = @{
                FileNotFound     = @('System.Management.Automation.ItemNotFoundException', 'ObjectNotFound')
                InvalidArgument  = @('System.ArgumentException', 'InvalidArgument')
                PasswordRequired = @('System.UnauthorizedAccessException', 'SecurityError')
                InvalidPdf       = @('System.IO.InvalidDataException', 'InvalidData')
                NotConformant    = @('System.InvalidOperationException', 'InvalidResult')
                FileReadError    = @('System.IO.IOException', 'ReadError')
                InputError       = @('System.InvalidOperationException', 'InvalidData')
            }
            foreach ($id in $expected.Keys) {
                $record = New-VellumPdfErrorRecord $id "Demo: $id" -Target 'x'
                $record.FullyQualifiedErrorId | Should -Be "PSVellumPDF.$id"
                $record.Exception.GetType().FullName | Should -Be $expected[$id][0]
                $record.CategoryInfo.Category | Should -Be $expected[$id][1]
                $record.Exception.Message | Should -Be "Demo: $id"
                $record.TargetObject | Should -Be 'x'
            }
            (New-VellumPdfErrorRecord Command 'Demo: m' -CommandName 'Demo-Cmdlet').FullyQualifiedErrorId | Should -Be 'PSVellumPDF.Demo-Cmdlet'
        }
    }
}

Describe 'Reader cmdlets report per-file failures as non-terminating errors with the same ids' {
    It '<Name>: <Case> is <Id>' -ForEach @(
        foreach ($name in 'Get-VellumPdfInfo', 'Get-VellumPdfText', 'Test-VellumPdfConformance', 'Export-VellumPdfImage', 'Unprotect-VellumPdfDocument') {
            @{ Name = $name; Case = 'a missing file'; Id = 'FileNotFound'; Path = 'missing'; Message = '*file not found*missing.pdf*' }
            @{ Name = $name; Case = 'a file that is not a PDF'; Id = 'InvalidPdf'; Path = 'junk'; Message = '*not a well-formed PDF*' }
            @{ Name = $name; Case = 'an empty file'; Id = 'InvalidPdf'; Path = 'empty'; Message = '*is empty, so it is not a PDF*' }
            @{ Name = $name; Case = 'an encrypted file without the password'; Id = 'PasswordRequired'; Path = 'locked'; Message = '*needs a password*' }
        }
    ) {
        $path = Get-Variable -Scope Script -Name $Path -ValueOnly
        $arguments = @{ LiteralPath = $path }
        if ($Name -eq 'Test-VellumPdfConformance') { $arguments['Profile'] = 'PdfA2b' }
        if ($Name -eq 'Export-VellumPdfImage') { $arguments['DestinationPath'] = Join-Path $TestDrive "img-$([guid]::NewGuid().ToString('N'))" }
        if ($Name -eq 'Unprotect-VellumPdfDocument') { $arguments['DestinationPath'] = Join-Path $TestDrive "plain-$([guid]::NewGuid().ToString('N')).pdf" }
        $errors = Get-ReaderError $Name $arguments
        $errors.Count | Should -Be 1
        $kind = $script:ExpectedKinds[$Id]
        $errors[0].FullyQualifiedErrorId | Should -BeLike "PSVellumPDF.$Id*"
        $errors[0].CategoryInfo.Category | Should -Be $kind.Category
        $errors[0].Exception.GetType().FullName | Should -Be $kind.Exception
        $errors[0].Exception.Message | Should -BeLike $Message
        $errors[0].TargetObject | Should -Be $path
    }

    It 'an IOException while reading is PSVellumPDF.FileReadError' {
        InModuleScope PSVellumPDF {
            foreach ($exception in [System.IO.IOException]::new('disk'), [System.UnauthorizedAccessException]::new('denied')) {
                $record = [System.Management.Automation.ErrorRecord]::new($exception, 'Whatever', 'NotSpecified', $null)
                $converted = ConvertTo-VellumPdfFileError -ErrorRecord $record -Target 'x.pdf' -CommandName 'Get-VellumPdfInfo'
                $converted.FullyQualifiedErrorId | Should -Be 'PSVellumPDF.FileReadError'
                $converted.CategoryInfo.Category | Should -Be 'ReadError'
                $converted.Exception | Should -BeOfType ([System.IO.IOException])
                $converted.Exception.InnerException | Should -Be $exception
            }
        }
    }

    It 'a wildcard that matches nothing is PSVellumPDF.FileNotFound' {
        $errors = Get-ReaderError 'Get-VellumPdfInfo' @{ Path = (Join-Path $TestDrive 'nothing-*.pdf') }
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'PSVellumPDF.FileNotFound*'
        $errors[0].Exception.Message | Should -BeLike '*no file matches*'
    }

    It 'a wrong password is PSVellumPDF.PasswordRequired' {
        $wrong = ConvertTo-SecureString 'wrong' -AsPlainText -Force
        $errors = Get-ReaderError 'Get-VellumPdfInfo' @{ LiteralPath = $script:locked; Password = $wrong }
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'PSVellumPDF.PasswordRequired*'
        $errors[0].Exception | Should -BeOfType ([System.UnauthorizedAccessException])
    }

    It 'the good file is still processed after a failing one' {
        $result = @(Get-VellumPdfInfo -LiteralPath $script:missing, $script:good -ErrorAction SilentlyContinue)
        $result.Count | Should -Be 1
    }

    It '-ErrorAction Stop makes the typed exception catchable: <Case>' -ForEach @(
        @{ Case = 'FileNotFound'; Path = 'missing'; Type = [System.Management.Automation.ItemNotFoundException] }
        @{ Case = 'InvalidPdf'; Path = 'junk'; Type = [System.IO.InvalidDataException] }
        @{ Case = 'PasswordRequired'; Path = 'locked'; Type = [System.UnauthorizedAccessException] }
    ) {
        $path = Get-Variable -Scope Script -Name $Path -ValueOnly
        $caught = $null
        try { Get-VellumPdfInfo -LiteralPath $path -ErrorAction Stop | Out-Null }
        catch [System.Management.Automation.ItemNotFoundException] { $caught = 'ItemNotFoundException'; $record = $_ }
        catch [System.IO.InvalidDataException] { $caught = 'InvalidDataException'; $record = $_ }
        catch [System.UnauthorizedAccessException] { $caught = 'UnauthorizedAccessException'; $record = $_ }
        $caught | Should -Be $Type.Name
        $record.FullyQualifiedErrorId | Should -BeLike "PSVellumPDF.$Case*"
    }

    It 'Test-VellumPdfConformance without -Profile reports the same ids' {
        (Get-ReaderError 'Test-VellumPdfConformance' @{ LiteralPath = $script:locked })[0].FullyQualifiedErrorId | Should -BeLike 'PSVellumPDF.PasswordRequired*'
        (Get-ReaderError 'Test-VellumPdfConformance' @{ LiteralPath = $script:junk })[0].FullyQualifiedErrorId | Should -BeLike 'PSVellumPDF.InvalidPdf*'
    }

    It 'a failure that is none of these is PSVellumPDF.InputError' {
        InModuleScope PSVellumPDF {
            $record = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('something odd'), 'Whatever', 'NotSpecified', $null)
            $converted = ConvertTo-VellumPdfFileError -ErrorRecord $record -Target 'x.pdf' -CommandName 'Get-VellumPdfInfo'
            $converted.FullyQualifiedErrorId | Should -Be 'PSVellumPDF.InputError'
            $converted.CategoryInfo.Category | Should -Be 'InvalidData'
            $converted.Exception.Message | Should -Be "Get-VellumPdfInfo: 'x.pdf': something odd"
        }
    }
}
