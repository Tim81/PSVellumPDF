function Get-VellumPdfBlockVariable {
    <#
    .SYNOPSIS
        Snapshots the caller's variables that a script block uses, for a block that runs later.
    .DESCRIPTION
        Add-VellumPdfDrawing runs its script block while the document is saved. Without help the block
        would see the variables as they are then: a loop variable holds its last value and a function's
        locals are gone. This returns copies of the variables the block reads (unqualified names only,
        taken from the scope the block was written in) so the block can run with the values they had
        when it was added.

        ScriptBlock.GetNewClosure() cannot do this from inside a module (it captures the module's own
        scope) and would also cut the block off from $script: and $global:, so the block stays bound to
        its own session state and the copies are supplied when it is invoked (ScriptBlock.InvokeWithContext).
        Returns an empty array when the block's session state cannot be reached.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSVariable[]])]
    param([Parameter(Mandatory)] [scriptblock]$ScriptBlock)

    $state = $null
    try {
        $property = [scriptblock].GetProperty('SessionState', [System.Reflection.BindingFlags]'Instance,NonPublic')
        if ($property) { $state = $property.GetValue($ScriptBlock) }
    }
    catch { Write-Verbose "The script block's session state is not reachable: $_" }
    if (-not $state) { return @() }

    # Names that must keep their live meaning: automatic variables and the block's own parameters.
    $skip = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            '_', 'args', 'input', 'this', 'PSItem', 'true', 'false', 'null', 'PSCmdlet', 'MyInvocation',
            'PSBoundParameters', 'PSScriptRoot', 'PSCommandPath', 'ExecutionContext', 'Error', 'LASTEXITCODE'),
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($parameter in @($ScriptBlock.Ast.ParamBlock?.Parameters)) {
        if ($parameter) { [void]$skip.Add($parameter.Name.VariablePath.UserPath) }
    }

    $nodes = $ScriptBlock.Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($node in $nodes) {
        $path = $node.VariablePath
        if (-not $path.IsUnscopedVariable) { continue }   # $script:x, $global:x, $using:x keep their live meaning
        $name = $path.UserPath
        if ($skip.Contains($name) -or -not $seen.Add($name)) { continue }
        $found = $state.PSVariable.Get($name)
        if ($found -and -not ($found.Options -band [System.Management.Automation.ScopedItemOptions]'ReadOnly,Constant')) {
            , [System.Management.Automation.PSVariable]::new($name, $found.Value)
        }
    }
}
