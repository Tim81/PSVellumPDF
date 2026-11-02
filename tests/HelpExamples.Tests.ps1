#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Every .EXAMPLE in the comment-based help is parsed and checked against the command metadata (parameter
# names, ValidateSet values), and the self-contained ones are run under en-US and de-DE, so an example
# that no longer works, or only works in one culture, fails the build.

param()

BeforeDiscovery {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    $script:cases = foreach ($command in (Get-Command -Module PSVellumPDF | Sort-Object Name)) {
        $index = 0
        foreach ($example in @((Get-Help $command.Name -Full).examples.example)) {
            $index++
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($example.code, [ref]$null, [ref]$null)
            $used = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) |
                ForEach-Object { $_.VariablePath.UserPath } | Sort-Object -Unique
            $assigned = @($ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
                    ForEach-Object { $_.Left.Extent.Text.TrimStart('$') })
            $free = @($used | Where-Object { $_ -notin $assigned -and $_ -notin 'true', 'false', 'null', '_', 'PSScriptRoot', 'args', 'input', 'PSItem', 'env', 'HOME', 'PWD' })
            @{ Name = $command.Name; Index = $index; Code = $example.code; Free = $free; Label = "$($command.Name) example $index" }
        }
    }
}

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    $script:assets = Join-Path $PSScriptRoot 'assets'

    # Files the examples refer to by relative path, created once and copied next to every example run.
    $script:fixtures = Join-Path $TestDrive 'fixtures'
    [void][System.IO.Directory]::CreateDirectory($script:fixtures)
    Copy-Item (Join-Path $script:assets 'DejaVuSans.ttf') $script:fixtures
    Copy-Item (Join-Path $script:assets 'gray16.png') (Join-Path $script:fixtures 'logo.png')
    Copy-Item (Join-Path $script:assets 'photo.jpg') $script:fixtures
    foreach ($pdf in 'report', 'brochure', 'contract') {
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text "Fixture $pdf" |
            Save-VellumPdfDocument -Path (Join-Path $script:fixtures "$pdf.pdf") | Out-Null
    }

    # Examples that need something this test cannot provide, with the reason. Anything not listed here
    # and without unexplained free variables is run.
    $script:skipRun = @{
        'Set-VellumPdfSignature example 1'    = 'needs a signing certificate'
        'Set-VellumPdfSignature example 2'    = 'needs a signing certificate'
        'Set-VellumPdfSignature example 3'    = 'needs a signing certificate'
        'Set-VellumPdfSignature example 4'    = 'needs a signing certificate and a time-stamp server'
        'Add-VellumPdfImage example 3'        = 'needs image bytes the example does not create'
        'Add-VellumPdfElement example 1'      = 'needs a prebuilt renderer'
        'Add-VellumPdfDrawing example 1'      = 'the script block runs during the save and uses free canvas variables'
        'Invoke-VellumPdfCanvas example 1'    = 'uses a canvas variable supplied by the cmdlet'
        'New-VellumPdfTextRun example 1'      = 'uses a document variable only to show chaining'
        'Set-VellumPdfOutputIntent example 2' = 'needs a PDF/A document, which the sample document is not'
        'New-VellumPdfPageDocument example 2' = 'contains a ... placeholder for omitted pages'
    }

    # Runs one example in the current session: prelude with sample variables, then the example code.
    function script:Invoke-Example([string]$Name, [string]$Code, [string]$Culture) {
        $type = (Get-Command $Name).Parameters['Document']?.ParameterType
        $page = $type -and $type.FullName -eq 'VellumPdf.Document.PdfDocument'
        $work = Join-Path $TestDrive ('ex-' + [guid]::NewGuid().ToString('N'))
        [void][System.IO.Directory]::CreateDirectory($work)
        Copy-Item (Join-Path $script:fixtures '*') $work
        $previousCulture = [cultureinfo]::CurrentCulture
        $previousLocation = Get-Location
        $doc = $null
        try {
            [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo($Culture)
            Set-Location $work
            $doc = if ($page) { New-VellumPdfPageDocument -Language en | Add-VellumPdfPage -Count 3 } else { New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Sample' }
            # Sample values for the variables the examples use, defined inside the evaluated script itself.
            $prelude = '$text = ''The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.''; $intro = $text; $more = $text' + [Environment]::NewLine
            $sb = [scriptblock]::Create($prelude + $Code)
            $null = & $sb
        }
        finally {
            Set-Location $previousLocation
            [cultureinfo]::CurrentCulture = $previousCulture
            if ($doc -and -not $doc.PSObject.Properties['PSVellumSaved'] -and -not $doc.PSObject.Properties['PSVellumDisposed']) { try { $doc.Dispose() } catch { Write-Verbose "dispose: $_" } }
        }
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Help examples parse and match the command metadata' {
    It '<Label>' -ForEach $script:cases {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
        $problems = foreach ($call in $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $commandName = $call.GetCommandName()
            $meta = if ($commandName) { Get-Command $commandName -ErrorAction SilentlyContinue }
            if ($meta -isnot [System.Management.Automation.CommandInfo] -or $meta.Source -ne 'PSVellumPDF') { continue }
            $elements = $call.CommandElements
            for ($i = 1; $i -lt $elements.Count; $i++) {
                if ($elements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                $parameterName = $elements[$i].ParameterName
                $match = $meta.Parameters.Values | Where-Object { $_.Name -like "$parameterName*" -or $_.Aliases -contains $parameterName } | Select-Object -First 1
                if (-not $match -and $meta.Parameters.Keys -notcontains $parameterName) { "${commandName}: no parameter -$parameterName"; continue }
                $parameter = $meta.Parameters[$parameterName] ?? $match
                $validateSet = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $valueAst = if ($elements[$i].Argument) { $elements[$i].Argument } elseif ($i + 1 -lt $elements.Count) { $elements[$i + 1] }
                if ($validateSet -and $valueAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $valueAst.Value -notin $validateSet.ValidValues) {
                    "${commandName}: -$parameterName '$($valueAst.Value)' is not one of $($validateSet.ValidValues -join ', ')"
                }
            }
        }
        $problems | Should -BeNullOrEmpty
    }
}

Describe 'Self-contained help examples run in every culture' {
    It '<Label> (<Culture>)' -ForEach @(
        foreach ($case in $script:cases) {
            $unexplained = @($case.Free | Where-Object { $_ -notin 'doc', 'text', 'intro', 'more' })
            if ($unexplained.Count -eq 0 -and $case.Code -notmatch 'Get-PfxCertificate|Get-Item|Cert:|https?://|Import-Csv|Get-ChildItem|\$env:|Read-Host|Get-Credential') {
                foreach ($culture in 'en-US', 'de-DE') { $case + @{ Culture = $culture } }
            }
        }
    ) {
        if ($script:skipRun.ContainsKey($Label)) { Set-ItResult -Skipped -Because $script:skipRun[$Label]; return }
        { Invoke-Example -Name $Name -Code $Code -Culture $Culture } | Should -Not -Throw
    }
}
