import requests

SERVER = "http://127.0.0.1:8001"
HEADERS = {"X-SSR-Secret": "ssr-demo-secret-2025"}

def run():
    print("=== Testing /detect-road-damage ===")
    img_url = "https://dummyimage.com/600x400/000/fff.jpg"
    try:
        res = requests.post(
            f"{SERVER}/detect-road-damage",
            json={"image_url": img_url, "source_channel": "app"},
            headers=HEADERS
        )
        print("Status", res.status_code)
        print("Detect:", res.json())
    except Exception as e:
        print("Detect error:", e)

    print("\n=== Testing /verify-repair ===")
    try:
        res = requests.post(f"{SERVER}/verify-repair", json={
            "before_image_url": img_url,
            "after_image_url": img_url
        }, headers=HEADERS)
        print("Status", res.status_code)
        print("Verify:", res.json())
    except Exception as e:
        print("Verify error:", e)

if __name__ == "__main__":
    run()
