import json
import sys


def lambda_handler(event, context):
    payload = {
        "ok": True,
        "message": "migrations lambda mvp",
        "request_id": getattr(context, "aws_request_id", "local"),
    }
    print(json.dumps(payload))
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def main() -> int:
    print("migrations lambda mvp")
    return 0


if __name__ == "__main__":
    sys.exit(main())
