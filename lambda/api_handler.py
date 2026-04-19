import json
import os
import boto3
from botocore.config import Config

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))

INPUT_BUCKET = os.environ["INPUT_BUCKET"]
OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
PRESIGN_EXPIRY = 300


def _ok(body: dict) -> dict:
    return {"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}


def _err(status: int, message: str) -> dict:
    return {"statusCode": status, "headers": {"Content-Type": "application/json"}, "body": json.dumps({"error": message})}


def handler(event, context):
    route = event.get("routeKey", "")

    if route == "POST /presign":
        try:
            body = json.loads(event.get("body") or "{}")
        except json.JSONDecodeError:
            return _err(400, "Invalid JSON body")

        filename = body.get("filename", "upload.jpg")
        # Sanitize: strip path components, force .jpg extension
        filename = os.path.basename(filename).rsplit(".", 1)[0] + ".jpg"
        key = f"uploads/{filename}"

        url = s3.generate_presigned_url(
            "put_object",
            Params={"Bucket": INPUT_BUCKET, "Key": key, "ContentType": "image/jpeg"},
            ExpiresIn=PRESIGN_EXPIRY,
        )
        return _ok({"upload_url": url, "key": key})

    if route == "GET /results/{key}":
        raw_key = event.get("pathParameters", {}).get("key", "")
        # Strip extension and path to get the base name used as output prefix
        base = os.path.basename(raw_key).rsplit(".", 1)[0]
        prefix = f"results/{base}_"

        response = s3.list_objects_v2(Bucket=OUTPUT_BUCKET, Prefix=prefix)
        objects = response.get("Contents", [])

        if not objects:
            return _ok({"status": "pending"})

        latest = sorted(objects, key=lambda o: o["LastModified"], reverse=True)[0]
        obj = s3.get_object(Bucket=OUTPUT_BUCKET, Key=latest["Key"])
        data = json.loads(obj["Body"].read())
        return _ok({"status": "complete", **data})

    return _err(404, "Not found")
