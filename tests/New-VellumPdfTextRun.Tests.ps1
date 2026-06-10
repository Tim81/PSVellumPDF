#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force

    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'
    if (-not (Test-Path $script:fontPath)) {
        throw "Test font asset not found at '$($script:fontPath)'. Cannot run embedded-font tests."
    }
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'New-VellumPdfTextRun' {
    It 'is exported by the module' {
        $exported = (Get-Module PSVellumPDF).ExportedFunctions.Keys
        $exported | Should -Contain 'New-VellumPdfTextRun'
    }

    It 'returns a TextRun with the correct Text property' {
        $run = New-VellumPdfTextRun -Text 'Hello'
        $run | Should -BeOfType 'VellumPdf.Layout.Elements.TextRun'
        $run.Text | Should -Be 'Hello'
    }

    It 'returns a TextRun with a non-null Style when no styling is supplied' {
        # Null style causes NullReferenceException at render; must be non-null.
        $run = New-VellumPdfTextRun -Text 'Unstyled'
        $run.Style | Should -Not -BeNullOrEmpty
    }

    It 'sets Style.Color when -Color is supplied' {
        $run = New-VellumPdfTextRun -Text 'Red' -Color 1.0, 0.0, 0.0
        $run.Style | Should -Not -BeNullOrEmpty
        $run.Style.Color.R | Should -Be 1.0
        $run.Style.Color.G | Should -Be 0.0
        $run.Style.Color.B | Should -Be 0.0
    }

    It 'sets Style.LinkUri when -LinkUri is supplied' {
        $run = New-VellumPdfTextRun -Text 'Click' -LinkUri 'https://example.com'
        $run.Style | Should -Not -BeNullOrEmpty
        $run.Style.LinkUri | Should -Be 'https://example.com'
    }

    It 'sets Style.FontSize when -FontSize is supplied' {
        $run = New-VellumPdfTextRun -Text 'Big' -FontSize 18
        $run.Style.FontSize | Should -Be 18
    }

    It 'accepts -Font and sets a non-null style' {
        $run = New-VellumPdfTextRun -Text 'Courier text' -Font Courier -FontSize 10
        $run | Should -BeOfType 'VellumPdf.Layout.Elements.TextRun'
        $run.Style | Should -Not -BeNullOrEmpty
        $run.Style.FontSize | Should -Be 10
    }

    It 'validates -Color must have exactly 3 elements' {
        { New-VellumPdfTextRun -Text 'Bad' -Color 1.0, 0.0 } | Should -Throw
    }

    It 'validates -Color values must be between 0 and 1' {
        { New-VellumPdfTextRun -Text 'Bad' -Color 2.0, 0.0, 0.0 } | Should -Throw
    }

    It 'combines -Color and -LinkUri in one run' {
        $run = New-VellumPdfTextRun -Text 'Styled link' -Color 0.0, 0.0, 1.0 -LinkUri 'https://example.com'
        $run.Style.Color.B | Should -Be 1.0
        $run.Style.LinkUri | Should -Be 'https://example.com'
    }

    It 'sets Style.Leading when -Leading is supplied' {
        $run = New-VellumPdfTextRun -Text 'Spaced' -Leading 14.0
        $run | Should -BeOfType 'VellumPdf.Layout.Elements.TextRun'
        $run.Style | Should -Not -BeNullOrEmpty
        $run.Style.Leading | Should -Be 14.0
    }
}

Describe 'Add-VellumPdfParagraph Runs parameter set' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "para-$([guid]::NewGuid()).pdf"
        $script:doc = New-VellumPdfDocument
    }

    AfterEach {
        if ($script:doc) {
            try { $script:doc.Dispose() } catch { Write-Verbose "Dispose skipped: $_" }
        }
    }

    It 'renders a paragraph composed of 3 runs to a valid PDF' {
        $run1 = New-VellumPdfTextRun -Text 'Plain text '
        $run2 = New-VellumPdfTextRun -Text 'Red text ' -Color 1.0, 0.0, 0.0
        $run3 = New-VellumPdfTextRun -Text 'Link' -LinkUri 'https://example.com'

        $script:doc |
            Add-VellumPdfParagraph -Run $run1, $run2, $run3 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'applies -Alignment to a runs-based paragraph' {
        $run1 = New-VellumPdfTextRun -Text 'Centered run'

        $script:doc |
            Add-VellumPdfParagraph -Run $run1 -Alignment Center |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0
    }

    It 'returns the document for pipeline chaining' {
        $run = New-VellumPdfTextRun -Text 'Chainable'
        $result = $script:doc | Add-VellumPdfParagraph -Run $run
        $result | Should -BeOfType 'VellumPdf.Layout.Document'
    }

    It 'rejects -Text and -Run together (mutual exclusion)' {
        $run = New-VellumPdfTextRun -Text 'A run'
        { $script:doc | Add-VellumPdfParagraph -Text 'Some text' -Run $run } |
            Should -Throw
    }

    It 'renders an embedded-font run inside a runs paragraph to a valid PDF' {
        $handle = Register-VellumPdfFont -Document $script:doc -Path $script:fontPath

        $run1 = New-VellumPdfTextRun -Text 'TrueType run' -FontHandle $handle -FontSize 12
        $run2 = New-VellumPdfTextRun -Text ' normal run'

        $script:doc |
            Add-VellumPdfParagraph -Run $run1, $run2 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'Add-VellumPdfParagraph Text parameter set with Color and LinkUri' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "para-$([guid]::NewGuid()).pdf"
        $script:doc = New-VellumPdfDocument
    }

    AfterEach {
        if ($script:doc) {
            try { $script:doc.Dispose() } catch { Write-Verbose "Dispose skipped: $_" }
        }
    }

    It 'renders -Text with -Color to a valid PDF' {
        $script:doc |
            Add-VellumPdfParagraph -Text 'Red paragraph' -Color 1.0, 0.0, 0.0 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'renders -Text with -LinkUri to a valid PDF' {
        $script:doc |
            Add-VellumPdfParagraph -Text 'Hyperlink paragraph' -LinkUri 'https://example.com' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'renders -Text with -Font, -FontSize, and -Color combined' {
        $script:doc |
            Add-VellumPdfParagraph -Text 'Blue bold' -Font HelveticaBold -FontSize 14 -Color 0.0, 0.0, 1.0 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'chains runs paragraph with other Add-VellumPdf* functions' {
        $run1 = New-VellumPdfTextRun -Text 'Intro run '
        $run2 = New-VellumPdfTextRun -Text 'bold run' -Font HelveticaBold -FontSize 11

        New-VellumPdfDocument |
            Add-VellumPdfHeading -Text 'Rich Text Demo' -Level 1 |
            Add-VellumPdfParagraph -Run $run1, $run2 |
            Add-VellumPdfParagraph -Text 'Plain paragraph after runs.' |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }

    It 'renders a -Leading paragraph to a valid PDF' {
        $script:doc |
            Add-VellumPdfParagraph -Text 'Double-spaced paragraph.' -Leading 24.0 |
            Save-VellumPdfDocument -Path $script:outPath

        Test-Path $script:outPath | Should -BeTrue
        (Get-Item $script:outPath).Length | Should -BeGreaterThan 0

        $head = [System.Text.Encoding]::ASCII.GetString(
            [System.IO.File]::ReadAllBytes($script:outPath)[0..4])
        $head | Should -Be '%PDF-'
    }
}

Describe 'New-VellumTextStyle with Color and LinkUri (private helper)' {
    It 'returns $null when no params are supplied (Color/LinkUri not requested)' {
        InModuleScope PSVellumPDF { New-VellumTextStyle } | Should -BeNullOrEmpty
    }

    It 'returns a TextStyle with Color when -Color is supplied' {
        $style = InModuleScope PSVellumPDF {
            New-VellumTextStyle -Color 0.5, 0.25, 0.75
        }
        $style | Should -Not -BeNullOrEmpty
        $style.Color.R | Should -Be 0.5
        $style.Color.G | Should -Be 0.25
        $style.Color.B | Should -Be 0.75
    }

    It 'returns a TextStyle with LinkUri when -LinkUri is supplied' {
        $style = InModuleScope PSVellumPDF {
            New-VellumTextStyle -LinkUri 'https://example.com'
        }
        $style | Should -Not -BeNullOrEmpty
        $style.LinkUri | Should -Be 'https://example.com'
    }

    It 'combines Font, Color, and LinkUri in one TextStyle' {
        $style = InModuleScope PSVellumPDF {
            New-VellumTextStyle -Font Helvetica -FontSize 12 -Color 1.0, 0.0, 0.0 -LinkUri 'https://example.com'
        }
        $style | Should -Not -BeNullOrEmpty
        $style.FontSize | Should -Be 12
        $style.Color.R | Should -Be 1.0
        $style.LinkUri | Should -Be 'https://example.com'
    }
}
