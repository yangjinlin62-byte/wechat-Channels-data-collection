param(
    [string]$ToolsDir = "",
    [string]$ApiKey = "",
    [switch]$SkipApiKeyPrompt
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

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name
    )
    $winget = Find-CommandPath @("winget")
    if (-not $winget) {
        Write-Warning "$Name was not found and winget is unavailable. Please install $Name manually."
        return
    }
    Write-Host "$Name was not found. Trying winget install..."
    & $winget install --id $PackageId -e --accept-package-agreements --accept-source-agreements
}

function Download-DecryptToolZip {
    param(
        [string]$Destination
    )
    $zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "wechat-channels-video-decrypt.zip"
    $extractRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-channels-video-decrypt-" + [guid]::NewGuid().ToString("N"))
    Invoke-WebRequest -Uri "https://github.com/Evil0ctal/WeChat-Channels-Video-File-Decryption/archive/refs/heads/main.zip" -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $source = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
    if (-not $source) {
        throw "Failed to extract decrypt tool zip."
    }
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Move-Item -LiteralPath $source.FullName -Destination $Destination
}

$SkillDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ScriptsDir = Join-Path $SkillDir "scripts"

if (-not $ToolsDir) {
    $codexSkillRoot = Join-Path $env:USERPROFILE ".codex\skills"
    $workbuddySkillRoot = Join-Path $env:USERPROFILE ".workbuddy\skills"
    if ($SkillDir.StartsWith($workbuddySkillRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $ToolsDir = Join-Path $env:USERPROFILE ".workbuddy\tools\wechat-channels-native-pipeline"
    } elseif ($SkillDir.StartsWith($codexSkillRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $ToolsDir = Join-Path $env:USERPROFILE ".codex\tools\wechat-channels-native-pipeline"
    } else {
        $ToolsDir = Join-Path $env:LOCALAPPDATA "wechat-channels-native-pipeline"
    }
}

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
    Install-WingetPackage -PackageId "Python.Python.3.12" -Name "Python 3.12"
    $PythonCandidates = @(
        (Find-CommandPath @("python")),
        (Find-CommandPath @("py")),
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:ProgramFiles\Python312\python.exe"
    )
    foreach ($candidate in $PythonCandidates) {
        if (Test-PythonPath $candidate) {
            $Python = $candidate
            break
        }
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
[Environment]::SetEnvironmentVariable("WECHAT_CHANNELS_NATIVE_TOOLS_DIR", $ToolsDir, "User")
$env:WECHAT_CHANNELS_NATIVE_TOOLS_DIR = $ToolsDir

$Git = Find-CommandPath @("git")
if (-not $Git) {
    Install-WingetPackage -PackageId "Git.Git" -Name "Git for Windows"
    $Git = Find-CommandPath @("git")
}

$Node = Find-CommandPath @("node")
$Npm = Find-CommandPath @("npm.cmd", "npm")
if (-not $Node -or -not $Npm) {
    Install-WingetPackage -PackageId "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
    $Node = Find-CommandPath @("node")
    $Npm = Find-CommandPath @("npm.cmd", "npm")
}
if (-not $Node -or -not $Npm) {
    throw "Node.js/npm was not found. Install Node.js 18+, then rerun this script."
}

if (-not (Test-Path -LiteralPath (Join-Path $DecryptServiceDir "package.json"))) {
    if (Test-Path -LiteralPath $DecryptDir) {
        Remove-Item -LiteralPath $DecryptDir -Recurse -Force
    }
    if ($Git) {
        & $Git clone --depth 1 "https://github.com/Evil0ctal/WeChat-Channels-Video-File-Decryption.git" $DecryptDir
    } else {
        Download-DecryptToolZip -Destination $DecryptDir
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $DecryptServiceDir "package.json"))) {
    throw "Decrypt API service package.json was not found under $DecryptServiceDir."
}

& $Npm install --prefix $DecryptServiceDir

$Ffmpeg = Find-CommandPath @("ffmpeg.exe", "ffmpeg")
if (-not $Ffmpeg) {
    Install-WingetPackage -PackageId "Gyan.FFmpeg" -Name "ffmpeg"
    $Ffmpeg = Find-CommandPath @("ffmpeg.exe", "ffmpeg")
}

if (-not $Ffmpeg) {
    Write-Warning "ffmpeg was not found. Install ffmpeg or set FFMPEG_BIN to the full ffmpeg.exe path before transcription."
} else {
    [Environment]::SetEnvironmentVariable("FFMPEG_BIN", $Ffmpeg, "User")
    $env:FFMPEG_BIN = $Ffmpeg
}

if ($ApiKey) {
    [Environment]::SetEnvironmentVariable("WORLDTREE_API_KEY", $ApiKey, "User")
    $env:WORLDTREE_API_KEY = $ApiKey
} elseif (-not $SkipApiKeyPrompt) {
    $existingKey = [Environment]::GetEnvironmentVariable("WORLDTREE_API_KEY", "User")
    if ($existingKey) {
        $env:WORLDTREE_API_KEY = $existingKey
        Write-Host "WorldTreeTech API key already exists in user environment."
    } else {
        Write-Host ""
        Write-Host "WorldTreeTech API key is required for collection."
        Write-Host "Register and get your key at: https://www.worldtreetech.cn/"
        $typedKey = Read-Host "Paste your WorldTreeTech API Key, or press Enter to set it later"
        if ($typedKey) {
            [Environment]::SetEnvironmentVariable("WORLDTREE_API_KEY", $typedKey, "User")
            $env:WORLDTREE_API_KEY = $typedKey
            Write-Host "WorldTreeTech API key saved to user environment."
        } else {
            Write-Warning "API key was not set. Run this installer again or set WORLDTREE_API_KEY before collection."
        }
    }
}

$Wrapper = Join-Path $ScriptsDir "wechat-channels.ps1"
Write-Host ""
Write-Host "Install complete."
Write-Host "Tools directory: $ToolsDir"
Write-Host "Run example:"
Write-Host ('  powershell -ExecutionPolicy Bypass -File "' + $Wrapper + '" --full-pipeline --account "ACCOUNT_NAME" --output-dir "F:\video-data"')
