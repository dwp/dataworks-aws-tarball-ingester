#!/bin/bash

set -Eeuo pipefail

MINIO_ACCESS_KEY=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_ACCESS_KEY)
MINIO_SECRET_KEY=$(aws secretsmanager get-secret-value --secret-id minio --query SecretString --output text | jq -r .MINIO_SECRET_KEY)
S3_MINIO_BINARY="s3://${1}/minio/minio.RELEASE.2020-10-28T08-16-50Z"

echo "Downloading min.io binary..."
aws s3 cp "$S3_MINIO_BINARY" /usr/bin/minio
echo "Changing permissions for MinIO"
chmod +x /usr/bin/minio
minio --version

echo "Creating user minio"
useradd minio -M --shell=/sbin/nologin

echo "Creating MinIO Volume area"
mkdir -p /opt/minio
chown -R minio:minio /opt/minio

echo "Creating MinIO Config File"
cat <<MINIOCONFIG >> /etc/default/minio
# Volume to be used for MinIO server.
MINIO_VOLUMES="/opt/minio"
# Access Key of the server.
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
# Secret key of the server.
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
MINIOCONFIG

echo "Copying TLS certs for MinIO"
mkdir -p /home/minio/.minio/certs/CAs
cp /etc/pki/tls/private/tarball-ingester.key /home/minio/.minio/certs/private.key
chmod 0600 /home/minio/.minio/certs/private.key
cp /etc/pki/tls/certs/tarball-ingester.crt /home/minio/.minio/certs/public.crt
chmod 0600 /home/minio/.minio/certs/public.crt
chown -R minio:minio /home/minio/.minio

echo "Enabling MinIO Service"
systemctl enable minio.service
systemctl start minio.service

echo "Waiting for MinIO Service"
sleep 5

cat <<HOSTSOVERRIDE >> /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 ${3}
::1         localhost6 localhost6.localdomain6
HOSTSOVERRIDE

echo "Creating s3://ucfs_business_data_tarballs location in MinIO"
export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}
aws configure set default.s3.signature_version s3v4
AWS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt aws --endpoint-url https://${3}:9000 s3 mb s3://${2}
AWS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt aws --endpoint-url https://${3}:9000 s3 ls
