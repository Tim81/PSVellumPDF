#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-VellumColor' {
    It 'passes through an R,G,B triple and rejects out-of-range or wrong-length input' {
        InModuleScope PSVellumPDF {
            ConvertTo-VellumColor @(0.1, 0.2, 0.3) | Should -Be @(0.1, 0.2, 0.3)   # numbers, not a culture-formatted string
            { ConvertTo-VellumColor @(0, 0, 2) } | Should -Throw '*between 0 and 1*'
            { ConvertTo-VellumColor @(0, 0) } | Should -Throw '*exactly 3*'
        }
    }

    It 'parses #RRGGBB and #RGB, and requires the leading #' {
        InModuleScope PSVellumPDF {
            ConvertTo-VellumColor '#ff0000' | Should -Be @(1, 0, 0)
            ConvertTo-VellumColor '#0f0' | Should -Be @(0, 1, 0)
            { ConvertTo-VellumColor '255' } | Should -Throw '*unrecognised colour*'
            { ConvertTo-VellumColor '#12' } | Should -Throw '*not a valid hex*'
        }
    }

    It 'knows the original and the extended CSS names, case-insensitively' {
        InModuleScope PSVellumPDF {
            ConvertTo-VellumColor 'NAVY' | Should -Be @(0, 0, 0.5)
            $gold = ConvertTo-VellumColor 'gold'
            [math]::Round($gold[0], 3) | Should -Be 1
            [math]::Round($gold[1], 3) | Should -Be 0.843
            [math]::Round($gold[2], 3) | Should -Be 0
            [math]::Round((ConvertTo-VellumColor 'steelblue')[0], 2) | Should -Be 0.27
            ConvertTo-VellumColor 'darkgrey' | Should -Be (ConvertTo-VellumColor 'darkgray')
        }
    }

    It 'returns $null for $null and throws for unknown names' {
        InModuleScope PSVellumPDF {
            ConvertTo-VellumColor $null | Should -BeNullOrEmpty
            { ConvertTo-VellumColor 'notacolour' } | Should -Throw '*unrecognised colour*'
        }
    }
}
