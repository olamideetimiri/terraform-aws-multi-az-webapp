#!/bin/bash
set -e
set -x

# Log user-data execution
exec > /var/log/user-data.log 2>&1

# Update system
yum update -y

# Install dependencies
yum install -y python3 python3-pip awscli

# Install postgres driver
pip3 install psycopg2-binary

# Create app directory
mkdir -p /opt/app

# Helper to retry SSM parameter fetches
get_param() {
  local name=$1
  local decrypt_flag=$2
  local value=""

  until value=$(aws ssm get-parameter --region eu-west-2 --name "$name" $decrypt_flag --query "Parameter.Value" --output text 2>/dev/null); do
    echo "Waiting for SSM parameter $name..."
    sleep 10
  done

  echo "$value"
}

# Fetch DB config from SSM with retry
DB_HOST=$(get_param "/mazwi/db/host" "")
DB_PORT=$(get_param "/mazwi/db/port" "")
DB_NAME=$(get_param "/mazwi/db/name" "")
DB_USER=$(get_param "/mazwi/db/username" "")
DB_PASS=$(get_param "/mazwi/db/password" "--with-decryption")

# Write environment variables for systemd
cat <<EOF > /opt/app/env.sh
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF

# Python application
cat <<'EOF' > /opt/app/app.py
import os
import psycopg2
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

def get_az():
    try:
        token_req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"}
        )
        with urllib.request.urlopen(token_req, timeout=2) as response:
            token = response.read().decode()

        az_req = urllib.request.Request(
            "http://169.254.169.254/latest/meta-data/placement/availability-zone",
            headers={"X-aws-ec2-metadata-token": token}
        )
        with urllib.request.urlopen(az_req, timeout=2) as response:
            return response.read().decode()
    except Exception:
        return "unknown"

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
            return

        if self.path == "/az":
            az = get_az()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Served from {az}".encode())
            return

        if self.path == "/db":
            try:
                conn = psycopg2.connect(
                    host=os.environ["DB_HOST"],
                    port=os.environ["DB_PORT"],
                    dbname=os.environ["DB_NAME"],
                    user=os.environ["DB_USER"],
                    password=os.environ["DB_PASS"]
                )
                cur = conn.cursor()
                cur.execute("SELECT now();")
                result = cur.fetchone()[0]
                cur.close()
                conn.close()

                self.send_response(200)
                self.end_headers()
                self.wfile.write(str(result).encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f"DB connection failed: {str(e)}".encode())
            return

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Hello from EC2")

server = HTTPServer(("0.0.0.0", 8000), Handler)
server.serve_forever()
EOF

# systemd service
cat <<EOF > /etc/systemd/system/app.service
[Unit]
Description=Python App
After=network.target

[Service]
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/env.sh
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app
systemctl start app
