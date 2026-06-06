# Native ASR Fallback Reference

The skill does not import or execute AsrTools. It uses `scripts/native_asr.py`.

## Engines

- `B`: Bcut/Bilibili-style upload-task-poll flow. Default first choice.
- `J`: JianYing/LV-style upload-sign-submit-query flow. Used as fallback.
- `K`: KuaiShou subtitle endpoint. Used as final fallback.

## Defaults

- Preferred engine: `B`.
- Per-item fallback order when preferred engine is `B`: `B -> J -> K`.
- Default concurrency: `2`.
- User-adjustable concurrency: `--asr-concurrency 3`.

## Stability Notes

These ASR endpoints are not official public contracts. Treat failures as normal operational events:

- Continue the batch when one item fails.
- Leave `视频文案` blank for failed rows.
- Keep transcript `.txt` files for successful rows.
- Write Excel after the parallel batch finishes.

Do not add official ASR providers or local Whisper to this skill unless the user explicitly changes the requirement.
