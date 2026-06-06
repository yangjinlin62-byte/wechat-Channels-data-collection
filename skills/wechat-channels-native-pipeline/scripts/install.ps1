param(
    [string]$ToolsDir = "$env:USERPROFILE\.codex\tools\wechat-channels-native-pipeline"
)

$ErrorActionPreference = "Stop"

function Find-CommandPath {
    param([string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    return $null
}

function Test-PythonPath {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    try {
        & $Path -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

$SkillDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ScriptsDir = Join-Path $SkillDir "scripts"
$VenvDir = Join-Path $ToolsDir ".venv"
$DecryptDir = Join-Path $ToolsDir "WeChat-Channels-Video-File-Decryption"
$DecryptServiceDir = Join-Path $DecryptDir "api-service"

$PythonCandidates = @(
    "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe",
    (Find-CommandPath @("python")),
    (Find-CommandPath @("py"))
)

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

$Python = $null
foreach ($candidate in $PythonCandidates) {
    if (Test-PythonPath $candidate) {
        $Python = $candidate
        break
    }
}
if (-not $Python) {
    throw "Python 3.10+ was not found. Install Python 3.10+ first, then rerun this script."
}

if (-not (Test-Path -LiteralPath (Join-Path $VenvDir "Scripts\python.exe"))) {
    & $Python -m venv $VenvDir
}

$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r (Join-Path $ScriptsDir "requirements.txt")

[Environment]::SetEnvironmentVariable("WECHAT_CHANNELS_NATIVE_PYTHON", $VenvPython, "User")
$env:WECHAT_CHANNELS_NATIVE_PYTHON = $VenvPython

$Git = Find-CommandPath @("git")
if (-not $Git) {
    throw "Git was not found. Install Git for Windows, then rerun this script."
}

$Node = Find-CommandPath @("node")
$Npm = Find-CommandPath @("npm.cmd", "npm")
if (-not $Node -or -not $Npm) {
    throw "Node.js/npm was not found. Install Node.js 18+, then rerun this script."
}

if (-not (Test-Path -LiteralPath (Join-Path $DecryptDir ".git"))) {
    & $Git clone --depth 1 "https://github.com/Evil0ctal/WeChat-Channels-Video-File-Decryption.git" $DecryptDir
}

if (-not (Test-Path -LiteralPath (Join-Path $DecryptServiceDir "package.json"))) {
    throw "Decrypt API service package.json was not found under $DecryptServiceDir."
}

& $Npm install --prefix $DecryptServiceDir

$Ffmpeg = Find-CommandPath @("ffmpeg.exe", "ffmpeg")
if (-not $Ffmpeg) {
    $Winget = Find-CommandPath @("winget")
    if ($Winget) {
        Write-Host "ffmpeg was not found. Trying winget install..."
        & $Winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
        $Ffmpeg = Find-CommandPath @("ffmpeg.exe", "ffmpeg")
    }
}

if (-not $Ffmpeg) {
    Write-Warning "ffmpeg was not found. Install ffmpeg or set FFMPEG_BIN to the full ffmpeg.exe path before transcription."
} else {
    [Environment]::SetEnvironmentVariable("FFMPEG_BIN", $Ffmpeg, "User")
    $env:FFMPEG_BIN = $Ffmpeg
}

$Wrapper = Join-Path $ScriptsDir "wechat-channels.ps1"
Write-Host ""
Write-Host "Install complete."
Write-Host "WorldTreeTech API key is not bundled. Register at https://www.worldtreetech.cn/ and set WORLDTREE_API_KEY."
Write-Host "Run example:"
Write-Host ('  powershell -ExecutionPolicy Bypass -File "' + $Wrapper + '" --full-pipeline --account "ACCOUNT_NAME" --output-dir "F:\video-data"')
