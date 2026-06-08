---
name: wechat-channels-native-pipeline
description: Collect WeChat Channels account works on Windows through WorldTreeTech, download encrypted videos, decrypt them, transcribe with built-in native ASR adapters instead of AsrTools, and export final xlsx data. Use when Codex or WorkBuddy needs a one-command installed 微信视频号采集-解密-转写-回填 workflow without relying on the local AsrTools software directory.
---

# WeChat Channels Native Pipeline

## Scope

Use this skill for Windows-only WeChat Channels account collection workflows that need:

1. WorldTreeTech account search and all-page work collection.
2. Encrypted video download.
3. Video decryption with each row's `decode_key`.
4. Audio extraction with `ffmpeg`.
5. Transcript generation through built-in native ASR adapters.
6. Final xlsx export.

This skill is intentionally independent from `wechat-video-account-collector`. Do not edit or rely on that older skill when using this one.

## First-Time Setup

When this skill has just been downloaded or `--doctor` reports missing dependencies, run the installer first. The installer must initialize the environment and then ask the user for a WorldTreeTech API key.

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\install.ps1"
```

For WorkBuddy installs, use the same script under `.workbuddy`:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\wechat-channels-native-pipeline\scripts\install.ps1"
```

The installer detects whether the skill is under `.codex` or `.workbuddy`, creates the matching tools directory, installs Python dependencies, installs the decrypt service dependency, checks `ffmpeg`, and prompts for the API key.

WorldTreeTech API keys are not bundled. The installer shows https://www.worldtreetech.cn/ and asks the user to paste their own key. For non-interactive setup, pass:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\wechat-channels-native-pipeline\scripts\install.ps1" -ApiKey "用户自己的API Key"
```

Never hardcode or commit real API keys.

## Default Workflow

When the user asks to collect an account with this skill, run the full pipeline unless they explicitly request a partial step:

If `WORLDTREE_API_KEY` or the native tools environment is missing, run `scripts/install.ps1` first and let it ask the user for the API key.

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --full-pipeline --account "账号名称" --output-dir "F:\视频号数据采集"
```

Defaults:

- Collect all available paginated works.
- Use ASR engine `B` first, then fallback to `J`, then `K` per failed item.
- Use `--asr-concurrency 2` by default.
- Users may set `--asr-concurrency 3` when they prefer speed and accept higher failure risk.
- Delete encrypted videos by default after successful decryption.
- Delete extracted audio files by default after transcription.
- Keep decrypted playable videos and ask before deleting them.

After a successful full pipeline, ask exactly:

`是否删除解密后的视频文件？`

Do not delete decrypted playable videos unless the user explicitly says yes.

## Final Workbook

The final workbook must contain only these columns, in this order:

1. `达人昵称`
2. `视频描述`
3. `视频文案`
4. `点赞量`
5. `收藏量`
6. `评论量`
7. `分享量`
8. `发布时间`

Internal fields such as `视频URL` and `视频解密key` are allowed only in intermediate workbooks.

## Commands

List account candidates:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --account "账号名称" --list-accounts
```

Check WorldTreeTech balance:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --check-balance
```

Check installation health:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --doctor
```

Run transcription from an existing workbook:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\10725\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --transcribe-from-xlsx "F:\视频号数据采集\账号名称-视频号账号数据.xlsx" --asr-concurrency 2
```

## Reliability Rules

- If account search returns multiple plausible candidates, show candidates and ask the user to choose.
- If one ASR item fails, continue the batch and leave that row's `视频文案` blank.
- Write transcript `.txt` files first, then write Excel in one single-threaded pass.
- If the final workbook is open in Excel/WPS and cannot be overwritten, save a sibling workbook and tell the user.
- If decryption fails before all rows are done, keep encrypted videos for retry.
- Do not hardcode API keys in skill files, scripts, docs, examples, logs, or workbooks.

## References

- Read `references/setup.md` when installation, API key setup, or external dependencies are involved.
- Read `references/asr-fallback.md` when debugging transcription or changing fallback behavior.
- Read `references/worldtreetech-api.md` when endpoint details, parameters, or response fields are needed.
