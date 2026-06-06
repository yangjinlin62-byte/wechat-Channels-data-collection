#!/usr/bin/env python3
"""Native ASR adapters used by the WeChat Channels native pipeline skill.

These adapters intentionally avoid importing or executing AsrTools. They use
the same service families as the existing AsrTools workflow and provide
per-item fallback across engines.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import json
import os
import time
import uuid
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:  # pragma: no cover - reported at runtime by transcribe_audio_file.
    requests = None


class AsrError(RuntimeError):
    pass


@dataclass
class Segment:
    text: str
    start_time: int = 0
    end_time: int = 0


def _read_audio(audio_path: Path) -> tuple[bytes, str]:
    if not audio_path.exists():
        raise AsrError(f"Audio file not found: {audio_path}")
    data = audio_path.read_bytes()
    if not data:
        raise AsrError(f"Audio file is empty: {audio_path}")
    crc32_hex = format(zlib.crc32(data) & 0xFFFFFFFF, "08x")
    return data, crc32_hex


def _segments_to_text(segments: list[Segment]) -> str:
    return "\n".join(seg.text.strip() for seg in segments if seg.text and seg.text.strip()).strip()


def transcribe_audio_file(
    audio_path: Path,
    preferred_engine: str = "B",
    fallback_engines: tuple[str, ...] = ("B", "J", "K"),
    timeout: int = 60,
) -> tuple[str, str]:
    if requests is None:
        raise AsrError("Missing dependency: requests. Run scripts\\install.ps1 before transcription.")
    engines = [preferred_engine] + [item for item in fallback_engines if item != preferred_engine]
    last_error: Exception | None = None
    for engine in engines:
        try:
            if engine == "B":
                text = BcutNativeAsr(audio_path, timeout=timeout).run()
            elif engine == "J":
                text = JianYingNativeAsr(audio_path, timeout=timeout).run()
            elif engine == "K":
                text = KuaiShouNativeAsr(audio_path, timeout=timeout).run()
            else:
                raise AsrError(f"Unknown ASR engine: {engine}")
            if text:
                return text, engine
            raise AsrError(f"ASR engine {engine} returned empty text.")
        except Exception as exc:  # noqa: BLE001 - fallback must catch per-engine failures.
            last_error = exc
            print(f"ASR engine {engine} failed for {audio_path.name}: {exc}")
    raise AsrError(f"All ASR engines failed for {audio_path}") from last_error


class BcutNativeAsr:
    api_base = "https://member.bilibili.com/x/bcut/rubick-interface"
    headers = {
        "User-Agent": "Bilibili/1.0.0 (https://www.bilibili.com)",
        "Content-Type": "application/json",
    }

    def __init__(self, audio_path: Path, timeout: int = 60):
        self.audio_path = audio_path
        self.timeout = timeout
        self.audio_data, _ = _read_audio(audio_path)
        self.download_url: str | None = None
        self.task_id: str | None = None

    def run(self) -> str:
        self._upload()
        self._create_task()
        result = self._poll_result()
        utterances = result.get("utterances") or []
        return _segments_to_text(
            [Segment(str(item.get("transcript") or ""), item.get("start_time", 0), item.get("end_time", 0)) for item in utterances]
        )

    def _upload(self) -> None:
        payload = {
            "type": 2,
            "name": "audio.mp3",
            "size": len(self.audio_data),
            "ResourceFileType": "mp3",
            "model_id": "8",
        }
        create = requests.post(f"{self.api_base}/resource/create", data=json.dumps(payload), headers=self.headers, timeout=self.timeout)
        create.raise_for_status()
        data = create.json()["data"]
        upload_urls = data["upload_urls"]
        per_size = data["per_size"]
        etags: list[str] = []
        for index, url in enumerate(upload_urls):
            start = index * per_size
            end = (index + 1) * per_size
            upload = requests.put(url, data=self.audio_data[start:end], headers=self.headers, timeout=self.timeout)
            upload.raise_for_status()
            etags.append(upload.headers.get("Etag") or "")
        complete_payload = {
            "InBossKey": data["in_boss_key"],
            "ResourceId": data["resource_id"],
            "Etags": ",".join(etags),
            "UploadId": data["upload_id"],
            "model_id": "8",
        }
        complete = requests.post(
            f"{self.api_base}/resource/create/complete",
            data=json.dumps(complete_payload),
            headers=self.headers,
            timeout=self.timeout,
        )
        complete.raise_for_status()
        self.download_url = complete.json()["data"]["download_url"]

    def _create_task(self) -> None:
        response = requests.post(
            f"{self.api_base}/task",
            json={"resource": self.download_url, "model_id": "8"},
            headers=self.headers,
            timeout=self.timeout,
        )
        response.raise_for_status()
        self.task_id = response.json()["data"]["task_id"]

    def _poll_result(self) -> dict[str, Any]:
        for _ in range(500):
            response = requests.get(
                f"{self.api_base}/task/result",
                params={"model_id": 7, "task_id": self.task_id},
                headers=self.headers,
                timeout=self.timeout,
            )
            response.raise_for_status()
            data = response.json()["data"]
            if data.get("state") == 4:
                return json.loads(data["result"])
            time.sleep(1)
        raise AsrError("Bcut ASR timed out while polling result.")


class KuaiShouNativeAsr:
    def __init__(self, audio_path: Path, timeout: int = 60):
        self.audio_path = audio_path
        self.timeout = timeout
        self.audio_data, _ = _read_audio(audio_path)

    def run(self) -> str:
        files = [("file", ("audio.mp3", self.audio_data, "audio/mpeg"))]
        response = requests.post(
            "https://ai.kuaishou.com/api/effects/subtitle_generate",
            data={"typeId": "1"},
            files=files,
            timeout=self.timeout,
        )
        response.raise_for_status()
        payload = response.json()
        items = payload.get("data", {}).get("text") or []
        return _segments_to_text(
            [Segment(str(item.get("text") or ""), item.get("start_time", 0), item.get("end_time", 0)) for item in items]
        )


class JianYingNativeAsr:
    def __init__(self, audio_path: Path, timeout: int = 60):
        self.audio_path = audio_path
        self.timeout = timeout
        self.audio_data, self.crc32_hex = _read_audio(audio_path)
        self.tdid = "3943278516897751" if dt.datetime.now().year != 2024 else f"{uuid.getnode():012d}"
        self.session_token: str | None = None
        self.secret_key: str | None = None
        self.access_key: str | None = None
        self.store_uri: str | None = None
        self.auth: str | None = None
        self.upload_id: str | None = None
        self.session_key: str | None = None
        self.upload_hosts: str | None = None

    def run(self) -> str:
        self._upload()
        query_id = self._submit()
        response = self._query(query_id)
        utterances = response.get("data", {}).get("utterances") or []
        return _segments_to_text(
            [Segment(str(item.get("text") or ""), item.get("start_time", 0), item.get("end_time", 0)) for item in utterances]
        )

    def _generate_sign_parameters(self, url: str) -> tuple[str, str]:
        current_time = str(int(time.time()))
        payload = {"url": url, "current_time": current_time, "pf": "4", "appvr": "4.0.0", "tdid": self.tdid}
        response = requests.post("https://asrtools-update.bkfeng.top/sign", json=payload, timeout=self.timeout)
        response.raise_for_status()
        sign_value = response.json().get("sign")
        if not sign_value:
            raise AsrError("JianYing sign service returned no sign.")
        return str(sign_value).lower(), current_time

    def _headers(self, url: str) -> dict[str, str]:
        sign_value, device_time = self._generate_sign_parameters(url)
        return {
            "User-Agent": "Cronet/TTNetVersion:01594da2 2023-03-14 QuicVersion:46688bb4 2022-11-28",
            "appvr": "4.0.0",
            "device-time": device_time,
            "pf": "4",
            "sign": sign_value,
            "sign-ver": "1",
            "tdid": self.tdid,
        }

    def _upload_headers(self) -> dict[str, str]:
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Authorization": self.auth or "",
            "Content-CRC32": self.crc32_hex,
        }

    def _upload(self) -> None:
        self._upload_sign()
        self._upload_auth()
        self._upload_file()
        self._upload_check()
        self._upload_commit()

    def _upload_sign(self) -> None:
        response = requests.post(
            "https://lv-pc-api-sinfonlinec.ulikecam.com/lv/v1/upload_sign",
            data=json.dumps({"biz": "pc-recognition"}),
            headers=self._headers("/lv/v1/upload_sign"),
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()["data"]
        self.access_key = data["access_key_id"]
        self.secret_key = data["secret_access_key"]
        self.session_token = data["session_token"]

    def _upload_auth(self) -> None:
        file_size = len(self.audio_data)
        request_parameters = (
            f"Action=ApplyUploadInner&FileSize={file_size}&FileType=object&IsInner=1"
            "&SpaceName=lv-mac-recognition&Version=2020-11-19&s=5y0udbjapi"
        )
        timestamp = dt.datetime.utcnow()
        amz_date = timestamp.strftime("%Y%m%dT%H%M%SZ")
        headers = {"x-amz-date": amz_date, "x-amz-security-token": self.session_token or ""}
        signature = _aws_signature(self.secret_key or "", request_parameters, headers)
        datestamp = timestamp.strftime("%Y%m%d")
        headers["authorization"] = (
            f"AWS4-HMAC-SHA256 Credential={self.access_key}/{datestamp}/cn/vod/aws4_request, "
            f"SignedHeaders=x-amz-date;x-amz-security-token, Signature={signature}"
        )
        response = requests.get(f"https://vod.bytedanceapi.com/?{request_parameters}", headers=headers, timeout=self.timeout)
        response.raise_for_status()
        store_info = response.json()["Result"]["UploadAddress"]["StoreInfos"][0]
        upload_address = response.json()["Result"]["UploadAddress"]
        self.store_uri = store_info["StoreUri"]
        self.auth = store_info["Auth"]
        self.upload_id = store_info["UploadID"]
        self.session_key = upload_address["SessionKey"]
        self.upload_hosts = upload_address["UploadHosts"][0]

    def _upload_file(self) -> None:
        url = f"https://{self.upload_hosts}/{self.store_uri}?partNumber=1&uploadID={self.upload_id}"
        response = requests.put(url, data=self.audio_data, headers=self._upload_headers(), timeout=self.timeout)
        response.raise_for_status()
        if response.json().get("success") != 0:
            raise AsrError(f"JianYing upload failed: {response.text}")

    def _upload_check(self) -> None:
        url = f"https://{self.upload_hosts}/{self.store_uri}?uploadID={self.upload_id}"
        response = requests.post(url, data=f"1:{self.crc32_hex}", headers=self._upload_headers(), timeout=self.timeout)
        response.raise_for_status()

    def _upload_commit(self) -> None:
        url = f"https://{self.upload_hosts}/{self.store_uri}?uploadID={self.upload_id}&partNumber=1&x-amz-security-token={self.session_token}"
        response = requests.put(url, data=self.audio_data, headers=self._upload_headers(), timeout=self.timeout)
        response.raise_for_status()

    def _submit(self) -> str:
        payload = {
            "adjust_endtime": 200,
            "audio": self.store_uri,
            "caption_type": 2,
            "client_request_id": "45faf98c-160f-4fae-a649-6d89b0fe35be",
            "max_lines": 1,
            "songs_info": [{"end_time": 6000, "id": "", "start_time": 0}],
            "words_per_line": 16,
        }
        response = requests.post(
            "https://lv-pc-api-sinfonlinec.ulikecam.com/lv/v1/audio_subtitle/submit",
            json=payload,
            headers=self._headers("/lv/v1/audio_subtitle/submit"),
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()["data"]["id"]

    def _query(self, query_id: str) -> dict[str, Any]:
        response = requests.post(
            "https://lv-pc-api-sinfonlinec.ulikecam.com/lv/v1/audio_subtitle/query",
            json={"id": query_id, "pack_options": {"need_attribute": True}},
            headers=self._headers("/lv/v1/audio_subtitle/query"),
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()


def _sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def _signature_key(secret_key: str, date_stamp: str, region_name: str, service_name: str) -> bytes:
    k_date = _sign(("AWS4" + secret_key).encode("utf-8"), date_stamp)
    k_region = _sign(k_date, region_name)
    k_service = _sign(k_region, service_name)
    return _sign(k_service, "aws4_request")


def _aws_signature(
    secret_key: str,
    request_parameters: str,
    headers: dict[str, str],
    method: str = "GET",
    payload: str = "",
    region: str = "cn",
    service: str = "vod",
) -> str:
    canonical_headers = "\n".join([f"{key}:{value}" for key, value in headers.items()]) + "\n"
    signed_headers = ";".join(headers.keys())
    payload_hash = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    canonical_request = f"{method}\n/\n{request_parameters}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    amzdate = headers["x-amz-date"]
    datestamp = amzdate.split("T")[0]
    credential_scope = f"{datestamp}/{region}/{service}/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amzdate}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"
    signing_key = _signature_key(secret_key, datestamp, region, service)
    return hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
