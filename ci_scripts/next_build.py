#!/usr/bin/env python3
"""Print the next build number: latest ASC build + 1.

Usage: python3 next_build.py <app_id>

Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY from environment.
"""
import sys
import os
import time

try:
    import jwt
    import requests
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "PyJWT", "requests", "-q"])
    import jwt
    import requests

app_id = sys.argv[1]
key_id = os.environ["ASC_KEY_ID"]
issuer_id = os.environ["ASC_ISSUER_ID"]
private_key = os.environ["ASC_PRIVATE_KEY"]

token = jwt.encode(
    {
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    },
    private_key,
    algorithm="ES256",
    headers={"kid": key_id},
)
h = {"Authorization": "Bearer " + token}
resp = requests.get(
    f"https://api.appstoreconnect.apple.com/v1/builds"
    f"?filter[app]={app_id}&sort=-uploadedDate&limit=1",
    headers=h,
)
resp.raise_for_status()
data = resp.json().get("data", [])
latest = int(data[0]["attributes"]["version"]) if data else 0
print(latest + 1)
