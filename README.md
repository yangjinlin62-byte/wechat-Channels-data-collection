# 微信视频号数据采集

一个面向 Codex、WorkBuddy 等智能体使用的微信视频号账号数据采集技能。  
目标是用一条指令完成：账号作品采集、视频下载、视频解密、文案转写、Excel 回填和最终表格导出。

本仓库当前包含一个 Codex Skill：

```text
skills/wechat-channels-native-pipeline/
```

## 能做什么

完整流程：

1. 搜索并确认微信视频号账号。
2. 采集账号下全部可翻页作品。
3. 下载微信视频号加密视频。
4. 使用视频解密 key 解密为可播放视频。
5. 从视频提取音频。
6. 使用技能内置 ASR 适配器转写视频文案。
7. 回填 Excel。
8. 导出最终 xlsx 工作表。
9. 默认删除加密视频和中间音频，询问是否删除解密后视频。

最终输出字段固定为：

| 顺序 | 字段 |
| --- | --- |
| 1 | 达人昵称 |
| 2 | 视频描述 |
| 3 | 视频文案 |
| 4 | 点赞量 |
| 5 | 收藏量 |
| 6 | 评论量 |
| 7 | 分享量 |
| 8 | 发布时间 |

最终文件命名格式：

```text
账号名称-视频号账号数据.xlsx
```

## 项目特点

- Windows + PowerShell 优先。
- 不依赖本机 AsrTools 软件目录。
- 内置 B/J/K 三路 ASR fallback，默认并发 2。
- 解密工具自动安装到本机工具目录，不把第三方工具源码直接塞进技能。
- API Key 由用户自行申请和配置，不写入仓库。
- 面向智能体调用，脚本化、可自检、可重复执行。

## 目录结构

```text
.
├─ README.md
└─ skills/
   └─ wechat-channels-native-pipeline/
      ├─ SKILL.md
      ├─ agents/
      │  └─ openai.yaml
      ├─ references/
      │  ├─ asr-fallback.md
      │  ├─ setup.md
      │  └─ worldtreetech-api.md
      └─ scripts/
         ├─ install.ps1
         ├─ native_asr.py
         ├─ requirements.txt
         ├─ wechat-channels.ps1
         └─ wechat_channels_cli.py
```

## 前置要求

本项目当前只面向 Windows 环境：

- Windows 10/11
- PowerShell
- Python 3.10+
- Git for Windows
- Node.js 18+
- ffmpeg
- Codex 或其他能读取本地 Skill 的智能体环境

安装脚本会尽量自动准备 Python 依赖、解密工具依赖和 ffmpeg 检测。

## API Key

采集数据依赖 WorldTreeTech API。

官网：

```text
https://www.worldtreetech.cn/
```

接口文档：

```text
https://www.worldtreetech.cn/api-docs
```

注册后，将自己的 API Key 配置到本机环境变量：

```powershell
[Environment]::SetEnvironmentVariable("WORLDTREE_API_KEY", "你的API Key", "User")
```

重新打开 PowerShell 后可检查：

```powershell
$env:WORLDTREE_API_KEY
```

不要把真实 API Key 提交到 GitHub。

## 安装技能

先克隆仓库：

```powershell
git clone https://github.com/yangjinlin62-byte/wechat-Channels-data-collection.git
cd wechat-Channels-data-collection
```

把技能复制到 Codex skills 目录：

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.codex\skills" | Out-Null
Copy-Item -Recurse -Force ".\skills\wechat-channels-native-pipeline" "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline"
```

运行安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\install.ps1"
```

安装脚本会：

- 创建本地 Python 虚拟环境。
- 安装 `openpyxl` 和 `requests`。
- 克隆并安装视频号解密服务依赖。
- 检查或配置 `ffmpeg`。
- 提醒用户自行配置 WorldTreeTech API Key。

## 自检

安装后运行：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --doctor
```

正常情况下会看到：

```text
[OK] Python
[OK] openpyxl
[OK] requests
[OK] ffmpeg
[OK] git
[OK] node
[OK] npm
[OK] decrypt tool
```

如果 API Key 未配置，会显示提示：

```text
[WARN] WorldTreeTech key: missing
```

这不是安装失败，只表示还不能开始采集。

## 使用示例

采集某个视频号账号的完整数据：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --full-pipeline --account "央姐来了" --output-dir "F:\视频号数据采集"
```

列出账号搜索候选项：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --account "央姐来了" --list-accounts
```

检查 WorldTreeTech 余额：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --check-balance
```

只对已有工作簿做视频文案转写回填：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --transcribe-from-xlsx "F:\视频号数据采集\央姐来了-视频号账号数据.xlsx" --asr-concurrency 2
```

如果更看重速度，可以将并发改为 3：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\wechat-channels-native-pipeline\scripts\wechat-channels.ps1" --transcribe-from-xlsx "F:\视频号数据采集\央姐来了-视频号账号数据.xlsx" --asr-concurrency 3
```

默认建议使用并发 2，稳定性更好。

## 智能体调用示例

对 Codex 或 WorkBuddy，可以这样描述任务：

```text
使用 wechat-channels-native-pipeline 技能，采集视频号账号“央姐来了”，执行完整流程，输出最终 xlsx 到 F:\视频号数据采集。
```

或更简短：

```text
用视频号原生采集技能采集：央姐来了
```

智能体应按技能说明执行：

```text
采集 -> 下载 -> 解密 -> 转写 -> 回填 -> 导出最终 xlsx -> 清理中间文件 -> 询问是否删除解密后视频
```

## ASR 转写说明

本技能不依赖 AsrTools 本体。  
它内置了轻量 ASR 适配器：

| 引擎 | 用途 |
| --- | --- |
| B | 默认优先 |
| J | 第一 fallback |
| K | 第二 fallback |

默认顺序：

```text
B -> J -> K
```

如果某条视频转写失败，流程会继续处理后续视频；失败行的 `视频文案` 会留空。

需要注意：这些 ASR 接口不是官方长期稳定接口，可能受到限流、接口变更、网络波动影响。本项目通过 fallback、并发控制和失败不中断来提高可用性，但不承诺永久稳定。

## 视频解密说明

微信视频号视频 URL 通常是加密视频地址。  
采集数据中需要同时保留：

```text
视频URL
视频解密key
```

技能会在中间工作簿中使用这些字段完成下载和解密。最终交付给用户的 xlsx 不保留这两个内部字段。

解密能力基于：

```text
https://github.com/Evil0ctal/WeChat-Channels-Video-File-Decryption
```

安装脚本会自动拉取并安装其本地 API 服务依赖。

## 常见问题

### 仓库里为什么没有 API Key？

API Key 属于个人敏感信息，不能提交到公开仓库。请用户自行注册 WorldTreeTech 后配置本机环境变量。

### 为什么不直接打包 AsrTools？

AsrTools 是本地 GUI 软件，不适合直接作为 Skill 的硬依赖。这个技能把可用转写逻辑抽成了内置模块，便于 Codex、WorkBuddy 等智能体一条命令安装和调用。

### 为什么默认并发是 2？

实测中并发 2 稳定性更好；并发 3 速度更快，但更容易遇到单条失败或接口波动。用户可以根据任务要求自行调整。

### 采集范围是什么？

默认采集“全部可翻页作品”。如需限制数量，可使用：

```powershell
--max-videos 10
```

或限制页数：

```powershell
--max-pages 1
```

## 安全与合规

请只采集你有权处理的数据，并遵守目标平台、接口服务商以及所在地法律法规的要求。  
本项目不提供规避权限、绕过访问控制或滥用接口的用途支持。

## 相关链接

- WorldTreeTech 官网：https://www.worldtreetech.cn/
- WorldTreeTech API 文档：https://www.worldtreetech.cn/api-docs
- WorldTreeTech 示例仓库：https://github.com/worldtreetech/wechat-api
- 视频解密工具：https://github.com/Evil0ctal/WeChat-Channels-Video-File-Decryption
