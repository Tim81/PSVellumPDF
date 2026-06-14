#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-VellumColor (private helper) - Feature 9: expanded palette' {
    # Blues
    It 'resolves darkblue to the correct CSS value (#00008B)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkblue' }
        $c[0] | Should -Be 0
        $c[1] | Should -Be 0
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x8B / 255.0, 4))
    }

    It 'resolves lightblue to the correct CSS value (#ADD8E6)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'lightblue' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xAD / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xD8 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xE6 / 255.0, 4))
    }

    It 'resolves royalblue (#4169E1)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'royalblue' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x41 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x69 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xE1 / 255.0, 4))
    }

    It 'resolves steelblue (#4682B4)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'steelblue' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x46 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x82 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xB4 / 255.0, 4))
    }

    # Greens
    It 'resolves darkgreen (#006400)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkgreen' }
        $c[0] | Should -Be 0
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x64 / 255.0, 4))
        $c[2] | Should -Be 0
    }

    It 'resolves forestgreen (#228B22)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'forestgreen' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x22 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x8B / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x22 / 255.0, 4))
    }

    It 'resolves seagreen (#2E8B57)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'seagreen' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x2E / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x8B / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x57 / 255.0, 4))
    }

    # Reds / pinks
    It 'resolves darkred (#8B0000)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkred' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x8B / 255.0, 4))
        $c[1] | Should -Be 0
        $c[2] | Should -Be 0
    }

    It 'resolves crimson (#DC143C)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'crimson' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xDC / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x14 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x3C / 255.0, 4))
    }

    It 'resolves coral (#FF7F50)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'coral' }
        $c[0] | Should -Be 1
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x7F / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x50 / 255.0, 4))
    }

    It 'resolves salmon (#FA8072)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'salmon' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xFA / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x80 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x72 / 255.0, 4))
    }

    It 'resolves pink (#FFC0CB)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'pink' }
        $c[0] | Should -Be 1
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xC0 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xCB / 255.0, 4))
    }

    # Yellows / golds / browns
    It 'resolves gold (#FFD700)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'gold' }
        $c[0] | Should -Be 1
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xD7 / 255.0, 4))
        $c[2] | Should -Be 0
    }

    It 'resolves khaki (#F0E68C)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'khaki' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xF0 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xE6 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x8C / 255.0, 4))
    }

    It 'resolves brown (#A52A2A)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'brown' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xA5 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x2A / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x2A / 255.0, 4))
    }

    It 'resolves chocolate (#D2691E)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'chocolate' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xD2 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x69 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x1E / 255.0, 4))
    }

    It 'resolves tan (#D2B48C)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'tan' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xD2 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xB4 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x8C / 255.0, 4))
    }

    It 'resolves beige (#F5F5DC)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'beige' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xF5 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xF5 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xDC / 255.0, 4))
    }

    # Purples
    It 'resolves indigo (#4B0082)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'indigo' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x4B / 255.0, 4))
        $c[1] | Should -Be 0
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x82 / 255.0, 4))
    }

    It 'resolves violet (#EE82EE)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'violet' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xEE / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x82 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xEE / 255.0, 4))
    }

    It 'resolves lavender (#E6E6FA)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'lavender' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xE6 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xE6 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xFA / 255.0, 4))
    }

    # Whites / grays
    It 'resolves ivory (#FFFFF0)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'ivory' }
        $c[0] | Should -Be 1
        $c[1] | Should -Be 1
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xF0 / 255.0, 4))
    }

    It 'resolves lightgray (#D3D3D3)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'lightgray' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xD3 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xD3 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xD3 / 255.0, 4))
    }

    It 'resolves lightgrey as the same triple as lightgray' {
        $a = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'lightgray' }
        $b = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'lightgrey' }
        $a[0] | Should -Be $b[0]
        $a[1] | Should -Be $b[1]
        $a[2] | Should -Be $b[2]
    }

    It 'resolves darkgray (#A9A9A9)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkgray' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0xA9 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xA9 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xA9 / 255.0, 4))
    }

    It 'resolves darkgrey as the same triple as darkgray' {
        $a = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkgray' }
        $b = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkgrey' }
        $a[0] | Should -Be $b[0]
        $a[1] | Should -Be $b[1]
        $a[2] | Should -Be $b[2]
    }

    It 'resolves slategray (#708090)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'slategray' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x70 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0x80 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0x90 / 255.0, 4))
    }

    It 'resolves slategrey as the same triple as slategray' {
        $a = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'slategray' }
        $b = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'slategrey' }
        $a[0] | Should -Be $b[0]
        $a[1] | Should -Be $b[1]
        $a[2] | Should -Be $b[2]
    }

    # Cyans
    It 'resolves turquoise (#40E0D0)' {
        $c = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'turquoise' }
        [math]::Round($c[0], 4) | Should -Be ([math]::Round(0x40 / 255.0, 4))
        [math]::Round($c[1], 4) | Should -Be ([math]::Round(0xE0 / 255.0, 4))
        [math]::Round($c[2], 4) | Should -Be ([math]::Round(0xD0 / 255.0, 4))
    }

    It 'resolves colour names case-insensitively (DarkBlue, DARKBLUE)' {
        $lower = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'darkblue' }
        $mixed = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'DarkBlue' }
        $upper = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'DARKBLUE' }
        $lower[0] | Should -Be $mixed[0]; $lower[1] | Should -Be $mixed[1]; $lower[2] | Should -Be $mixed[2]
        $lower[0] | Should -Be $upper[0]; $lower[1] | Should -Be $upper[1]; $lower[2] | Should -Be $upper[2]
    }

    It 'still throws on an unrecognised name' {
        { InModuleScope PSVellumPDF { ConvertTo-VellumColor 'notacolour' } } |
            Should -Throw '*unrecognised colour*'
    }

    It 'existing colour names still work (red, blue, orange)' {
        $r = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'red' }
        $r[0] | Should -Be 1; $r[1] | Should -Be 0; $r[2] | Should -Be 0

        $b = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'blue' }
        $b[0] | Should -Be 0; $b[1] | Should -Be 0; $b[2] | Should -Be 1

        $o = InModuleScope PSVellumPDF { ConvertTo-VellumColor 'orange' }
        $o[0] | Should -Be 1
    }

    It 'new colours can be used in a real PDF pipeline (produces valid PDF)' {
        $outPath = Join-Path $TestDrive "colour-palette-$([guid]::NewGuid()).pdf"
        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Steel Blue Heading' -Level 1 -Color 'steelblue' |
            Add-VellumPdfParagraph -Text 'Crimson text.' -Color 'crimson' |
            Save-VellumPdfDocument -Path $outPath

        Test-Path $outPath | Should -BeTrue
        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}
