# Setup Reference

## Requirements

- Windows + PowerShell.
- Python 3.10+ or the Codex bundled Python runtime.
- Git for Windows.
- Node.js 18+ with npm.
- ffmpeg in PATH, `FFMPEG_BIN`, or installed by `scripts/install.ps1`.
- WorldTreeTech API key from https://www.worldtreetech.cn/.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\install.ps1"
```

For WorkBuddy:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\wechat-channels-native-pipeline\scripts\install.ps1"
```

The installer:

- Detects whether the skill is installed under `.codex` or `.workbuddy`.
- Creates the matching tools directory and `.venv`.
- Installs `openpyxl` and `requests`.
- Clones and installs `Evil0ctal/WeChat-Channels-Video-File-Decryption`.
- Sets `WECHAT_CHANNELS_NATIVE_PYTHON`.
- Sets `WECHAT_CHANNELS_NATIVE_TOOLS_DIR`.
- Sets `FFMPEG_BIN` if ffmpeg is found.
- Prompts the user for `WORLDTREE_API_KEY` if it is not already set.

## API Key

Do not store real API keys in the skill or repository. The installer should ask the user to register at https://www.worldtreetech.cn/ and paste their key.

Manual fallback:

```powershell
[Environment]::SetEnvironmentVariable("WORLDTREE_API_KEY", "用户自己的API Key", "User")
```

The installer also accepts `-ApiKey "用户自己的API Key"` for non-interactive setup. The CLI accepts `--key`, but environment variables are preferred.

## Decrypt Service

The collector starts the local decrypt service when needed. If port `3000` is already occupied, either stop the existing process or run with another `--decrypt-api-url` only if the decrypt tool is configured for that port.
