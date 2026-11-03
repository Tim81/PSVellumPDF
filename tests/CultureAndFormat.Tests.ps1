#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# -Culture, -InputCulture, explicit format strings (-ColumnFormat, -Format, -LabelFormat) and the reading of numbers
# from string input in tables, lists and pie charts, in flow and page documents.

param()

BeforeDiscovery {
    $script:havePdftotext = [bool](Get-Command pdftotext -ErrorAction SilentlyContinue)
    $script:haveQpdf = [bool](Get-Command qpdf -ErrorAction SilentlyContinue)

    # Text, the expected invariant rendering of the [decimal] (null = not a number / not certain), optional hint / culture.
    $script:numberCases = @(
        # The user's examples (exact value and scale).
        @{ Text = '1.444,50'; Expected = '1444.50' }
        @{ Text = '1,976.08'; Expected = '1976.08' }
        @{ Text = '55433.34'; Expected = '55433.34' }
        @{ Text = '66443,85'; Expected = '66443.85' }
        @{ Text = '777544434,7755'; Expected = '777544434.7755' }
        @{ Text = '775444335.7325'; Expected = '775444335.7325' }
        # Grouping and decimals.
        @{ Text = '1.234.567'; Expected = '1234567' }
        @{ Text = '1,234,567'; Expected = '1234567' }
        @{ Text = '12.345.678,9'; Expected = '12345678.9' }
        @{ Text = '12345,678'; Expected = '12345.678' }
        @{ Text = '12345.678'; Expected = '12345.678' }
        @{ Text = '0,123'; Expected = '0.123' }
        @{ Text = '0.5'; Expected = '0.5' }
        @{ Text = '10.00'; Expected = '10.00' }
        @{ Text = '95'; Expected = '95' }
        @{ Text = '0'; Expected = '0' }
        @{ Text = ' 42 '; Expected = '42' }
        @{ Text = '+1.5'; Expected = '1.5' }
        @{ Text = '-1,5'; Expected = '-1.5' }
        @{ Text = '-1.444,50'; Expected = '-1444.50' }
        # Ambiguous without evidence: not read.
        @{ Text = '1,234'; Expected = $null }
        @{ Text = '1.234'; Expected = $null }
        @{ Text = '999,999'; Expected = $null }
        # Ambiguous with evidence (the decimal mark other values showed).
        @{ Text = '1,234'; Hint = '.'; Expected = '1234' }
        @{ Text = '1.234'; Hint = '.'; Expected = '1.234' }
        @{ Text = '1.234'; Hint = ','; Expected = '1234' }
        @{ Text = '1,234'; Hint = ','; Expected = '1.234' }
        # A hint never turns a certain reading around.
        @{ Text = '1.234.567'; Hint = '.'; Expected = '1234567' }
        @{ Text = '66443,85'; Hint = '.'; Expected = '66443.85' }
        # -InputCulture: strict, no detection.
        @{ Text = '1.234'; InputCulture = 'de-DE'; Expected = '1234' }
        @{ Text = '1,234'; InputCulture = 'de-DE'; Expected = '1.234' }
        @{ Text = '1.444,50'; InputCulture = 'de-DE'; Expected = '1444.50' }
        @{ Text = '55433.34'; InputCulture = 'de-DE'; Expected = $null }
        @{ Text = '12.34'; InputCulture = 'de-DE'; Expected = $null }
        @{ Text = '1,234'; InputCulture = 'en-US'; Expected = '1234' }
        @{ Text = '1.234'; InputCulture = 'en-US'; Expected = '1.234' }
        @{ Text = '55433.34'; InputCulture = 'en-US'; Expected = '55433.34' }
        @{ Text = '1.444,50'; InputCulture = 'en-US'; Expected = $null }
        @{ Text = '007'; InputCulture = 'en-US'; Expected = $null }
        @{ Text = '1 234,5'; InputCulture = 'fr-FR'; Expected = '1234.5' }
        # Not numbers.
        @{ Text = '007'; Expected = $null }
        @{ Text = '-007'; Expected = $null }
        @{ Text = '01234'; Expected = $null }
        @{ Text = '00.5'; Expected = $null }
        @{ Text = '10.0.0.1'; Expected = $null }
        @{ Text = '1.2.3'; Expected = $null }
        @{ Text = '1 234'; Expected = $null }
        @{ Text = '€5'; Expected = $null }
        @{ Text = '$5.00'; Expected = $null }
        @{ Text = '5%'; Expected = $null }
        @{ Text = '1e5'; Expected = $null }
        @{ Text = '1E-3'; Expected = $null }
        @{ Text = ''; Expected = $null }
        @{ Text = '   '; Expected = $null }
        @{ Text = '-'; Expected = $null }
        @{ Text = '+'; Expected = $null }
        @{ Text = 'abc'; Expected = $null }
        @{ Text = '12abc'; Expected = $null }
        @{ Text = '1,'; Expected = $null }
        @{ Text = '.5'; Expected = $null }
        @{ Text = '5.'; Expected = $null }
        @{ Text = '1,2,3'; Expected = $null }
        @{ Text = '1.234,567,89'; Expected = $null }
        @{ Text = '1,5.234'; Expected = $null }
        @{ Text = '0.123.456'; Expected = $null }
        @{ Text = '12345678901234567890123456789012345'; Expected = $null }
    )
    # Every case carries every key, so the name template and body also work under Set-StrictMode (build.ps1 Test).
    foreach ($case in $script:numberCases) { foreach ($key in 'Hint', 'InputCulture') { if (-not $case.ContainsKey($key)) { $case[$key] = $null } } }
}

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Saves a document and returns the drawn text, whitespace collapsed to single spaces. Documents with
    # -Conformance embed their fonts, whose text pdftotext reads but Get-VellumPdfText does not, so tests use none.
    function script:Save-AndRead($Document) {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.pdf')
        $Document | Save-VellumPdfDocument -Path $path | Out-Null
        ((& pdftotext -layout $path - 2>$null | Out-String) -replace '[\s ]+', ' ').Trim()
    }
    function script:New-Page([hashtable]$Arguments = @{}) { New-VellumPdfPageDocument @Arguments | Add-VellumPdfPage }
    $script:dateValue = [datetime]::new(2026, 3, 5, 14, 30, 0)
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-VellumPdfNumberText' {
    It 'reads <Text> (hint <Hint>, input culture <InputCulture>) as <Expected>' -ForEach $script:numberCases {
        InModuleScope PSVellumPDF -Parameters @{ Case = $_ } {
            $splat = @{ Text = $Case.Text }
            if ($null -ne $Case.Hint) { $splat['Hint'] = $Case.Hint }
            if ($null -ne $Case.InputCulture) { $splat['InputCulture'] = [cultureinfo]::GetCultureInfo($Case.InputCulture) }
            $value = ConvertFrom-VellumPdfNumberText @splat
            if ($null -eq $Case.Expected) { $value | Should -BeNullOrEmpty }
            else {
                $value | Should -BeOfType [decimal]
                # The invariant text shows both the value and its scale (10.00 stays 10.00).
                $value.ToString([cultureinfo]::InvariantCulture) | Should -Be $Case.Expected
            }
        }
    }

    It 'returns $null for $null' {
        InModuleScope PSVellumPDF { ConvertFrom-VellumPdfNumberText -Text $null | Should -BeNullOrEmpty }
    }

    It 'keeps the scale of the text as the decimal scale' {
        InModuleScope PSVellumPDF {
            $value = ConvertFrom-VellumPdfNumberText -Text '1.444,50'
            (([decimal]::GetBits($value)[3] -shr 16) -band 0xFF) | Should -Be 2
            $value | Should -Be 1444.5
        }
    }
}

Describe 'Get-VellumPdfNumberHint' {
    It 'reads the decimal mark from <Text>' -ForEach @(
        @{ Text = @('1.444,50', '1,234'); Expected = ',' }
        @{ Text = @('1,976.08'); Expected = '.' }
        @{ Text = @('1.234.567'); Expected = ',' }
        @{ Text = @('1,234,567'); Expected = '.' }
        @{ Text = @('66443,85', '1,5'); Expected = ',' }
        @{ Text = @('12345.678'); Expected = '.' }
        @{ Text = @('1.444,50', '1,976.08'); Expected = $null }   # conflicting evidence
        @{ Text = @('1,234', '5.678'); Expected = $null }   # only ambiguous values
        @{ Text = @('abc', '007', '95'); Expected = $null }
    ) {
        InModuleScope PSVellumPDF -Parameters @{ Case = $_ } {
            $hint = Get-VellumPdfNumberHint -Text $Case.Text
            if ($null -eq $Case.Expected) { $hint | Should -BeNullOrEmpty } else { $hint | Should -Be $Case.Expected }
        }
    }
}

Describe 'ConvertTo-VellumPdfText' {
    It 'leaves strings unchanged, ignoring the format' {
        InModuleScope PSVellumPDF {
            ConvertTo-VellumPdfText -Value '1.234,5' -Culture ([cultureinfo]'de-DE') -Format 'N2' | Should -BeExactly '1.234,5'
        }
    }
    It 'formats IFormattable values with the culture and the optional format' {
        InModuleScope PSVellumPDF {
            $de = [cultureinfo]::GetCultureInfo('de-DE')
            $inv = [cultureinfo]::InvariantCulture
            ConvertTo-VellumPdfText -Value 1234.5 -Culture $inv -Format '' | Should -Be '1234.5'
            ConvertTo-VellumPdfText -Value 1234.5 -Culture $de -Format '' | Should -Be '1234,5'
            ConvertTo-VellumPdfText -Value 1234.5 -Culture $de -Format 'N2' | Should -Be '1.234,50'
            ConvertTo-VellumPdfText -Value ([datetime]'2026-03-05') -Culture $de -Format 'd' | Should -Be '05.03.2026'
            ConvertTo-VellumPdfText -Value ([datetime]'2026-03-05') -Culture $inv -Format 'yyyy-MM-dd' | Should -Be '2026-03-05'
            ConvertTo-VellumPdfText -Value ([decimal]12.5) -Culture $de | Should -Be '12,5'
        }
    }
    It 'converts other values with [string] and $null to the empty string' {
        InModuleScope PSVellumPDF {
            $inv = [cultureinfo]::InvariantCulture
            ConvertTo-VellumPdfText -Value $true -Culture $inv | Should -Be 'True'
            ConvertTo-VellumPdfText -Value $null -Culture $inv | Should -Be ''
        }
    }
    It 'names the format string and the column when the type rejects the format' {
        InModuleScope PSVellumPDF {
            { ConvertTo-VellumPdfText -Value 1.5 -Culture ([cultureinfo]::InvariantCulture) -Format 'Q' -CommandName 'Demo' -What 'column 3' } |
                Should -Throw "Demo: the format string 'Q' cannot format column 3*"
        }
    }
}

Describe 'Culture on documents and cmdlets' {
    It 'rejects an unknown culture name on every cmdlet that takes -Culture' {
        { New-VellumPdfDocument -Culture 'xx-NOPE' } | Should -Throw '*New-VellumPdfDocument: -Culture ''xx-NOPE'' is not a known culture name*'
        { New-VellumPdfPageDocument -Culture 'xx-NOPE' } | Should -Throw '*not a known culture name*'
        { New-VellumPdfDocument -InputCulture 'xx-NOPE' } | Should -Throw '*-InputCulture ''xx-NOPE'' is not a known culture name*'
        $doc = New-VellumPdfDocument
        try {
            { $doc | Add-VellumPdfTable -Row @(, @('a')) -Culture 'xx-NOPE' } | Should -Throw '*Add-VellumPdfTable: -Culture*'
            { $doc | Add-VellumPdfList -Item 'a' -Culture 'xx-NOPE' } | Should -Throw '*Add-VellumPdfList: -Culture*'
            { $doc | Add-VellumPdfPieChart -Slice @{ Value = 1 } -Culture 'xx-NOPE' } | Should -Throw '*Add-VellumPdfPieChart: -Culture*'
            { $doc | Add-VellumPdfTable -Row @(, @('a')) -InputCulture 'xx-NOPE' } | Should -Throw '*-InputCulture*'
        }
        finally { $doc.Dispose() }
    }

    It 'stores the invariant culture by default and the given one when set' {
        $default = New-VellumPdfDocument
        $de = New-VellumPdfDocument -Culture de-DE -InputCulture ([cultureinfo]'nl-NL')
        $page = New-VellumPdfPageDocument -Culture fr-FR
        try {
            $default.PSObject.Properties['PSVellumCulture'].Value | Should -Be ([cultureinfo]::InvariantCulture)
            $default.PSObject.Properties['PSVellumInputCulture'].Value | Should -BeNullOrEmpty
            $de.PSObject.Properties['PSVellumCulture'].Value.Name | Should -Be 'de-DE'
            $de.PSObject.Properties['PSVellumInputCulture'].Value.Name | Should -Be 'nl-NL'
            $page.PSObject.Properties['PSVellumCulture'].Value.Name | Should -Be 'fr-FR'
        }
        finally { $default.Dispose(); $de.Dispose(); $page.Dispose() }
    }

    Context 'Add-VellumPdfTable' {
        It 'draws dates and numbers with the invariant culture by default, whatever the machine culture' -Skip:(-not $script:havePdftotext) {
            $previous = [cultureinfo]::CurrentCulture
            try {
                [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo('de-DE')
                $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @($script:dateValue, 1234.5)))
            }
            finally { [cultureinfo]::CurrentCulture = $previous }
            $text | Should -Match '03/05/2026 14:30:00 1234\.5'
        }

        It 'draws them with -Culture de-DE' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @($script:dateValue, 1234.5)) -Culture de-DE)
            $text | Should -Match '05\.03\.2026 14:30:00 1234,5'
        }

        It 'accepts a [cultureinfo] for -Culture' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @(1234.5)) -Culture ([cultureinfo]::GetCultureInfo('de-DE')))
            $text | Should -Match '1234,5'
        }

        It 'uses the document culture, and a per-call -Culture overrides it' -Skip:(-not $script:havePdftotext) {
            $doc = New-VellumPdfDocument -Culture de-DE
            $doc | Add-VellumPdfTable -Row @(, @('doc', 1234.5)) | Out-Null
            $doc | Add-VellumPdfTable -Row @(, @('call', 1234.5)) -Culture en-US | Out-Null
            $text = Save-AndRead $doc
            $text | Should -Match 'doc 1234,5'
            $text | Should -Match 'call 1234\.5'
        }

        It 'reads <Name> records the same way' -ForEach @(@{ Name = 'PSCustomObject' }) -Skip:(-not $script:havePdftotext) {
            $rows = @([pscustomobject]@{ Date = $script:dateValue; Amount = 1234.5 })
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -Culture de-DE)
            $text | Should -Match 'Date Amount'
            $text | Should -Match '05\.03\.2026 14:30:00 1234,5'
        }

        It '-ColumnFormat formats a column, with and without a culture' -Skip:(-not $script:havePdftotext) {
            $rows = @(, @('a', 1234.5, $script:dateValue))
            $inv = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -ColumnFormat '', 'N2', 'yyyy-MM-dd')
            $inv | Should -Match 'a 1,234\.50 2026-03-05'
            $de = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -ColumnFormat '', 'N2', 'yyyy-MM-dd' -Culture de-DE)
            $de | Should -Match 'a 1\.234,50 2026-03-05'
        }

        It '-ColumnFormat also formats numbers given as strings' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1234.5'), @('1.444,5'), @('7'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -ColumnFormat 'N2' -Culture de-DE)
            $text | Should -Match '1\.234,50 1\.444,50 7,00'
        }

        It 'a rich cell Format key wins over the column format, and the caller''s hashtable stays as it was' -Skip:(-not $script:havePdftotext) {
            $cell = @{ Text = 1234.4; Format = 'N0' }
            $rows = @(, @(1234.4, $cell))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -ColumnFormat 'F2', 'F2')
            $text | Should -Match '1234\.40 1,234'
            $cell.Text | Should -BeOfType [double]
            $cell.Text | Should -Be 1234.4
        }

        It 'follows the grid for -ColumnFormat when a cell spans columns' -Skip:(-not $script:havePdftotext) {
            $rows = @(@(@{ Text = 'wide'; ColSpan = 2 }, 5), @(1, 2, 3))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -ColumnFormat '', '', 'F1')
            $text | Should -Match 'wide 5\.0'
            $text | Should -Match '1 2 3\.0'
        }

        It 'names the column when a format string is invalid' {
            $doc = New-VellumPdfDocument
            try {
                { $doc | Add-VellumPdfTable -Row @(, @('a', 1.5)) -ColumnFormat '', 'Q' } |
                    Should -Throw "*Add-VellumPdfTable: the format string 'Q' cannot format column 2*"
                { $doc | Add-VellumPdfTable -Row @(, @(@{ Text = 1.5; Format = 'Q' })) } |
                    Should -Throw "*the format string 'Q'*"
            }
            finally { $doc.Dispose() }
        }

        It 'a format for a column that holds only text is ignored' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @('plain')) -ColumnFormat 'Q')
            $text | Should -Match 'plain'
        }
    }

    Context 'Add-VellumPdfPageTable' {
        It 'draws numbers with the invariant culture by default, the document culture, and a per-call override' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('inv', 1234.5)))
            $text | Should -Match 'inv 1234\.5'
            $doc = New-Page @{ Culture = 'de-DE' }
            $doc | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('doc', 1234.5, $script:dateValue)) | Out-Null
            $doc | Add-VellumPdfPageTable -X 50 -Y 600 -Width 300 -Row @(, @('call', 1234.5)) -Culture en-US | Out-Null
            $text = Save-AndRead $doc
            $text | Should -Match 'doc 1234,5 05\.03\.2026 14:30:00'
            $text | Should -Match 'call 1234\.5'
        }

        It '-ColumnFormat and a cell Format key work like in flow tables' -Skip:(-not $script:havePdftotext) {
            $rows = @(, @('a', 1234.5, @{ Text = 1234.5; Format = 'F0' }))
            $text = Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 400 -Row $rows -ColumnFormat '', 'N2', 'N2' -Culture de-DE)
            $text | Should -Match 'a 1\.234,50 1234'
        }

        It 'names the column when a format string is invalid' {
            $doc = New-Page
            try {
                { $doc | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('a', 1.5)) -ColumnFormat '', 'Q' } |
                    Should -Throw "*Add-VellumPdfPageTable: the format string 'Q' cannot format column 2*"
            }
            finally { $doc.Dispose() }
        }
    }

    Context 'Add-VellumPdfList and Add-VellumPdfPageList' {
        It 'formats non-string items with -Culture and -Format, children included' -Skip:(-not $script:havePdftotext) {
            $items = @(1234.5, @{ Text = 99.5; Children = @(2.25) })
            $inv = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item $items -Format 'N2')
            $inv | Should -Match '1,234\.50'
            $inv | Should -Match '99\.50'
            $inv | Should -Match '2\.25'
            $de = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item $items -Format 'N2' -Culture de-DE)
            $de | Should -Match '1\.234,50'
            $de | Should -Match '99,50'
            $de | Should -Match '2,25'
        }

        It 'uses the document culture, a per-call override and an item Format key' -Skip:(-not $script:havePdftotext) {
            $doc = New-VellumPdfDocument -Culture de-DE
            $doc | Add-VellumPdfList -Item @(1234.5, @{ Text = 1234.5; Format = 'N0' }) | Out-Null
            $doc | Add-VellumPdfList -Item @(2345.5) -Culture en-US | Out-Null
            $text = Save-AndRead $doc
            $text | Should -Match '1234,5'
            $text | Should -Match '1\.235|1\.234'
            $text | Should -Match '2345\.5'
        }

        It 'does not change the caller''s item hashtables' {
            $item = @{ Text = 7.5; Children = @(1.5) }
            $doc = New-VellumPdfDocument
            try { $doc | Add-VellumPdfList -Item $item | Out-Null }
            finally { $doc.Dispose() }
            $item.Text | Should -BeOfType [double]
            @($item.Children)[0] | Should -BeOfType [double]
        }

        It 'names the item when a format string is invalid' {
            $doc = New-VellumPdfDocument
            try {
                { $doc | Add-VellumPdfList -Item 'a', 1.5 -Format 'Q' } | Should -Throw "*Add-VellumPdfList: the format string 'Q' cannot format item 2*"
            }
            finally { $doc.Dispose() }
        }

        It 'page lists: -Format, -Culture, the document culture and invalid formats' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item 1234.5, 2.5 -Format 'N2' -Culture de-DE)
            $text | Should -Match '1\.234,50'
            $text | Should -Match '2,50'
            $doc = New-Page @{ Culture = 'de-DE' }
            $doc | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item @(1234.5, @{ Text = 8.5; Children = @(0.25) }) | Out-Null
            $text = Save-AndRead $doc
            $text | Should -Match '1234,5'
            $text | Should -Match '0,25'
            { New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item 'a', 1.5 -Format 'Q' } | Should -Throw "*the format string 'Q' cannot format item 2*"
        }
    }

    Context 'Add-VellumPdfPieChart' {
        BeforeAll {
            $script:slices = @(@{ Value = 1; Label = 'Alpha' }, @{ Value = 2; Label = 'Beta' })
        }

        It 'labels shares like before by default, in the invariant culture' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice $script:slices -Legend)
            $text | Should -Match 'Alpha 33\.3 %'
            $text | Should -Match 'Beta 66\.7 %'
        }

        It 'no longer follows the machine culture' -Skip:(-not $script:havePdftotext) {
            $previous = [cultureinfo]::CurrentCulture
            try {
                [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo('de-DE')
                $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice $script:slices -Legend)
            }
            finally { [cultureinfo]::CurrentCulture = $previous }
            $text | Should -Match 'Alpha 33\.3 %'
        }

        It '-Culture and the document culture select the decimal mark' -Skip:(-not $script:havePdftotext) {
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice $script:slices -Legend -Culture de-DE)) | Should -Match 'Alpha 33,3 %'
            $doc = New-VellumPdfDocument -Culture de-DE
            (Save-AndRead ($doc | Add-VellumPdfPieChart -Slice $script:slices -Legend)) | Should -Match 'Alpha 33,3 %'
            $doc2 = New-VellumPdfDocument -Culture de-DE
            (Save-AndRead ($doc2 | Add-VellumPdfPieChart -Slice $script:slices -Legend -Culture en-US)) | Should -Match 'Alpha 33\.3%'
        }

        It '-LabelFormat changes the label format' -Skip:(-not $script:havePdftotext) {
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice $script:slices -Legend -LabelFormat 'P0')) | Should -Match 'Alpha 33 %'
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice $script:slices -Legend -LabelFormat 'N3' -Culture de-DE)) | Should -Match 'Alpha 0,333'
        }

        It 'a label that looks like a number is not read again by the legend table' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfPieChart -Slice @(@{ Value = 1; Label = '1,5' }, @{ Value = 3; Label = '007' }) -Legend -LabelFormat 'N2' -Culture de-DE)
            $text | Should -Match '1,5 0,25'
            $text | Should -Match '007 0,75'
        }

        It 'rejects an invalid -LabelFormat, with or without a legend' {
            $doc = New-VellumPdfDocument
            try {
                { $doc | Add-VellumPdfPieChart -Slice $script:slices -LabelFormat 'Q' } | Should -Throw "*Add-VellumPdfPieChart: the format string 'Q' cannot format -LabelFormat*"
                { $doc | Add-VellumPdfPieChart -Slice $script:slices -Legend -LabelFormat 'Q' } | Should -Throw "*the format string 'Q'*"
            }
            finally { $doc.Dispose() }
        }
    }
}

Describe 'Number detection in string cells and items' {
    Context 'tables' {
        It 'reads grouping and decimal marks from strings (invariant default)' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1.444,50'), @('1,976.08'), @('55433.34'), @('66443,85'), @('777544434,7755'), @('775444335.7325'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -WarningAction SilentlyContinue)
            $text | Should -Be '1444.50 1976.08 55433.34 66443.85 777544434.7755 775444335.7325'
        }

        It 'renders what it reads with -Culture and -ColumnFormat' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1.444,50'), @('1,976.08'), @('55433.34'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -Culture de-DE)
            $text | Should -Be '1444,50 1976,08 55433,34'
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -Culture de-DE -ColumnFormat 'N2')
            $text | Should -Be '1.444,50 1.976,08 55.433,34'
        }

        It 'leaves text that is not a number as it is' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('007', '10.0.0.1', '1 234', '5%', '1e5', 'abc'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows)
            $text | Should -Be '007 10.0.0.1 1 234 5% 1e5 abc'
        }

        It 'does not read header cells as numbers' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Header '1.444,50', '2024' -Row @(, @('1.444,50', '2024')))
            $text | Should -Be '1.444,50 2024 1444.50 2024'
        }

        It 'does not read header cells of a record table or rich header cells as numbers' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Header @{ Text = '1,5' } -Row @(, @('1,5')))
            $text | Should -Be '1,5 1.5'
        }

        It 'warns once about an ambiguous number and leaves it unchanged' -Skip:(-not $script:havePdftotext) {
            $doc = New-VellumPdfDocument
            $text = Save-AndRead ($doc | Add-VellumPdfTable -Row @(@('1,234', '5.678'), @('x', 'y')) -WarningVariable warned -WarningAction SilentlyContinue)
            $text | Should -Match '1,234 5\.678'
            @($warned).Count | Should -Be 1
            "$($warned[0])" | Should -Match "Add-VellumPdfTable: 2 number text\(s\) are ambiguous.*'1,234', '5\.678'"
        }

        It 'resolves an ambiguous number from the other values of the same column' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1.444,50', '1,234'), @('2,5', '5.678'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -WarningVariable warned -WarningAction SilentlyContinue)
            # Column 1: '.' groups, so ',' is the decimal mark (1,234 would be 1.234 if it were in this column).
            $text | Should -Match '1444\.50 1,234'
            $text | Should -Match '2\.5 5\.678'
            @($warned).Count | Should -Be 1   # column 2 has no evidence: '1,234' and '5.678' stay
        }

        It 'uses the evidence of the same column only' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1,976.08'), @('1,234'), @('1.234'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -WarningVariable warned)
            $text | Should -Be '1976.08 1234 1.234'
            @($warned).Count | Should -Be 0
        }

        It '-InputCulture reads strings strictly with that culture' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1.234'), @('1.444,50'), @('55433.34'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows -InputCulture de-DE -WarningVariable warned)
            $text | Should -Be '1234 1444.50 55433.34'
            @($warned).Count | Should -Be 0
        }

        It 'the document -InputCulture applies, and a per-call -InputCulture overrides it ($null switches it off)' -Skip:(-not $script:havePdftotext) {
            $doc = New-VellumPdfDocument -InputCulture de-DE
            $doc | Add-VellumPdfTable -Row @(, @('1.234', 'doc')) | Out-Null
            $doc | Add-VellumPdfTable -Row @(, @('1.234', 'call')) -InputCulture en-US | Out-Null
            $doc | Add-VellumPdfTable -Row @(, @('1.234', 'off')) -InputCulture $null -WarningAction SilentlyContinue | Out-Null
            $text = Save-AndRead $doc
            $text | Should -Match '1234 doc'
            $text | Should -Match '1\.234 call'
            $text | Should -Match '1\.234 off'
        }

        It '-NoNumberParsing and Parse = $false draw the string as given' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @('1.444,50', '66443,85')) -NoNumberParsing -Culture de-DE)
            $text | Should -Be '1.444,50 66443,85'
            $rows = @(, @(@{ Text = '1.444,50'; Parse = $false }, '66443,85'))
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row $rows)
            $text | Should -Be '1.444,50 66443.85'
        }

        It 'Parse = $false does not stop non-string values from being formatted' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfTable -Row @(, @(@{ Text = 1234.5; Parse = $false })) -Culture de-DE)
            $text | Should -Be '1234,5'
        }

        It 'keeps a table tagged and valid when numbers are read from strings' -Skip:(-not ($script:havePdftotext -and $script:haveQpdf)) {
            $path = Join-Path $TestDrive 'tagged-flow.pdf'
            New-VellumPdfDocument -Conformance PdfUA1 -Language en-US |
                Set-VellumPdfDocumentInfo -Title 'Numbers' |
                Add-VellumPdfTable -Header 'Item', 'Amount' -Row @(@('Widget', '1.444,50'), @('Gadget', '55433.34')) -Culture de-DE |
                Save-VellumPdfDocument -Path $path -Validate | Out-Null
            (Test-VellumPdfConformance -Path $path -Profile PdfUA1).IsCompliant | Should -BeTrue
            ((& pdftotext -layout $path - 2>$null | Out-String) -replace '\s+', ' ') | Should -Match 'Widget 1444,50 Gadget 55433,34'
        }
    }

    Context 'page tables' {
        It 'reads numbers from strings, with the same rules' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1.444,50', '007'), @('1,976.08', '10.0.0.1'), @('55433.34', 'x'))
            $text = Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row $rows)
            $text | Should -Be '1444.50 007 1976.08 10.0.0.1 55433.34 x'
        }

        It 'does not read header cells as numbers, and uses column evidence' -Skip:(-not $script:havePdftotext) {
            $rows = @(@('1,976.08'), @('1,234'))
            $text = Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Header '1,5' -Row $rows -WarningVariable warned)
            $text | Should -Be '1,5 1976.08 1234'
            @($warned).Count | Should -Be 0
        }

        It 'warns once about ambiguous numbers' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('1,234', '2.345')) -WarningVariable warned -WarningAction SilentlyContinue)
            $text | Should -Be '1,234 2.345'
            @($warned).Count | Should -Be 1
        }

        It '-InputCulture, -NoNumberParsing and Parse = $false' -Skip:(-not $script:havePdftotext) {
            (Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('1.234', '1,5')) -InputCulture de-DE)) | Should -Be '1234 1.5'
            (Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('1.444,50', '66443,85')) -NoNumberParsing)) | Should -Be '1.444,50 66443,85'
            (Save-AndRead (New-Page | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @(@{ Text = '1.444,50'; Parse = $false }, '66443,85')))) | Should -Be '1.444,50 66443.85'
            $doc = New-Page @{ InputCulture = 'de-DE' }
            (Save-AndRead ($doc | Add-VellumPdfPageTable -X 50 -Y 700 -Width 300 -Row @(, @('1.234')))) | Should -Be '1234'
        }

        It 'a tagged PDF/UA page table with numbers read from strings still validates' -Skip:(-not ($script:havePdftotext -and $script:haveQpdf)) {
            $path = Join-Path $TestDrive 'tagged-page.pdf'
            New-VellumPdfPageDocument -Conformance PdfUA1 -Language en-US -Culture de-DE | Add-VellumPdfPage |
                Set-VellumPdfDocumentInfo -Title 'Numbers' |
                Add-VellumPdfPageTable -X 72 -Y 700 -Width 300 -Header 'Item', 'Amount' -ColumnAlignment Left, Right `
                    -Row @(@('Widget', '1.444,50'), @('Gadget', '55433.34'), @('Total', 56877.84)) |
                Save-VellumPdfDocument -Path $path -Validate | Out-Null
            (Test-VellumPdfConformance -Path $path -Profile PdfUA1).IsCompliant | Should -BeTrue
            ((& pdftotext -layout $path - 2>$null | Out-String) -replace '\s+', ' ') | Should -Match 'Widget 1444,50 Gadget 55433,34 Total 56877,84'
        }
    }

    Context 'lists' {
        It 'reads numbers from string items; the other items are the evidence' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item '1.444,50', '1,234', 'text 1,234', '007' -Style OrderedDecimal)
            $text | Should -Match '1444\.50'
            $text | Should -Match '1\.234'   # ',' is the decimal mark in this list: 1,234 -> 1.234
            $text | Should -Match 'text 1,234'
            $text | Should -Match '007'
        }

        It 'warns once about an ambiguous item and leaves it unchanged' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item '1,234', @{ Text = 'x'; Children = @('2.345') } -WarningVariable warned -WarningAction SilentlyContinue)
            $text | Should -Match '1,234'
            $text | Should -Match '2\.345'
            @($warned).Count | Should -Be 1
            "$($warned[0])" | Should -Match "'1,234', '2\.345'"
        }

        It '-Culture, -Format, -InputCulture, -NoNumberParsing and Parse = $false' -Skip:(-not $script:havePdftotext) {
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item '1.444,5', '66443,85' -Format 'N2' -Culture de-DE)) | Should -Match '1\.444,50'
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item '1.234' -InputCulture de-DE)) | Should -Match '1234'
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item '1.444,50' -NoNumberParsing)) | Should -Match '1\.444,50'
            (Save-AndRead (New-VellumPdfDocument | Add-VellumPdfList -Item @{ Text = '1.444,50'; Parse = $false }, '66443,85')) | Should -Match '1\.444,50.*66443\.85'
        }

        It 'page lists read numbers the same way' -Skip:(-not $script:havePdftotext) {
            $text = Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item '1.444,50', '55433.34', '007', @{ Text = '1,976.08'; Parse = $false })
            $text | Should -Match '1444\.50'
            $text | Should -Match '55433\.34'
            $text | Should -Match '007'
            $text | Should -Match '1,976\.08'
            $text = Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item '1,234' -WarningVariable warned -WarningAction SilentlyContinue)
            $text | Should -Match '1,234'
            @($warned).Count | Should -Be 1
            (Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item '1.444,5' -Culture de-DE -Format 'N2')) | Should -Match '1\.444,50'
            (Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item '1.444,50' -NoNumberParsing)) | Should -Match '1\.444,50'
            (Save-AndRead (New-Page | Add-VellumPdfPageList -X 50 -Y 700 -Width 300 -Item '1.234' -InputCulture de-DE)) | Should -Match '1234'
        }
    }
}
