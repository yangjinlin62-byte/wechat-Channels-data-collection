param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = "Stop"

$Python = $env:WECHAT_CHANNELS_NATIVE_PYTHON
if (-not $Python -or -not (Test-Path -LiteralPath $Python)) {
    $Candidate = Join-Path $env:USERPROFILE ".codex\tools\wechat-channels-native-pipeline\.venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $Candidate) {
        $Python = $Candidate
    }
}

if (-not $Python -or -not (Test-Path -LiteralPath $Python)) {
    throw "Native skill Python environment not found. Run scripts\install.ps1 first."
}

$Script = Join-Path $PSScriptRoot "wechat_channels_cli.py"
& $Python $Script @CliArgs
exit $LASTEXITCODE
