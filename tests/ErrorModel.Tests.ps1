#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Error model and input robustness: errors terminate whatever -ErrorAction says, option values are
# mapped case-insensitively, coordinates are bounded, and records with missing properties are tolerated.

param()

BeforeDiscovery {
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)
}

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    function script:New-Page([hashtable]$DocParams = @{}) { New-VellumPdfPageDocument @DocParams | Add-VellumPdfPage }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Errors terminate whatever -ErrorAction says' {
    It '<Name> still throws with -ErrorAction <Pref>' -ForEach @(
        foreach ($pref in 'SilentlyContinue', 'Ignore', 'Continue') {
            @{ Pref = $pref; Name = 'Add-VellumPdfPath unknown command'; Run = { param($ea) New-Page | Add-VellumPdfPath -Data 'Q 1 2' -ErrorAction $ea } }
            @{ Pref = $pref; Name = 'Add-VellumPdfPath conflicting colours'; Run = { param($ea) New-Page | Add-VellumPdfPath 'M 0 0 L 1 1' -FillColor red -FillCmyk 0, 0, 0, 1 -ErrorAction $ea } }
            @{ Pref = $pref; Name = 'Add-VellumPdfShape without size'; Run = { param($ea) New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -ErrorAction $ea } }
            @{ Pref = $pref; Name = 'Save -Validate on an unconformant document'; Run = { param($ea) New-VellumPdfDocument | Add-VellumPdfParagraph -Text x | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'nv.pdf') -Validate -ErrorAction $ea } }
        }
    ) {
        { & $Run $Pref } | Should -Throw
        Test-Path (Join-Path $TestDrive 'nv.pdf') | Should -BeFalse
    }
}

Describe 'Line cap and join names are case-insensitive' {
    It 'maps <Cap>/<Join> for shapes and paths' -ForEach @(
        @{ Cap = 'round'; Join = 'bevel'; CapOp = 1; JoinOp = 2 }
        @{ Cap = 'SQUARE'; Join = 'Round'; CapOp = 2; JoinOp = 1 }
        @{ Cap = 'butt'; Join = 'miter'; CapOp = 0; JoinOp = 0 }
    ) {
        $path = Join-Path $TestDrive "cap-$Cap.pdf"
        New-Page | Add-VellumPdfShape Rectangle -X 1 -Y 1 -Width 10 -Height 10 -LineCap $Cap -LineJoin $Join |
            Add-VellumPdfPath 'M 1 1 L 20 20' -LineCap $Cap -LineJoin $Join |
            Save-VellumPdfDocument -Path $path | Out-Null
        $c = Get-PdfContentText $path
        ([regex]::Matches($c, "(?m)^$CapOp J$")).Count | Should -Be 2
        ([regex]::Matches($c, "(?m)^$JoinOp j$")).Count | Should -Be 2
        $c | Should -Not -Match '(?m)^-1 [Jj]$'
    }
}

Describe 'Coordinates are bounded to the page limit' {
    It 'refuses <Name>' -ForEach @(
        @{ Name = 'a huge path coordinate'; Run = { New-Page | Add-VellumPdfPath 'M 1e300 2 L 3 3' } }
        @{ Name = 'a huge text box position'; Run = { New-Page | Add-VellumPdfTextBox 'x' -X 3e9 -Y 1e39 -Width 100 } }
        @{ Name = 'a huge clip box'; Run = { New-Page | Use-VellumPdfClip -X 1e40 -Y 0 -Width 10 -Height 10 -ScriptBlock { } } }
        @{ Name = 'a huge shape'; Run = { New-Page | Add-VellumPdfShape Rectangle -X 0 -Y 0 -Width 20000 -Height 5 } }
        @{ Name = 'a huge text position'; Run = { New-Page | Add-VellumPdfText 'x' -X 0 -Y -15000 } }
        @{ Name = 'a huge point'; Run = { New-Page | Add-VellumPdfPath -Point (0, 0), (99999, 1) } }
        @{ Name = 'a huge link rectangle'; Run = { New-Page | Add-VellumPdfLink -X 0 -Y 0 -Width 99999 -Height 5 -Uri 'https://example.com' } }
    ) {
        { & $Run } | Should -Throw '*between -14400 and 14400*'
    }

    It 'accepts values at the limit and writes a file' {
        $path = Join-Path $TestDrive 'limit.pdf'
        New-Page @{ Conformance = 'PdfA2b'; Language = 'en' } | Add-VellumPdfPath 'M -14400 14400 L 14400 -14400' -StrokeColor black |
            Save-VellumPdfDocument -Path $path -Validate | Out-Null
        Test-Path $path | Should -BeTrue
    }

    It 'writes a file qpdf accepts for values at the limit' -Skip:(-not $script:haveQpdf) {
        $path = Join-Path $TestDrive 'limit-qpdf.pdf'
        New-Page @{ Conformance = 'PdfA2b'; Language = 'en' } | Add-VellumPdfPath 'M -14400 14400 L 14400 -14400' -StrokeColor black |
            Save-VellumPdfDocument -Path $path -Validate | Out-Null
        & qpdf --check $path 2>&1 | Out-String | Should -Match 'No syntax or stream encoding errors'
    }
}

Describe 'Records with missing properties' {
    It 'builds a table from records that carry different properties' {
        $records = '[{"name":"a","note":"x"},{"name":"b"}]' | ConvertFrom-Json
        $path = Join-Path $TestDrive 'records.pdf'
        New-VellumPdfDocument | Add-VellumPdfTable -Row $records | Save-VellumPdfDocument -Path $path | Out-Null
        Test-Path $path | Should -BeTrue
    }

    It 'takes pie slices without a Color and reports a missing Value clearly' {
        $path = Join-Path $TestDrive 'pie.pdf'
        New-VellumPdfDocument | Add-VellumPdfPieChart -Slice ([pscustomobject]@{ Value = 1 }), ([pscustomobject]@{ Value = 2; Label = 'b' }) |
            Save-VellumPdfDocument -Path $path | Out-Null
        Test-Path $path | Should -BeTrue
        { New-VellumPdfDocument | Add-VellumPdfPieChart -Slice ([pscustomobject]@{ Label = 'x' }) } | Should -Throw '*no numeric Value*'
    }

    It 'reads pie data from objects with missing properties and from an array given to -InputObject' {
        $doc = New-VellumPdfDocument
        try {
            { Add-VellumPdfPieChart -Document $doc -InputObject ([pscustomobject]@{ A = 1 }) -ValueProperty Missing } | Should -Throw '*no numeric Value*'
            $out = Add-VellumPdfPieChart -Document $doc -InputObject @(
                [pscustomobject]@{ V = 40; L = 'a' }, [pscustomobject]@{ V = 60; L = 'b' }) -ValueProperty V -LabelProperty L
            $out | Should -BeOfType ([VellumPdf.Layout.Document])
        }
        finally { $doc.Dispose() }
    }
}

Describe 'Reader input handling' {
    BeforeAll {
        $script:pdf = Join-Path $TestDrive 'report[1].pdf'
        New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Hello brackets' | Save-VellumPdfDocument -Path $script:pdf | Out-Null
    }

    It 'binds piped file objects literally, so names with [ ] work' {
        (Get-Item -LiteralPath $script:pdf | Get-VellumPdfInfo).PageCount | Should -Be 1
        ((Get-ChildItem -LiteralPath $TestDrive -Filter 'report*') | Get-VellumPdfText) -join '' | Should -Match 'Hello brackets'
        (Get-Item -LiteralPath $script:pdf | Test-VellumPdfConformance -Profile PdfA2b) | Should -Not -BeNullOrEmpty
    }

    It 'still expands wildcards given to -Path, and does not treat brackets there as literal' {
        { Get-VellumPdfText -Path $script:pdf -ErrorAction Stop } | Should -Throw '*no file matches*'
        (Get-VellumPdfText -Path (Join-Path $TestDrive 'report`[1`].pdf')) -join '' | Should -Match 'Hello brackets'
    }

    It 'names the cmdlet for a missing file, an empty file and an empty byte array' {
        { Get-VellumPdfInfo -Path (Join-Path $TestDrive 'nope.pdf') -ErrorAction Stop } | Should -Throw 'Get-VellumPdfInfo: file not found*'
        $empty = Join-Path $TestDrive 'empty.pdf'
        [System.IO.File]::WriteAllBytes($empty, [byte[]]@())
        { Get-VellumPdfInfo -LiteralPath $empty -ErrorAction Stop } | Should -Throw '*is empty, so it is not a PDF*'
        { Get-VellumPdfText -Bytes ([byte[]]@()) -ErrorAction Stop } | Should -Throw '*empty*not a PDF*'
        { Get-VellumPdfText -Bytes ([byte[]]@(0)) -ErrorAction Stop } | Should -Throw '*not a well-formed PDF*'
    }
}
