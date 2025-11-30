import io
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload


def main() -> None:
    sa_key = os.environ["GOOGLE_SERVICE_ACCOUNT_KEY"]
    folder_id = os.environ["GOOGLE_DRIVE_FOLDER_ID"]
    version = os.environ["VERSION"]

    if version.startswith("v") and version[1:].isdigit():
        ver_num = version[1:]
    else:
        sys.stderr.write(f"No Polarion mapping for non-version branch {version}\n")
        sys.exit(1)

    target_name = f"PolarionALM_{ver_num}.zip"

    info = json.loads(sa_key)
    creds = service_account.Credentials.from_service_account_info(
        info,
        scopes=["https://www.googleapis.com/auth/drive.readonly"],
    )

    service = build("drive", "v3", credentials=creds)

    query = f"'{folder_id}' in parents and name = '{target_name}' and trashed = false"
    resp = service.files().list(q=query, fields="files(id,name)", pageSize=1).execute()
    files = resp.get("files", [])
    if not files:
        sys.stderr.write(f"No file named {target_name} found in folder {folder_id}\n")
        sys.exit(1)

    file_id = files[0]["id"]

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
