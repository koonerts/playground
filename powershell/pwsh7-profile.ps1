using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function global:InstallModule {
    param (
        [Parameter(Mandatory)][string]$moduleName,
        [boolean]$preRelease
    )

    if ($preRelease) {
        Install-Module $moduleName -AllowPrerelease -Force -Scope AllUsers -Repository PSGallery -SkipPublisherCheck
    }
    else {
        Install-Module $moduleName -Force -Scope AllUsers -Repository PSGallery -SkipPublisherCheck
    }
}

function global:ImportModule {
    param (
        [Parameter(Mandatory)][string]$moduleName
    )

    $module = (Get-Module -Name $moduleName)
    if (!$module) {
		"Importing module $moduleName..."
        Import-Module $moduleName -scope Global -Force
    }
}

if ($PSVersionTable.PSEdition -eq 'Core') {
    $env:PSModulePath="C:\Program Files\PowerShell\Modules;c:\program files\powershell\7-preview\Modules;C:\Program Files\WindowsPowerShell\Modules;C:\Windows\System32\WindowsPowerShell\v1.0\Modules;C:\Program Files (x86)\Red Gate\SQL Change Automation PowerShell\Modules\;C:\Program Files (x86)\Microsoft Azure Information Protection\Powershell;C:\Program Files (x86)\AWS Tools\PowerShell\"

    ImportModule PSReadLine
    ImportModule PSScriptTools
    ImportModule AWSPowerShell.NetCore
    ImportModule posh-git
    ImportModule oh-my-posh
    ImportModule AWSLambdaPSCore
    ImportModule PSUtil

    set-theme paradox
    $env:PYTHONIOENCODING="utf-8"
    #iex "$(thefuck --alias)"
}
else {
    Import-Module PSReadLine
}


Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Searching for commands with up/down arrow is really handy.  The
# option "moves to end" is useful if you want the cursor at the end
# of the line while cycling through history like it does w/o searching,
# without that option, the cursor will remain at the position it was
# when you used up arrow, which can be useful if you forget the exact
# string you started the search on.
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# CaptureScreen is good for blog posts or email showing a transaction
# of what you did when asking for help or demonstrating a technique.
Set-PSReadLineKeyHandler -Chord 'Ctrl+d,Ctrl+c' -Function CaptureScreen


# This key handler shows the entire or filtered history using Out-GridView. The
# typed text is used as the substring pattern for filtering. A selected command
# is inserted to the command line without invoking. Multiple command selection
# is supported, e.g. selected by Ctrl + Click.
Set-PSReadLineKeyHandler -Key F7 `
                         -BriefDescription History `
                         -LongDescription 'Show command history' `
                         -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern)
    {
        $pattern = [regex]::Escape($pattern)
    }

    $history = [System.Collections.ArrayList]@(
    $last = ''
    $lines = ''
    foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath))
    {
        if ($line.EndsWith('`'))
        {
            $line = $line.Substring(0, $line.Length - 1)
            $lines = if ($lines)
            {
                "$lines`n$line"
            }
            else
            {
                $line
            }
            continue
        }

        if ($lines)
        {
            $line = "$lines`n$line"
            $lines = ''
        }

        if (($line -cne $last) -and (!$pattern -or ($line -match $pattern)))
        {
            $last = $line
            $line
        }
    }
    )
    $history.Reverse()

    $command = $history | Out-GridView -Title History -PassThru
    if ($command)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

# This is an example of a macro that you might use to execute a command.
# This will add the command to history.
Set-PSReadLineKeyHandler -Key Ctrl+b `
                         -BriefDescription BuildCurrentDirectory `
                         -LongDescription "Build the current directory" `
                         -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("msbuild")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}


# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

Set-PSReadLineKeyHandler -Key '"',"'" `
                         -BriefDescription SmartInsertQuote `
                         -LongDescription "Insert paired quotes if not already on a quote" `
                         -ScriptBlock {
    param($key, $arg)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    $ast = $null
    $tokens = $null
    $parseErrors = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

    function FindToken
    {
        param($tokens, $cursor)

        foreach ($token in $tokens)
        {
            if ($cursor -lt $token.Extent.StartOffset) { continue }
            if ($cursor -lt $token.Extent.EndOffset) {
                $result = $token
                $token = $token -as [StringExpandableToken]
                if ($token) {
                    $nested = FindToken $token.NestedTokens $cursor
                    if ($nested) { $result = $nested }
                }

                return $result
            }
        }
        return $null
    }

    $token = FindToken $tokens $cursor

    # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
        # If we're at the start of the string, assume we're inserting a new string
        if ($token.Extent.StartOffset -eq $cursor) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }

        # If we're at the end of the string, move over the closing quote if present.
        if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }
    }

    if ($null -eq $token -or
            $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
        if ($line[0..$cursor].Where{$_ -eq $quote}.Count % 2 -eq 1) {
            # Odd number of quotes before the cursor, insert a single quote
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
        }
        else {
            # Insert matching quotes, move cursor to be in between the quotes
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        return
    }

    # If cursor is at the start of a token, enclose it in quotes.
    if ($token.Extent.StartOffset -eq $cursor) {
        if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
                $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
            $end = $token.Extent.EndOffset
            $len = $end - $cursor
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
            return
        }
    }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(','{','[' `
                         -BriefDescription InsertPairedBraces `
                         -LongDescription "Insert matching braces" `
                         -ScriptBlock {
    param($key, $arg)

    $closeChar = switch ($key.KeyChar)
    {
        <#case#> '(' { [char]')'; break }
        <#case#> '{' { [char]'}'; break }
        <#case#> '[' { [char]']'; break }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    #$keychar = $key.KeyChar
    #$nextChar = $line[$cursor]

    if ($selectionStart -ne -1) {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    } else {
        $clip = gcb
        $clip = $clip -join "`n"
        if ($clip[$cursor] -eq $key.KeyChar -and $clip.SubString($cursor+1)) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
    }
}


Set-PSReadLineKeyHandler -Key ')',']','}' `
                         -BriefDescription SmartCloseBraces `
                         -LongDescription "Insert closing brace or skip" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    #$keychar = $key.KeyChar
    #"$keychar $line $cursor" >> 'testing.txt'

    if ($line[$cursor] -eq $key.KeyChar)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace `
                         -BriefDescription SmartBackspace `
                         -LongDescription "Delete previous character or matching quotes/parens/braces" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0)
    {
        $toMatch = $null
        if ($cursor -lt $line.Length)
        {
            switch ($line[$cursor])
            {
                <#case#> '"' { $toMatch = '"'; break }
                <#case#> "'" { $toMatch = "'"; break }
                <#case#> ')' { $toMatch = '('; break }
                <#case#> ']' { $toMatch = '['; break }
                <#case#> '}' { $toMatch = '{'; break }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor-1] -eq $toMatch)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        }
        else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}


# Sometimes you enter a command but realize you forgot to do something else first.
# This binding will let you save that command in the history so you can recall it,
# but it doesn't actually execute.  It also clears the line with RevertLine so the
# undo stack is reset - though redo will still reconstruct the command line.
Set-PSReadLineKeyHandler -Key Alt+w `
                         -BriefDescription SaveInHistory `
                         -LongDescription "Save current line in history but do not execute" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# Insert text from the clipboard as a here string
Set-PSReadLineKeyHandler -Key Ctrl+V `
                         -BriefDescription PasteAsHereString `
                         -LongDescription "Paste the clipboard text as a here string" `
                         -ScriptBlock {
    param($key, $arg)

    Add-Type -Assembly PresentationCore
    if ([System.Windows.Clipboard]::ContainsText())
    {
        # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n","`n").TrimEnd()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

# Sometimes you want to get a property of invoke a member on what you've entered so far
# but you need parens to do that.  This binding will help by putting parens around the current selection,
# or if nothing is selected, the whole line.
Set-PSReadLineKeyHandler -Key 'Alt+(' `
                         -BriefDescription ParenthesizeSelection `
                         -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
                         -ScriptBlock {
    param($key, $arg)

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

# Each time you press Alt+', this key handler will change the token
# under or before the cursor.  It will cycle through single quotes, double quotes, or
# no quotes each time it is invoked.
Set-PSReadLineKeyHandler -Key "Alt+'" `
                         -BriefDescription ToggleQuoteArgument `
                         -LongDescription "Toggle quotes on the argument under the cursor" `
                         -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $tokenToChange = $null
    foreach ($token in $tokens)
    {
        $extent = $token.Extent
        if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor)
        {
            $tokenToChange = $token

            # If the cursor is at the end (it's really 1 past the end) of the previous token,
            # we only want to change the previous token if there is no token under the cursor
            if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext())
            {
                $nextToken = $foreach.Current
                if ($nextToken.Extent.StartOffset -eq $cursor)
                {
                    $tokenToChange = $nextToken
                }
            }
            break
        }
    }

    if ($tokenToChange -ne $null)
    {
        $extent = $tokenToChange.Extent
        $tokenText = $extent.Text
        if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"')
        {
            # Switch to no quotes
            $replacement = $tokenText.Substring(1, $tokenText.Length - 2)
        }
        elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'")
        {
            # Switch to double quotes
            $replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
        }
        else
        {
            # Add single quotes
            $replacement = "'" + $tokenText + "'"
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                $extent.StartOffset,
                $tokenText.Length,
                $replacement)
    }
}

# This example will replace any aliases on the command line with the resolved commands.
Set-PSReadLineKeyHandler -Key "Alt+%" `
                         -BriefDescription ExpandAliases `
                         -LongDescription "Replace all aliases with the full command" `
                         -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $startAdjustment = 0
    foreach ($token in $tokens)
    {
        if ($token.TokenFlags -band [TokenFlags]::CommandName)
        {
            $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
            if ($alias -ne $null)
            {
                $resolvedCommand = $alias.ResolvedCommandName
                if ($resolvedCommand -ne $null)
                {
                    $extent = $token.Extent
                    $length = $extent.EndOffset - $extent.StartOffset
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                            $extent.StartOffset + $startAdjustment,
                            $length,
                            $resolvedCommand)

                    # Our copy of the tokens won't have been updated, so we need to
                    # adjust by the difference in length
                    $startAdjustment += ($resolvedCommand.Length - $length)
                }
            }
        }
    }
}

# F1 for help on the command line - naturally
Set-PSReadLineKeyHandler -Key F1 `
                         -BriefDescription CommandHelp `
                         -LongDescription "Open the help window for the current command" `
                         -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $commandAst = $ast.FindAll( {
        $node = $args[0]
        $node -is [CommandAst] -and
                $node.Extent.StartOffset -le $cursor -and
                $node.Extent.EndOffset -ge $cursor
    }, $true) | Select-Object -Last 1

    if ($commandAst -ne $null)
    {
        $commandName = $commandAst.GetCommandName()
        if ($commandName -ne $null)
        {
            $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
            if ($command -is [AliasInfo])
            {
                $commandName = $command.ResolvedCommandName
            }

            if ($commandName -ne $null)
            {
                Get-Help $commandName -ShowWindow
            }
        }
    }
}


#
# Ctrl+Shift+j then type a key to mark the current directory.
# Ctrj+j then the same key will change back to that directory without
# needing to type cd and won't change the command line.

#
$global:PSReadLineMarks = @{}

Set-PSReadLineKeyHandler -Key Ctrl+J `
                         -BriefDescription MarkDirectory `
                         -LongDescription "Mark the current directory" `
                         -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey($true)
    $global:PSReadLineMarks[$key.KeyChar] = $pwd
}

Set-PSReadLineKeyHandler -Key Ctrl+j `
                         -BriefDescription JumpDirectory `
                         -LongDescription "Goto the marked directory" `
                         -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey()
    $dir = $global:PSReadLineMarks[$key.KeyChar]
    if ($dir)
    {
        cd $dir
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}

Set-PSReadLineKeyHandler -Key Alt+j `
                         -BriefDescription ShowDirectoryMarks `
                         -LongDescription "Show the currently marked directories" `
                         -ScriptBlock {
    param($key, $arg)

    $global:PSReadLineMarks.GetEnumerator() | % {
        [PSCustomObject]@{Key = $_.Key; Dir = $_.Value} } |
            Format-Table -AutoSize | Out-Host

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# Auto correct 'git cmt' to 'git commit'
Set-PSReadLineOption -CommandValidationHandler {
    param([CommandAst]$CommandAst)

    switch ($CommandAst.GetCommandName())
    {
        'git' {
            $gitCmd = $CommandAst.CommandElements[1].Extent
            switch ($gitCmd.Text)
            {
                'cmt' {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                            $gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'commit')
                }
            }
        }
    }
}

# `ForwardChar` accepts the entire suggestion text when the cursor is at the end of the line.
# This custom binding makes `RightArrow` behave similarly - accepting the next word instead of the entire suggestion text.
Set-PSReadLineKeyHandler -Key RightArrow `
                         -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
                         -LongDescription "Move cursor one character to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
    }
}

function global:TfGet {
    param (
        [Parameter(Mandatory)]
        [string]
        $target
    )

    if ($target -eq 'all') {
        tf get $all_s /recursive
        tf get $all_l /recursive
    }
    else {
        tf get $target /recursive
    }
}

function global:TfClean {
    param (
        [Parameter(Mandatory)]
        [string]
        $target
    )

    tf reconcile $target /clean /recursive
}

function global:TfPromote {
    param (
        [Parameter(Mandatory)]
        [string]
        $target
    )

    tf reconcile $target /promote /recursive
}

function global:AddFileToZip {
    Param(
        [Parameter(Mandatory)][string]$zipFileName,
        [Parameter(Mandatory)][string]$fileToAdd
    )

    try {
        $zipFileName = GetFilePath $zipFileName
        $fileToAdd = GetFilePath $fileToAdd
        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
        $zip = [System.IO.Compression.ZipFile]::Open($zipFileName,"Update")
        $FileName = [System.IO.Path]::GetFileName($fileToAdd)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$fileToAdd,$FileName,"Optimal") | Out-Null
        $Zip.Dispose()
        Write-Host "Successfully added $fileToAdd to $zipFileName "
    } catch {
        Write-Warning "Failed to add $fileToAdd to $zipFileName . Details : $_"
    }
}

function global:GetFilePath {
    param(
        [Parameter(Mandatory)][string]$file
    )
    $file = ToLinuxPath $file
    if ($file -match "/") {
        return $file
    }
    else {
        return ToLinuxPath "$pwd/$file"
    }
}

function global:RunGoAlgo {
    $orig=pwd
    cd "$proj_home/algo/go-algo"
    C:\go\go1.16rc1\bin\go.exe build -o ~\AppData\Local\Temp\___2go_build_go_algo.exe . #gosetup
    ~\AppData\Local\Temp\___2go_build_go_algo.exe
    cd $orig
}

function global:GitSwitch {
    param (
        [Parameter(Mandatory)]
        [string]
        $branch
    )

    if ($branch -eq 'dev') {
        git switch Development
    }
    elseif ($branch -eq 'qa') {
        git switch QA
    }
    elseif ($branch -eq 'qa2') {
        git switch QA2
    }
    elseif ($branch -eq 'uat') {
        git switch UAT
    }
    elseif ($branch -eq 'prd' -or $branch -eq 'prod') {
        git switch Production
    }
}

function global:GetGitBranchName {
    param (
        [string]$branch
    )

    if (!$branch) {
        return (git branch --show-current)
    }
    elseif ($branch -eq 'dev') {
        $branch = 'Development'
    }
    elseif ($branch -eq 'qa') {
        $branch = 'QA'
    }
    elseif ($branch -eq 'qa2') {
        $branch = 'QA2'
    }
    elseif ($branch -eq 'uat') {
        $branch = 'UAT'
    }
    elseif ($branch -eq 'prd' -or $branch -eq 'prod') {
        $branch = 'Production'
    }
    else {
        $branch = $null
    }

    return $branch
}

function global:GitFastForward {
    param (
        [string]$branch
    )

    $branch = GetGitBranchName $branch

    "Fast-forwarding $branch..."
    if ($branch -ne $current) {
        git fetch origin ($branch + ":" + $branch)
        #git switch $branch
        #git pull --ff-only
        #git switch $current
    }
    else {
        git pull --ff-only
    }
    "Done"
}

function global:GitPullAll {
    $current = (git branch --show-current)
    (git branch).Replace("*", "").Trim()  | ForEach-Object -Parallel {
        git switch $_
        git pull
    }
    git switch $current
}

function global:GitPushAll {
    param (
        [Parameter(Mandatory)][string]$message
    )
    git add --all
    git commit -m $message
    git push
}

function global:CleanCdk {
    "Removing .js/.d.ts files.."
    $paths = "$aws_cdk\bin","$aws_cdk\lib","$aws_cdk\config","$aws_cdk\test"
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Get-ChildItem $path -recurse -exclude "*/.env/*","*/node_modules/*","app.js" -include *.js,*.d.ts | Where { $_.DirectoryName -notlike '*\node_modules\*' -and $_.DirectoryName -notlike '*\lambdas\*' } | Remove-Item -Recurse -Force
        }
    }
    "Finished"

    "Removing cdk.out..."
    if (Test-Path "$aws_cdk/cdk.out") { rm -r -fo "$aws_cdk/cdk.out" }
    "Finished"
}

function global:BuildCdk {
    param (
        [Parameter(Mandatory)]
        [string]
        $node_env
    )
    
    $originalPath = $pwd
    cd $aws_cdk
    
    if ($node_env -eq "dev") {
        $env:NODE_ENV="dev"
    }
    elseif ($node_env -eq "qa") {
        $env:NODE_ENV="qa"
    }
    elseif ($node_env -eq "qa2") {
        $env:NODE_ENV="qa2"
    }
    elseif ($node_env -eq "UAT") {
        $env:NODE_ENV="uat"
    }
    elseif ($node_env -eq "Prod") {
        $env:NODE_ENV="prod"
    }

    npm run build-config
    tsc
    cd $originalPath
}

function global:RemoveItem {
    param (
        [Parameter(Mandatory)]
        [string]
        $target
    )

    if (Test-Path $target) { rm -r -fo $target }
}


function global:ToLinuxPath {
    param (
        [Parameter(Mandatory)]
        [string]
        $path
    )
    return $path.Replace("\", "/")
}

function global:CleanWebsite {
    $paths = $dev_s,$dev_l,$qa_s,$qa_l,$qa2_s,$qa2_l,$uat_s,$uat_l,$prod_s,$prod_l
    $matches = "Microsoft.TeamFoundation","Voltage.SecureData.Native.x64.dll","Voltage.SecureData.Native.x64.dll","Specflow.tests"

    foreach ($path in $paths) {
        foreach ($match in $matches) {
            Get-ChildItem "$path\website\Bin" | Where{$_.Name -Match $match} | Write-Output | Remove-Item
        }
    }
}

function global:CreateGitDiff {
    param (
        [Parameter()][string]$ref
    )

    $origDir = $pwd
    cd $aws_home

    if ($ref) {

        $branchName = GetGitBranchName $ref
        if ($branchName) {
            $ref = $branchName
            $status = git diff HEAD $ref --name-only
        }
        else {
            $status = git ls-files
        }
    }
    else {
        $status= (git status --porcelain | ForEach-Object { $_.Substring(3) })
        if (!$status) {
            $status = git diff HEAD^ --name-only
        }
    }

    $status > "./build-changes.txt"
    ""
    $status
    ""
    cd $origDir
}

function global:CleanAndZip {
    param (
        [Parameter(Mandatory)]
        [string]
        $basePath,

        [Parameter(Mandatory)]
        [string]
        $outputDir,

        [Parameter(Mandatory)]
        [string]
        $outputFile,

        [Parameter(Mandatory)]
        [string[]]
        $subDirectories
    )
    $subDirectories = $subDirectories.Replace("\", "/")
    if ([bool]($subDirectories -match "/cdk")) { CleanCdk }

    rmrf "$outputDir\$outputFile"
    $origPath = pwd
    cd $basePath
    7z.exe a "$outputDir\$outputFile" $subDirectories `
     -mx=5 -mmt=6 -xr!*'.package' -xr!*'.git' -xr!*'.git'* `
     -xr!node_modules -xr!bswiftServerless\Web\ChatWidget\element -xr!bswiftserverless\*\bin -xr!bswiftserverless\*\obj -xr!"bswift .net\*\bin" -xr!"bswift .net\*\obj" `
     -xr!'cdk.out' -xr!*'$tf', -xr!*'$tf'* -xr!*'.env' -xr!*'.venv' -xr!*'.idea' -xr!*'.vs' -xr!*'.vscode' -xr!*'.aws-sam' -xr!CDK/**/lambda-layers/dotnet/*/packages -xr!CDK/**/lambda-layers/python/*/python -xr!CDK/**/lambda-layers/nodejs/*/nodejs `
     -xr!'CDK/**/lambda-layers/dotnet/*/packages.zip' -xr!'CDK/**/lambda-layers/python/*/python.zip' -xr!'CDK/**/lambda-layers/nodejs/*/nodejs.zip' -xr!*'.mpg' -xr!*'.mp4' -xr!*'.mpeg' -xr!*'.mpe' -xr!*'.mpv' -xr!*'.ogg' -xr!*'.mp4' -xr!*'.avi' -xr!*'.wmv' -xr!*'.mov' -xr!*'.qt' -xr!*'.flv' -xr!*'.swd' `
     -xr!*'.avchd' -xr!*'.rpt' -xr!*'.xls' -xr!*'.xlsx' -xr!*'.doc' -xr!*'.docx' -xr!*'.tif' -xr!*'.tiff' -xr!*'.bmp' -xr!*'.jpg' -xr!*'.jpeg' -xr!*'.gif' <#-xr!*'.png'#> `
     -xr!*'.eps' -xr!*'.raw' -xr!*'.cr2' -xr!*'.nef' -xr!*'.ord' -xr!*'.sr2'-xr!*'.svg'-xr!*'.heic' -xr!*'.ai' -xr!*'.pdf' -xr!*'.webp' -xr!*'.bmp' -xr!*'.dib' -xr!*'.heif' `
     -xr!*'.jp2' -xr!*'.j2k' -xr!*'.jpf' -xr!*'.jpx' -xr!*'.jpm' -xr!*'.mj2' -xr!*'.svgz' -xr!*'.pcm' -xr!*'.wav' -xr!*'.aiff' -xr!*'.mp3' -xr!*'.aac' -xr!*'.ogg' -xr!*'.wma' `
     -xr!*'.flac' -xr!*'.alac' -xr!*'.rpt' -xr!*'.csv' -xr!*'.odt' -xr!*'.ods' -xr!*'.ppt' -xr!*'.pptx' <# -xr!*'.txt' #> -xr!*'.xsd' -xr!*'.xsd' -xr!edi -xr!packages -xr!'Utility.Tests' `
     -xr!'Web.Integration.Tests' -xr!angular_elements -xr!'Database DLM' -xr!'Data Warehouse'
    cd $origPath
}

function global:Zip {
    param (
        [Parameter(Mandatory)][string]$source,
        [Parameter(Mandatory)][string]$dest
    )
    Compress-Archive $source $dest -Force
}

function global:Unzip {
    param (
        [Parameter(Mandatory)]
        [string]
        $zipPath,

        [Parameter(Mandatory)]
        [string]
        $dest
    )
    7z x $zipPath -o"$dest"
    #Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
}

function global:SetEnvVar {
    param (
        [Parameter(Mandatory)]
        [string] $name,

        [Parameter(Mandatory)]
        [string] $val,
        
        [string]$type
    )
    if($type -match 'mach') {
        $type = 'machine'
    }
    else {
        $type = 'user'
    }
    [Environment]::SetEnvironmentVariable($name,$val,$type)
}

function SetEnvironmentVars {
    $env:CDK_NEW_BOOTSTRAP=1
    $env:CODEBUILD_SRC_DIR="$proj_home/cdk"
}

function global:SetProxyEnvironmentVars {
    param (
        [string]$scope
    )
    if ($scope -eq $null -or $scope -eq 'local') {
        $env:HTTP_PROXY=$proxy_url_authenticated
        $env:HTTPS_PROXY=$proxy_url_authenticated
    }
    if ($scope -eq $null -or $scope -eq 'global') {
        [Environment]::SetEnvironmentVariable("HTTP_PROXY",$env:HTTP_PROXY,"User")
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY",$env:HTTPS_PROXY,"User")
    }
    "Set Proxy Environment Vars"
}

function global:RemoveProxyEnvironmentVars {
    param (
        [string]$scope
    )
    if ($scope -eq $null -or $scope -eq 'local') {
        $env:HTTP_PROXY=$null
        $env:HTTPS_PROXY=$null
    }
    if ($scope -eq $null -or $scope -eq 'global') {
        [Environment]::SetEnvironmentVariable("HTTP_PROXY",$env:HTTP_PROXY,"User")
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY",$env:HTTPS_PROXY,"User")
    }
    "Removed Proxy Environment Vars"
}

function global:Intellij {
    ."~\AppData\Local\JetBrains\Toolbox\apps\IDEA-U\ch-0\202.7660.26\bin\idea64.exe"
}

function global:PyCharm {
    ."~\AppData\Local\JetBrains\Toolbox\apps\PyCharm-P\ch-0\202.7660.27\bin\pycharm64.exe"
}

function global:Rider {
    ."~\AppData\Local\JetBrains\Toolbox\apps\Rider\ch-0\203.5981.141\bin\rider64.exe"
}

function global:RiderNoProx {
    RemoveProxyEnvironmentVars
    ."~\AppData\Local\JetBrains\Toolbox\apps\Rider\ch-0\203.6682.21\bin\rider64.exe"
    SetProxyEnvironmentVars
}

function global:RefreshProfile {
    $curr = pwd
    ."$pwsh_profile"
    Init
    cd $curr
}

function global:GetAliasFormatted {
    Get-Alias | Sort-Object Source | Format-Table -View source
}

function global:GetMyAliasFormatted {
    Get-MyAlias | Sort-Object Source | Format-Table -View source
}

function global:Get-Certificates {
    Param(
        $Computer = $env:COMPUTERNAME,
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation,
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName
    )

    $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$computer\$StoreName",$StoreLocation)
    $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly")
    $Store.Certificates
}

function global:Activate {
    if (Test-Path '.env') {
        .\.env\Scripts\activate
    }
    elseif (Test-Path 'env') {
        .\env\Scripts\activate
    }
    elseif (Test-Path 'venv') {
        .\venv\Scripts\activate
    }
    elseif (Test-Path '.venv') {
        .\venv\Scripts\activate
    }
}

function global:CreateVirtualEnv {
    "Removing .env if exists"
    rmrf .env 
    "Creating new .env"
    py -m venv .env
    "Activated"
    Activate
    "Upgrading pip package installer if applicable"
    py -m pip install --upgrade pip
    "Installing requirements.txt if present"
    if (Test-Path requirements.txt) {
        pip install -r requirements.txt
    }
    "Finished"
}

function global:PackageRequirementsTxt {
    param (
        [string]
        [Parameter(Mandatory)]
        $package_type
    )
    
    if ($package_type -inotin 'l','f','layer','function') {
        $package_type
        "Invalid input - indicate 'layer' (or 'l') or 'function' (or 'f') for package_type" 
        return
    }
    else {
        if ($package_type -in 'f','function' ) {
            $packageDir=".package"
            $zipDir="$packageDir/*"
            $package_type="LambdaFunction"
        }
        else {
            $packageDir=".package/python" 
            $zipDir=$packageDir
            $package_type="LambdaLayer"
        }
    }
    
    if(Test-Path .package) { Remove-Item .package -Force -Recurse } # clear dependencies incase we updated the requirements.txt file
    "Installing $package_type's requirements.txt dependencies into $packageDir"
    pip install -qqq -r requirements.txt -t $packageDir # installs the requirements.txt dependencies inside the .package dir | -qqq to reduce cmd output, remove if desired
    
    "Copying /app and requirements.txt into $packageDir"
    Copy-Item requirements.txt $packageDir -Force # copy requirements.txt file into .package/python dir
    if($package_type -eq 'LambdaFunction') { Copy-Item app $packageDir -Recurse -Force } # copy app folder into .package/python dir
    
    "Creating python.zip from $packageDir"
    Compress-Archive $zipDir python.zip -Force # zips the contents of .package into a package.zip | -Force will overwrite any current package.zip file
    
    "Removing .package directory"
    if(Test-Path .package) { Remove-Item .package -Force -Recurse } # clean up the .packages folder as it's not needed any longer
    
    "Finished packaging $package_type"
}

function global:OpenExplorer {
    param (
        [Parameter(Mandatory)]
        [string]
        $path
    )
    $path = ToLinuxPath $path
    explorer $path.TrimEnd("/")
}

function global:GetLockingProcess {
    param (
        [Parameter(Mandatory)]
        [string]
        $fileOrPath
    )

    $lockingProcess = CMD /C "openfiles /query /fo table | find /I ""$fileOrPath"""
    Write-Host $lockingProcess
}

function global:NpmRun {
    param (
        [Parameter(Mandatory)]
        [string]
        $scriptName
    )
    npm run $scriptName
}

function global:GetCustomAliases {
    param (
        [char]
        $sortBy
    )
    $sortBy
    if ($sortBy -eq "v") { $prop = "value" }
    else { $prop = "key" }

    $alias_map.GetEnumerator() | Sort-Object -Property $prop 
}

function global:ClearPipCache {
    rmrf "C:\Users\a800689\AppData\Local\pip\cache"
}

function global:ClearPipEnvCache {
    rmrf "C:\Users\a800689\AppData\Local\pipenv\pipenv\cache"
}

function global:NotepadPlus {
    param (
        [Parameter(Mandatory)]
        [string]
        $filePath
    )
    $origDir = pwd
    $filePath = ($filePath -replace "\\","/")
    $dirs = $filePath.split("/")
    if ($dirs.length -eq 1) {
        $file = $dirs[0];
    }
    else {
        $file = $dirs[$dirs.lenght - 1]
        $dirs[$dirs.lenght - 1] = ""
        cd ($dirs -join "/")
    }

    start notepad++ "$file"
    cd $origDir
}

function global:KeepAwake {
    $keepAwakeJob = (Get-Job | where { $_.Name -match 'KeepAwakeJob' })
    if ($keepAwakeJob) {
        Remove-Job -Name KeepAwakeJob -Force
    }

    Start-ThreadJob -Name KeepAwakeJob -ScriptBlock {
        while (1) {
            $wsh = New-Object -ComObject WScript.Shell
            $wsh.SendKeys('+{F15}')
            Start-Sleep -seconds 59
        }
    }
}

function global:CreateCustomAliases {
    $global:alias_map = @{
        "rmrf"="RemoveItem"
        "refp"="RefreshProfile"
        "cpjar"="CopyNeo4jJar"
        "bcdk"="BuildCdk"
        "ccdk"="CleanCdk"
        "gapsr"="Get-PSReadLineKeyHandler"
        "gaf"="GetAliasFormatted"
        "gmaf"="GetMyAliasFormatted"
        "gca"="GetCustomAliases"
        "npmr"="NpmRun"
        "tfg"="TfGet"
        "tfrp"="TfPromote"
        "tfrc"="TfClean"
        "prt"="PackageRequirementsTxt"
        "cve"="CreateVirtualEnv"
        "czip"="CleanAndZip"
        "npp"="NotepadPlus"
        "cgd"="CreateGitDiff"
        "sprox"="SetProxyEnvironmentVars"
        "rprox"="RemoveProxyEnvironmentVars"
        "git-sw"="GitSwitch"
        "git-ff"="GitFastForward"
        "git-ps"="GitPushAll"
        "oe"="OpenExplorer"
        "gfp"="GetFilePath"
        "rgoa"="RunGoAlgo"
    }

    foreach ($key in $alias_map.keys) {
        set-alias $key $alias_map.$key -Scope Script
    }
}

function global:Init {
    $origPath = $pwd
    global:SetVars
    CreateCustomAliases

    if ($comp_name -match "800689") {
        SetWebProxyCredentials
    }

    if (Test-Path $vs_dev_ps1) {
        ."$vs_dev_ps1"
    }
    if ($origPath -match "$proj_folder") { cd $origPath }
    else { cd $proj_home }

    cls
}
