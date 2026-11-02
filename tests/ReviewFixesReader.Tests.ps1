#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Review fixes for the Reader cmdlets (Get-VellumPdfInfo, Get-VellumPdfText, Test-VellumPdfConformance,
# Export-VellumPdfImage, Unprotect-VellumPdfDocument): per-file non-terminating errors, one input in
# memory at a time, unique image file names across inputs, -AllowReconstruction everywhere, binding by
# property name.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    $script:gray16 = Join-Path $PSScriptRoot 'assets' 'gray16.png'
    $script:pw = ConvertTo-SecureString 'sekret' -AsPlainText -Force

    # a.pdf, c.pdf valid (with an image, PDF/A-2b so every cmdlet has something to do); b.pdf is not a PDF.
    $script:dir = Join-Path $TestDrive 'mixed'
    New-Item -ItemType Directory -Path $script:dir | Out-Null
    foreach ($n in 'a', 'c') {
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text "File $n" | Add-VellumPdfImage -Path $script:gray16 -Width 30 |
            Save-VellumPdfDocument -Path (Join-Path $script:dir "$n.pdf") | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $script:dir 'b.pdf') -Value 'this is not a PDF'
    $script:a = Join-Path $script:dir 'a.pdf'
    $script:b = Join-Path $script:dir 'b.pdf'
    $script:c = Join-Path $script:dir 'c.pdf'

    $script:locked = Join-Path $TestDrive 'locked.pdf'
    New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Secret text' |
        Protect-VellumPdfDocument -UserPassword $script:pw -OwnerPassword (ConvertTo-SecureString 'owner' -AsPlainText -Force) |
        Save-VellumPdfDocument -Path $script:locked | Out-Null

    $script:bracket = Join-Path $TestDrive 'report[1].pdf'
    New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Bracket text' | Add-VellumPdfImage -Path $script:gray16 -Width 30 |
        Save-VellumPdfDocument -Path $script:bracket | Out-Null

    # Runs a reader cmdlet over piped input; returns what it wrote and the (non-terminating) errors it reported.
    # 2>&1 sees only the records the cmdlet wrote (-ErrorVariable would also collect exceptions caught inside).
    function script:Invoke-Reader([string]$Name, $InputObject, [hashtable]$Extra = @{}, [string]$ErrorAction = 'Continue') {
        $Extra['ErrorAction'] = $ErrorAction
        $all = if ($null -eq $InputObject) { @(& $Name @Extra 2>&1) } else { @($InputObject | & $Name @Extra 2>&1) }
        [pscustomobject]@{
            Output = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
            Errors = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        }
    }
    # The extra arguments each reader needs to run in these tests.
    function script:Get-ReaderArgument([string]$Name, [string]$Tag) {
        switch ($Name) {
            'Test-VellumPdfConformance' { @{ Profile = 'PdfA2b' } }
            'Export-VellumPdfImage' { @{ DestinationPath = (Join-Path $TestDrive "out-$Tag"); Force = $true } }
            default { @{} }
        }
    }

    # The same file with the xref table and trailer cut off.
    function script:Get-Truncated([string]$Path) {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        , [byte[]]$bytes[0..($bytes.Length - 120)]
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'A bad input file is a non-terminating error for that file' {
    It '<Name> goes on after the bad file and reports it with the file as TargetObject' -ForEach @(
        @{ Name = 'Get-VellumPdfInfo' }, @{ Name = 'Get-VellumPdfText' }, @{ Name = 'Test-VellumPdfConformance' }, @{ Name = 'Export-VellumPdfImage' }
    ) {
        $r = Invoke-Reader $Name (Get-ChildItem (Join-Path $script:dir '*.pdf')) (Get-ReaderArgument $Name 'perfile')
        $r.Output.Count | Should -Be 2   # a.pdf and c.pdf; c.pdf is processed even though b.pdf failed
        $r.Errors.Count | Should -Be 1
        $r.Errors[0].TargetObject | Should -Be $script:b
        $r.Errors[0].Exception.Message | Should -BeLike "${Name}: *b.pdf*not a well-formed PDF*"
        $r.Errors[0].FullyQualifiedErrorId | Should -Match '^PdfInputError'
    }

    It '<Name> -ErrorAction Stop stops at the first bad file' -ForEach @(
        @{ Name = 'Get-VellumPdfInfo' }, @{ Name = 'Get-VellumPdfText' }, @{ Name = 'Test-VellumPdfConformance' }, @{ Name = 'Export-VellumPdfImage' }
    ) {
        $extra = Get-ReaderArgument $Name 'stop'
        $extra['ErrorAction'] = 'Stop'
        $got = [System.Collections.Generic.List[object]]::new()
        { Get-ChildItem (Join-Path $script:dir '*.pdf') | & $Name @extra | ForEach-Object { $got.Add($_) } } |
            Should -Throw '*not a well-formed PDF*'
        $got.Count | Should -Be 1
    }

    It 'a good file before a missing path is still returned by -Path good, missing' {
        $r = Invoke-Reader Get-VellumPdfInfo $null @{ Path = $script:a, (Join-Path $script:dir 'missing.pdf') }
        $r.Output.Count | Should -Be 1
        $r.Output[0].Path | Should -Be $script:a
        $r.Errors.Count | Should -Be 1
        $r.Errors[0].Exception.Message | Should -BeLike '*file not found*missing.pdf*'
        $r.Errors[0].Exception | Should -BeOfType ([System.IO.FileNotFoundException])
        $r.Errors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
    }

    It 'reports a path that matches nothing as an error, then carries on' {
        $r = Invoke-Reader Get-VellumPdfText $null @{ Path = (Join-Path $script:dir 'nomatch*.pdf'), $script:a }
        $r.Output.Count | Should -Be 1
        $r.Errors[0].Exception.Message | Should -BeLike '*no file matches*'
    }

    It 'an empty file and an empty byte array are errors for that input only' {
        $empty = Join-Path $TestDrive 'empty-one.pdf'
        [System.IO.File]::WriteAllBytes($empty, [byte[]]@())
        $r = Invoke-Reader Get-VellumPdfInfo $null @{ LiteralPath = $empty, $script:a }
        $r.Output.Count | Should -Be 1
        $r.Errors[0].Exception.Message | Should -BeLike '*is empty, so it is not a PDF*'
        $r = Invoke-Reader Get-VellumPdfInfo $null @{ Bytes = [byte[]]@() }
        $r.Output.Count | Should -Be 0
        $r.Errors[0].Exception.Message | Should -BeLike '*byte array is empty*'
    }

    It 'a missing password and a page that does not exist are per-file errors' {
        $r = Invoke-Reader Get-VellumPdfText @($script:locked, $script:a) @{ Page = 1 }
        $r.Output.Count | Should -Be 1
        $r.Errors.Count | Should -Be 1
        $r.Errors[0].Exception.Message | Should -BeLike '*needs a password*'
        $r = Invoke-Reader Get-VellumPdfText @($script:a, $script:c) @{ Page = 99 }
        $r.Output.Count | Should -Be 0
        $r.Errors.Count | Should -Be 2   # both files lack page 99; both are reported
    }

    It 'Test-VellumPdfConformance -Quiet is false when a file could not be checked' {
        $r = Invoke-Reader Test-VellumPdfConformance (Get-ChildItem (Join-Path $script:dir '*.pdf')) @{ Profile = 'PdfA2b'; Quiet = $true }
        $r.Output | Should -Be @($false)
        $r.Errors.Count | Should -Be 1
    }

    It '-ErrorAction SilentlyContinue and Ignore keep the good results without errors' {
        foreach ($action in 'SilentlyContinue', 'Ignore') {
            $r = Invoke-Reader Get-VellumPdfInfo (Get-ChildItem (Join-Path $script:dir '*.pdf')) @{} $action
            $r.Output.Count | Should -Be 2
            $r.Errors.Count | Should -Be 0
        }
    }

    It 'parameter-level errors still terminate' {
        { Get-VellumPdfInfo -Path $script:a -MaxDiagnostics 0 } | Should -Throw
        { Get-VellumPdfText -Path $script:a -Bytes ([byte[]](1, 2)) } | Should -Throw
        { Export-VellumPdfImage -Path $script:a -DestinationPath $TestDrive -Page 0 } | Should -Throw
        { Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath $script:locked -Password $script:pw } | Should -Throw '*different file*'
    }

    It 'Unprotect-VellumPdfDocument reports an unreadable single input as a non-terminating error' {
        $out = Join-Path $TestDrive 'never.pdf'
        $r = Invoke-Reader Unprotect-VellumPdfDocument $null @{ Path = (Join-Path $script:dir 'missing.pdf'); DestinationPath = $out }
        $r.Output.Count | Should -Be 0
        $r.Errors[0].Exception.Message | Should -BeLike '*file not found*'
        $r = Invoke-Reader Unprotect-VellumPdfDocument $null @{ Path = $script:b; DestinationPath = $out }
        $r.Output.Count | Should -Be 0
        $r.Errors[0].TargetObject | Should -Be $script:b
        $r.Errors[0].Exception.Message | Should -BeLike '*not a well-formed PDF*'
        Test-Path $out | Should -BeFalse
    }
}

Describe 'Inputs are opened one at a time' {
    It 'Get-VellumPdfInput resolves paths without reading any file' {
        $items = InModuleScope PSVellumPDF -Parameters @{ Dir = $script:dir } {
            param($Dir)
            @(Get-VellumPdfInput -Path (Join-Path $Dir '*.pdf') -CommandName 'x' | ForEach-Object { [pscustomobject]@{ Name = $_.Name; HasData = $null -ne $_.Data } })
        }
        $items.Count | Should -Be 3
        $items.HasData | Should -Not -Contain $true
    }

    It 'a file is read only when its turn comes (one removed while the first is processed is reported, not preloaded)' {
        $dir = Join-Path $TestDrive 'lazy'
        New-Item -ItemType Directory $dir | Out-Null
        Copy-Item $script:a (Join-Path $dir '1.pdf')
        Copy-Item $script:a (Join-Path $dir '2.pdf')
        $seen = [System.Collections.Generic.List[string]]::new()
        $all = @(Get-VellumPdfInfo -Path (Join-Path $dir '*.pdf') -ErrorAction Continue 2>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) { $_ }
                else {
                    $seen.Add($_.Path)
                    Remove-Item -LiteralPath (Join-Path $dir '2.pdf') -ErrorAction SilentlyContinue   # after the first result, before the second read
                }
            })
        $seen.Count | Should -Be 1
        $all.Count | Should -Be 1
        $all[0].Exception.Message | Should -BeLike '*file not found*2.pdf*'
    }

    It 'Unprotect-VellumPdfDocument counts the matches before it reads any file' {
        Copy-Item $script:locked (Join-Path $TestDrive 'count-a.pdf')
        Copy-Item $script:locked (Join-Path $TestDrive 'count-b.pdf')
        Mock -ModuleName PSVellumPDF Read-VellumPdfInput { }
        { Unprotect-VellumPdfDocument -Path (Join-Path $TestDrive 'count-*.pdf') -DestinationPath (Join-Path $TestDrive 'count-out.pdf') -Password $script:pw } |
            Should -Throw '*matches 2 files*'
        Should -Invoke -ModuleName PSVellumPDF Read-VellumPdfInput -Times 0 -Exactly
    }
}

Describe 'Export-VellumPdfImage file names are unique within one call' {
    BeforeAll {
        $script:left = Join-Path $TestDrive 'left'
        $script:right = Join-Path $TestDrive 'right'
        foreach ($d in $script:left, $script:right) {
            New-Item -ItemType Directory $d | Out-Null
            New-VellumPdfDocument | Add-VellumPdfParagraph -Text $d | Add-VellumPdfImage -Path $script:gray16 -Width 30 |
                Save-VellumPdfDocument -Path (Join-Path $d 'report.pdf') | Out-Null
        }
    }

    It 'gives two inputs with the same file name different output names, with and without -Force' {
        foreach ($force in $true, $false) {
            $out = Join-Path $TestDrive "unique-$force"
            $files = @(Get-ChildItem $script:left, $script:right -Filter report.pdf -Recurse -File |
                    Export-VellumPdfImage -DestinationPath $out -Force:$force -ErrorAction Stop)
            $files.Count | Should -Be 2
            $files.Name | Sort-Object | Should -Be @('report-p1-i1-2.png', 'report-p1-i1.png')
            @(Get-ChildItem $out).Count | Should -Be 2
        }
    }

    It 'applies the same rule to -BaseName with several inputs' {
        $out = Join-Path $TestDrive 'basename'
        $files = @($script:left, $script:right | ForEach-Object { Join-Path $_ 'report.pdf' } |
                Export-VellumPdfImage -DestinationPath $out -BaseName logo)
        $files.Name | Should -Be @('logo-p1-i1.png', 'logo-p1-i1-2.png')
    }

    It 'a third input with the same name gets -3, and names are stable on a second run with -Force' {
        $out = Join-Path $TestDrive 'three'
        $inputs = (Join-Path $script:left 'report.pdf'), (Join-Path $script:right 'report.pdf'), (Join-Path $script:left 'report.pdf')
        (Export-VellumPdfImage -LiteralPath $inputs -DestinationPath $out).Name | Should -Be @('report-p1-i1.png', 'report-p1-i1-2.png', 'report-p1-i1-3.png')
        (Export-VellumPdfImage -LiteralPath $inputs -DestinationPath $out -Force).Name | Should -Be @('report-p1-i1.png', 'report-p1-i1-2.png', 'report-p1-i1-3.png')
        @(Get-ChildItem $out).Count | Should -Be 3
    }

    It 'never overwrites a file of an earlier run without -Force, and -Force overwrites pre-existing files' {
        $out = Join-Path $TestDrive 'preexisting'
        New-Item -ItemType Directory $out | Out-Null
        Set-Content -LiteralPath (Join-Path $out 'report-p1-i1.png') -Value 'old'
        $inputs = (Join-Path $script:left 'report.pdf'), (Join-Path $script:right 'report.pdf')
        $r = Invoke-Reader Export-VellumPdfImage $null @{ LiteralPath = $inputs; DestinationPath = $out }
        $r.Errors.Count | Should -Be 1
        $r.Errors[0].Exception.Message | Should -BeLike '*use -Force*'
        Get-Content -LiteralPath (Join-Path $out 'report-p1-i1.png') | Should -Be 'old'
        $r.Output.Name | Should -Be @('report-p1-i1-2.png')

        $forced = @(Export-VellumPdfImage -LiteralPath $inputs -DestinationPath $out -Force)
        $forced.Name | Should -Be @('report-p1-i1.png', 'report-p1-i1-2.png')
        Get-Content -LiteralPath (Join-Path $out 'report-p1-i1.png') -AsByteStream -TotalCount 4 | Should -Be @(137, 80, 78, 71)
    }
}

Describe '-AllowReconstruction on Export-VellumPdfImage and Unprotect-VellumPdfDocument' {
    It 'Export-VellumPdfImage fails on a truncated file with the hint, and recovers it with -AllowReconstruction' {
        $broken = Get-Truncated $script:a
        $path = Join-Path $TestDrive 'broken-img.pdf'
        [System.IO.File]::WriteAllBytes($path, $broken)
        $out = Join-Path $TestDrive 'recovered'
        { Export-VellumPdfImage -LiteralPath $path -DestinationPath $out -ErrorAction Stop } | Should -Throw '*Try -AllowReconstruction*'
        Test-Path $out | Should -BeFalse
        $files = @(Export-VellumPdfImage -LiteralPath $path -DestinationPath $out -AllowReconstruction -ReconstructionBudgetMultiplier 8)
        $files.Count | Should -Be 1
        $files[0].Name | Should -Be 'broken-img-p1-i1.png'
    }

    It 'Unprotect-VellumPdfDocument fails on a truncated file with the hint, and recovers it with -AllowReconstruction' {
        $path = Join-Path $TestDrive 'broken-locked.pdf'
        [System.IO.File]::WriteAllBytes($path, (Get-Truncated $script:locked))
        $out = Join-Path $TestDrive 'broken-open.pdf'
        { Unprotect-VellumPdfDocument -LiteralPath $path -DestinationPath $out -Password $script:pw -ErrorAction Stop } | Should -Throw '*Try -AllowReconstruction*'
        Test-Path $out | Should -BeFalse
        $result = Unprotect-VellumPdfDocument -LiteralPath $path -DestinationPath $out -Password $script:pw -AllowReconstruction -ReconstructionBudgetMultiplier 8
        $result.FullName | Should -Be $out
        (Get-VellumPdfInfo -Path $out).IsEncrypted | Should -BeFalse
    }

    It 'both cmdlets document and expose the switch' {
        (Get-Command Export-VellumPdfImage).Parameters.Keys | Should -Contain 'AllowReconstruction'
        (Get-Command Unprotect-VellumPdfDocument).Parameters.Keys | Should -Contain 'AllowReconstruction'
        (Get-Help Export-VellumPdfImage -Parameter AllowReconstruction).description.Text | Should -Not -BeNullOrEmpty
        (Get-Help Unprotect-VellumPdfDocument -Parameter AllowReconstruction).description.Text | Should -Not -BeNullOrEmpty
    }
}

Describe 'Pipeline binding by property name' {
    It '<Name> binds an object with a Path property to -Path' -ForEach @(
        @{ Name = 'Get-VellumPdfInfo' }, @{ Name = 'Get-VellumPdfText' }, @{ Name = 'Test-VellumPdfConformance' }, @{ Name = 'Export-VellumPdfImage' }
    ) {
        $r = Invoke-Reader $Name ([pscustomobject]@{ Path = $script:a }) (Get-ReaderArgument $Name 'bind-path')
        $r.Errors | Should -BeNullOrEmpty
        $r.Output.Count | Should -Be 1
    }

    It '<Name> binds Select-Object FullName output to -LiteralPath, brackets included' -ForEach @(
        @{ Name = 'Get-VellumPdfInfo' }, @{ Name = 'Get-VellumPdfText' }, @{ Name = 'Test-VellumPdfConformance' }, @{ Name = 'Export-VellumPdfImage' }
    ) {
        $r = Invoke-Reader $Name (Get-Item -LiteralPath $script:bracket | Select-Object FullName) (Get-ReaderArgument $Name 'bind-fullname')
        $r.Errors | Should -BeNullOrEmpty
        $r.Output.Count | Should -Be 1
    }

    It '<Name> still binds a FileInfo for report[1].pdf literally (PSPath) and a string to -Path' -ForEach @(
        @{ Name = 'Get-VellumPdfInfo' }, @{ Name = 'Get-VellumPdfText' }, @{ Name = 'Test-VellumPdfConformance' }, @{ Name = 'Export-VellumPdfImage' }
    ) {
        $r = Invoke-Reader $Name (Get-Item -LiteralPath $script:bracket) (Get-ReaderArgument $Name 'bind-fileinfo')
        $r.Errors | Should -BeNullOrEmpty
        $r.Output.Count | Should -Be 1
        $r = Invoke-Reader $Name $script:a (Get-ReaderArgument $Name 'bind-string')
        $r.Errors | Should -BeNullOrEmpty
        $r.Output.Count | Should -Be 1
        # A string with [ ] is a wildcard pattern for -Path (unchanged): the literal name does not match it.
        $r = Invoke-Reader $Name $script:bracket (Get-ReaderArgument $Name 'bind-pattern')
        $r.Output.Count | Should -Be 0
        $r.Errors[0].Exception.Message | Should -BeLike '*no file matches*'
    }

    It 'Unprotect-VellumPdfDocument binds Path objects, Select-Object FullName and FileInfo' {
        $out = Join-Path $TestDrive 'unprotect-bind.pdf'
        ([pscustomobject]@{ Path = $script:locked } | Unprotect-VellumPdfDocument -DestinationPath $out -Password $script:pw -Force).FullName | Should -Be $out
        (Get-Item -LiteralPath $script:locked | Select-Object FullName | Unprotect-VellumPdfDocument -DestinationPath $out -Password $script:pw -Force).FullName | Should -Be $out
        (Get-Item -LiteralPath $script:locked | Unprotect-VellumPdfDocument -DestinationPath $out -Password $script:pw -Force).FullName | Should -Be $out
        ($script:locked | Unprotect-VellumPdfDocument -DestinationPath $out -Password $script:pw -Force).FullName | Should -Be $out
    }

    It 'the output of Get-VellumPdfInfo (it has a Path property) pipes into the other readers' {
        Get-VellumPdfInfo -Path $script:a | Get-VellumPdfText | Should -Match 'File a'
    }

    It 'Path and LiteralPath expose the documented aliases' {
        foreach ($cmd in 'Get-VellumPdfInfo', 'Get-VellumPdfText', 'Test-VellumPdfConformance', 'Export-VellumPdfImage', 'Unprotect-VellumPdfDocument') {
            $p = (Get-Command $cmd).Parameters
            $p['LiteralPath'].Aliases | Should -Contain 'PSPath'
            $p['LiteralPath'].Aliases | Should -Contain 'FullName'
            $p['Path'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).ValueFromPipelineByPropertyName | Should -Contain $true
        }
    }
}
