# WorldTreeTech API Reference

Official site: https://www.worldtreetech.cn/

The skill uses the existing WorldTreeTech WeChat Channels endpoints through `scripts/wechat_channels_cli.py`.

## Environment

Preferred API key variables:

- `WORLDTREE_API_KEY`
- `WORLD_TREE_API_KEY`

Never hardcode keys in skill files or committed examples.

## Endpoints

Base URL:

```text
https://www.worldtreetech.cn
```

Current script endpoints:

- `/api/v2/wechat/video/search`
- `/api/v2/wechat/video/getUserInfo`
- `/api/v2/user/balance`

## Internal Workbook Fields

Intermediate workbooks may include:

- `达人昵称`
- `视频描述`
- `点赞量`
- `收藏量`
- `评论量`
- `分享量`
- `发布时间`
- `视频URL`
- `视频解密key`
- `视频文案`

Final workbooks must include only:

- `达人昵称`
- `视频描述`
- `视频文案`
- `点赞量`
- `收藏量`
- `评论量`
- `分享量`
- `发布时间`
