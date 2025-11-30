import io
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload


def _build_service(sa_key: str):
    info = json.loads(sa_key)
    creds = service_account.Credentials.from_service_account_info(
        info,
        scopes=["https://www.googleapis.com/auth/drive.readonly"],
    )
    return build("drive", "v3", credentials=creds)


def _find_exact_version(service, folder_id: str, ver_num: str):
    target_name = f"PolarionALM_{ver_num}.zip"
    query = f"'{folder_id}' in parents and name = '{target_name}' and trashed = false"
    resp = service.files().list(q=query, fields="files(id,name)", pageSize=1).execute()
    files = resp.get("files", [])
    if not files:
        sys.stderr.write(f"No file named {target_name} found in folder {folder_id}\n")
        sys.exit(1)
    file_id = files[0]["id"]
    return file_id, target_name


def _extract_ver(name: str) -> int:
    # Erwartet Namen wie "PolarionALM_2512.zip" -> 2512
    base = os.path.basename(name)
    if base.startswith("PolarionALM_") and base.endswith(".zip"):
        middle = base[len("PolarionALM_") : -len(".zip")]
        if middle.isdigit():
            return int(middle)
    return -1


def _find_latest(service, folder_id: str):
    query = (
        f"'{folder_id}' in parents and name contains 'PolarionALM_' and "
        "name contains '.zip' and trashed = false"
    )
    resp = service.files().list(q=query, fields="files(id,name)", pageSize=1000).execute()
    files = resp.get("files", [])
    if not files:
        sys.stderr.write(f"No Polarion ZIPs found in folder {folder_id}\n")
        sys.exit(1)

    candidates = [(_extract_ver(f["name"]), f) for f in files]
    candidates = [c for c in candidates if c[0] >= 0]
    if not candidates:
        sys.stderr.write(
            f"No Polarion ZIPs with parsable version in folder {folder_id}\n"
        )
        sys.exit(1)

    _, best_file = max(candidates, key=lambda x: x[0])
    file_id = best_file["id"]
    target_name = best_file["name"]
    return file_id, target_name


def main() -> None:
    sa_key = os.environ["GOOGLE_SERVICE_ACCOUNT_KEY"]
    folder_id = os.environ["GOOGLE_DRIVE_FOLDER_ID"]
    version = os.environ["VERSION"]

    service = _build_service(sa_key)

    # Version-Branch (z.B. v2512): exakte Datei "PolarionALM_2512.zip"
    if version.startswith("v") and version[1:].isdigit():
        ver_num = version[1:]
        file_id, target_name = _find_exact_version(service, folder_id, ver_num)
    # main/master: wähle die neueste Datei nach Versionsnummer im Namen
    else:
        file_id, target_name = _find_latest(service, folder_id)

    request = service.files().get_media(fileId=file_id)
    fh = io.BytesIO()
    downloader = MediaIoBaseDownload(fh, request)
    done = False
    while not done:
        status, done = downloader.next_chunk()
        if status:
            print(f"Download {int(status.progress() * 100)}%.")

    fh.seek(0)
    with open("polarion-linux.zip", "wb") as f:
        f.write(fh.read())

    print(f"Downloaded {target_name} to polarion-linux.zip")


if __name__ == "__main__":
    main()
