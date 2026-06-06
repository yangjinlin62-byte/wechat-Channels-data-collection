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

The installer:

- Creates `%USERPROFILE%\.codex\tools\wechat-channels-native-pipeline\.venv`.
- Installs `openpyxl` and `requests`.
- Clones and installs `Evil0ctal/WeChat-Channels-Video-File-Decryption`.
- Sets `WECHAT_CHANNELS_NATIVE_PYTHON`.
- Sets `FFMPEG_BIN` if ffmpeg is found.

## API Key

Do not store real API keys in the skill or repository. Ask users to register at https://www.worldtreetech.cn/ and set:

```powershell
[Environment]::SetEnvironmentVariable("WORLDTREE_API_KEY", "用户自己的API Key", "User")
```

The CLI also accepts `--key`, but environment variables are preferred.

## Decrypt Service

The collector starts the local decrypt service when needed. If port `3000` is already occupied, either stop the existing process or run with another `--decrypt-api-url` only if the decrypt tool is configured for that port.
