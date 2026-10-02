import urllib.request
import json
import os
import zipfile
import sys

def get_token():
    if os.environ.get('GITHUB_TOKEN'):
        return os.environ['GITHUB_TOKEN'].strip()
    token_file = os.path.join(os.path.dirname(__file__), 'token_github.txt')
    if os.path.exists(token_file):
        with open(token_file, 'r', encoding='utf-8') as f:
            return f.read().strip()
    return ''

token = get_token()
repo = 'meonam/iosApp'

def check_and_download(run_id=None):
    # 1. Get latest run if not specified
    if not run_id:
        url = f'https://api.github.com/repos/{repo}/actions/runs?per_page=3'
        req = urllib.request.Request(url, headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Mozilla/5.0'
        })
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            runs = data.get('workflow_runs', [])
            for r in runs:
                if r['status'] == 'completed' and r['conclusion'] == 'success':
                    run_id = str(r['id'])
                    print(f"Found successful run: {run_id} ({r['display_title']})")
                    break
                elif r['status'] in ('in_progress', 'queued'):
                    print(f"Run {r['id']} still {r['status']}...")
                    return False
    
    if not run_id:
        print("No completed successful run found yet.")
        return False

    # 2. Get artifacts
    url = f'https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts'
    req = urllib.request.Request(url, headers={
        'Authorization': 'Bearer ' + token,
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Mozilla/5.0'
    })
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        artifacts = data.get('artifacts', [])
        target = None
        for a in artifacts:
            if 'IPA' in a['name'] or 'ipa' in a['name'] or a['name'] == 'QLTB-iOS-App-IPA':
                target = a
                break
        if not target and artifacts:
            target = artifacts[0]
        if not target:
            print("No artifacts found in run", run_id)
            return False

    download_url = target['archive_download_url']
    print(f"Downloading artifact {target['name']} (ID: {target['id']}, size: {target['size_in_bytes']} bytes)...")

    # 3. Custom redirect handler to strip Authorization header when redirected to Azure Blob
    class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
            if new_req and 'Authorization' in new_req.headers:
                del new_req.headers['Authorization']
            return new_req

    opener = urllib.request.build_opener(NoAuthRedirect)
    req = urllib.request.Request(download_url, headers={
        'Authorization': 'Bearer ' + token,
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Mozilla/5.0'
    })

    build_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build')
    os.makedirs(build_dir, exist_ok=True)
    zip_path = os.path.join(build_dir, 'artifact.zip')

    with opener.open(req) as resp, open(zip_path, 'wb') as f:
        f.write(resp.read())

    print(f"Downloaded zip to {zip_path}. Extracting...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(build_dir)

    ipa_files = [f for f in os.listdir(build_dir) if f.endswith('.ipa')]
    if ipa_files:
        chosen_ipa = os.path.join(build_dir, ipa_files[0])
        size_mb = os.path.getsize(chosen_ipa) / (1024 * 1024)
        print(f"SUCCESS: {chosen_ipa} extracted! Size: {size_mb:.2f} MB")
        
        # Copy to release/iOS
        release_dir = r"E:\CODE\Android\APP\QLTB\release\iOS"
        os.makedirs(release_dir, exist_ok=True)
        import shutil
        dest_ipa = os.path.join(release_dir, os.path.basename(chosen_ipa))
        shutil.copy2(chosen_ipa, dest_ipa)
        print(f"COPIED TO RELEASE: {dest_ipa} ({os.path.getsize(dest_ipa) / (1024 * 1024):.2f} MB)")

        root_ipa = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.path.basename(chosen_ipa))
        shutil.copy2(chosen_ipa, root_ipa)
        print(f"COPIED TO ROOT: {root_ipa}")

        if os.path.exists(zip_path):
            os.remove(zip_path)
        return True
    else:
        print("Extracted files:", os.listdir(build_dir))
        return False

if __name__ == '__main__':
    rid = sys.argv[1] if len(sys.argv) > 1 else None
    check_and_download(rid)
