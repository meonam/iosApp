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

# Có thể truyền tên repo từ tham số dòng lệnh hoặc mặc định
repo = sys.argv[1] if len(sys.argv) > 1 else 'meonam/iosApp'

def check_and_download(run_id=None):
    headers = {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Mozilla/5.0'
    }
    if token:
        headers['Authorization'] = 'Bearer ' + token

    # 1. Lấy workflow run mới nhất nếu không chỉ định run_id
    if not run_id:
        url = f'https://api.github.com/repos/{repo}/actions/runs?per_page=5'
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                runs = data.get('workflow_runs', [])
                for r in runs:
                    if 'BarcodeScanner' in r.get('name', '') or 'barcodescanner' in r.get('path', '').lower():
                        if r['status'] == 'completed' and r['conclusion'] == 'success':
                            run_id = str(r['id'])
                            print(f"Tìm thấy bản build thành công: {run_id} ({r['display_title']})")
                            break
                        elif r['status'] in ('in_progress', 'queued'):
                            print(f"Bản build {r['id']} vẫn đang chạy ({r['status']})...")
                            return False
        except Exception as e:
            print(f"Lỗi kiểm tra workflow: {e}")
            return False
    
    if not run_id:
        print("Chưa tìm thấy bản build thành công nào.")
        return False

    # 2. Tải Artifacts (.ipa)
    url = f'https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts'
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            artifacts = data.get('artifacts', [])
            target = None
            for a in artifacts:
                if 'BarcodeScanner' in a['name'] or 'IPA' in a['name']:
                    target = a
                    break
            if not target and artifacts:
                target = artifacts[0]
            
            if not target:
                print("Không tìm thấy tệp IPA trong Artifacts.")
                return False

            download_url = target['archive_download_url']
            print(f"Đang tải {target['name']} ({target['size_in_bytes']} bytes)...")
            
            down_req = urllib.request.Request(download_url, headers=headers)
            zip_dest = os.path.join(os.path.dirname(__file__), "BarcodeScanner_artifact.zip")
            with urllib.request.urlopen(down_req) as d_resp, open(zip_dest, 'wb') as out_f:
                out_f.write(d_resp.read())
            
            print(f"Đã tải xong: {zip_dest}")
            # Giải nén tìm file .ipa
            with zipfile.ZipFile(zip_dest, 'r') as zip_ref:
                zip_ref.extractall(os.path.dirname(__file__))
            print("Đã giải nén tệp .IPA thành công vào thư mục dự án!")
            return True
    except Exception as e:
        print(f"Lỗi tải Artifact: {e}")
        return False

if __name__ == '__main__':
    check_and_download()
