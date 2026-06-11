import json
import os
import urllib.request
import urllib.error

TOKEN = os.environ.get("GITHUB_TOKEN")
if not TOKEN:
    print("Error: GITHUB_TOKEN environment variable not set.")
    exit(1)
REPO = "j4dy/RotatedForMacMusicians"
TAG = "v0.2.0-beta"
DMG_PATH = "Vecto.dmg"

def make_request(url, data=None, headers=None, method="GET"):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} - {e.reason}")
        print(e.read().decode('utf-8', errors='ignore'))
        raise

def main():
    print(f"=== Creating GitHub Release for {TAG} ===")
    
    release_url = f"https://api.github.com/repos/{REPO}/releases"
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "python-urllib"
    }
    
    release_data = json.dumps({
        "tag_name": TAG,
        "name": TAG,
        "body": (
            "## Rotated For Mac Musicians - Version 0.2.0 Beta\n\n"
            "This release introduces full support for 2-button sheet music browsing with dynamic direction toggling and edge wrapping:\n"
            "- **Double-Click Direction Toggle**: Double-pressing the Left Arrow button toggles the navigation keys between horizontal movement (Left/Right) and vertical movement (Up/Down).\n"
            "- **Typewriter Edge Wrapping**: Moving the cursor past the left or right screen boundary automatically wraps it to the opposite edge and offsets it vertically up or down by exactly 1 line (configured focus cursor size).\n"
            "- **Manual Override Controls**: Arrow keys behave as responsive manual 2D buttons when in browsing mode.\n"
            "- **Jitter & Duplicate Wrap Elimination**: Smart check cancels any accidental drift caused by the first press in double-press sequences or simultaneous clicking.\n"
            "- **On-screen Instruction Banner**: Adds a clear instructions banner displaying the hold-to-exit and double-click direction toggle shortcuts.\n"
            "- **AppKit Native Event Loop Dispatch**: Resolves WKWebView focus hijacking issues to deliver robust programmatic clicks."
        ),
        "draft": False,
        "prerelease": True
    }).encode('utf-8')
    
    status, body_data = make_request(release_url, data=release_data, headers=headers, method="POST")
    response_json = json.loads(body_data.decode('utf-8'))
    print(f"Release created successfully! ID: {response_json['id']}")
    
    upload_url_template = response_json['upload_url']
    # Clean template URL: e.g. "https://uploads.github.com/.../assets{?name,label}" -> "https://uploads.github.com/.../assets"
    upload_url = upload_url_template.split('{')[0]
    
    print(f"=== Uploading {DMG_PATH} to Release ===")
    if not os.path.exists(DMG_PATH):
        raise FileNotFoundError(f"Could not find release binary at: {DMG_PATH}")
        
    file_size = os.path.getsize(DMG_PATH)
    with open(DMG_PATH, 'rb') as f:
        file_data = f.read()
        
    upload_headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/octet-stream",
        "Content-Length": str(file_size),
        "User-Agent": "python-urllib"
    }
    
    upload_url_with_name = f"{upload_url}?name=Vecto.dmg"
    status, upload_body = make_request(upload_url_with_name, data=file_data, headers=upload_headers, method="POST")
    upload_response = json.loads(upload_body.decode('utf-8'))
    print("=== Upload Complete ===")
    print(f"Asset URL: {upload_response['browser_download_url']}")

if __name__ == "__main__":
    main()
