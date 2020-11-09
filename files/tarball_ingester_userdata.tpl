#!/bin/bash

# Force LC update when any of these files are changed
echo "${s3_file_tarball_ingester_logrotate_md5}" > /dev/null
echo "${s3_file_tarball_ingester_cloudwatch_sh_md5}" > /dev/null
echo "${s3_file_tarball_ingester_minio_sh_md5}" > /dev/null
echo "${s3_file_tarball_ingester_minio_service_file_md5}" > /dev/null
echo "${ti_manifest_file_md5}" > /dev/null

export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d'"' -f4)
export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

export http_proxy="http://${internet_proxy}:3128"
export HTTP_PROXY="$http_proxy"
export https_proxy="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="${non_proxied_endpoints}"
export NO_PROXY="$no_proxy"

echo "Configure AWS Inspector"
cat > /etc/init.d/awsagent.env << AWSAGENTPROXYCONFIG
export https_proxy=$https_proxy
export http_proxy=$http_proxy
export no_proxy=$no_proxy
AWSAGENTPROXYCONFIG

/etc/init.d/awsagent stop
sleep 5
/etc/init.d/awsagent start

echo "Configuring startup scripts paths"
S3_URI_LOGROTATE="s3://${s3_config_bucket}/${s3_file_tarball_ingester_logrotate}"
S3_CLOUDWATCH_SHELL="s3://${s3_config_bucket}/${s3_file_tarball_ingester_cloudwatch_sh}"
S3_MINIO_SHELL="s3://${s3_config_bucket}/${s3_file_tarball_ingester_minio_sh}"
S3_MINIO_SERVICE_FILE="s3://${s3_config_bucket}/${s3_file_tarball_ingester_minio_service_file}"
S3_MANIFEST_FILE="s3://${s3_config_bucket}/${s3_file_tarball_ingester_manifest_json_file}"

echo "Configuring startup file paths"
mkdir -p /opt/tarball_ingestion/

TI_MANIFEST_FILE_PATH="/opt/tarball_ingestion/tarball_ingester_manifest.json"

echo "Installing startup scripts"
aws s3 cp "$S3_URI_LOGROTATE"          /etc/logrotate.d/tarball_ingestion
aws s3 cp "$S3_CLOUDWATCH_SHELL"       /opt/tarball_ingestion/tarball_ingestion_cloudwatch.sh
aws s3 cp "$S3_MINIO_SHELL"            /opt/tarball_ingestion/tarball_ingestion_minio.sh
aws s3 cp "$S3_MINIO_SERVICE_FILE"     /etc/systemd/system/minio.service
aws s3 cp "$S3_MANIFEST_FILE"          "$TI_MANIFEST_FILE_PATH"

echo "Allow shutting down"
echo "tarball_ingestion     ALL = NOPASSWD: /sbin/shutdown -h now" >> /etc/sudoers

echo "Creating directories"
mkdir -p /var/log/tarball_ingestion

echo "Creating user tarball_ingestion"
useradd tarball_ingestion -m

echo "Setup cloudwatch logs"
chmod u+x /opt/tarball_ingestion/tarball_ingestion_cloudwatch.sh
/opt/tarball_ingestion/tarball_ingestion_cloudwatch.sh \
    "${cwa_metrics_collection_interval}" "${cwa_namespace}" "${cwa_cpu_metrics_collection_interval}" \
    "${cwa_disk_measurement_metrics_collection_interval}" "${cwa_disk_io_metrics_collection_interval}" \
    "${cwa_mem_metrics_collection_interval}" "${cwa_netstat_metrics_collection_interval}" "${cwa_log_group_name}" \
    "$AWS_DEFAULT_REGION"

echo "${environment_name}" > /opt/tarball_ingestion/environment

# Retrieve certificates
ACM_KEY_PASSWORD=$(uuidgen -r)

acm-cert-retriever \
--acm-cert-arn "${acm_cert_arn}" \
--acm-key-passphrase "$ACM_KEY_PASSWORD" \
--private-key-alias "${private_key_alias}" \
--truststore-aliases "${truststore_aliases}" \
--truststore-certs "${truststore_certs}" >> /var/log/acm-cert-retriever.log 2>&1

echo "Setup minio..."
chmod u+x /opt/tarball_ingestion/tarball_ingestion_minio.sh
/opt/tarball_ingestion/tarball_ingestion_minio.sh "${s3_artefact_bucket}" "${minio_s3_bucket_name}" "${tarball_ingester_endpoint}"

echo "Retrieving Tarball Ingester artefact..."
aws s3 cp s3://${s3_artefact_bucket}/dataworks-tarball-ingester/dataworks-tarball-ingester-${tarball_ingester_release}.zip \
    /tmp/dataworks-tarball-ingester-${tarball_ingester_release}.zip
   unzip -d /opt/tarball_ingestion /tmp/dataworks-tarball-ingester-${tarball_ingester_release}.zip
   chmod u+x /opt/tarball_ingestion/file-transfer.sh
   chmod u+x /opt/tarball_ingestion/steps/copy_collections_to_s3.py

echo "Changing permissions and moving files for tarball ingester"
chown tarball_ingestion:tarball_ingestion -R  /opt/tarball_ingestion
chown tarball_ingestion:tarball_ingestion -R  /var/log/tarball_ingestion

echo "Installing Python3 for running encryption script"
yum install -y python3
pip3 install -r /opt/tarball_ingestion/requirements.txt

if [[ "${environment_name}" != "production" ]]; then
    echo "Running script to copy synthetic tarballs..."
    echo "Synthetic tarball script would have run" >> /var/log/tarball_ingestion/tarball_ingestion.out 2>&1
fi

TI_ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --instance-ids $INSTANCE_ID \
    --region $AWS_DEFAULT_REGION \
    | grep AutoScalingGroupName | cut -d'"' -f4)


echo "Execute Python script to process Incrementals collections data..."
python3 /opt/tarball_ingestion/steps/copy_collections_to_s3.py -s "${ti_src_dir}" \
    -s3b "${ti_s3_bucket}" \
    -s3p "${ti_s3_prefix}" \
    -m "$TI_MANIFEST_FILE_PATH" \
    -t "${ti_tmp_dir}" \
    -d "${dks_endpoint}" \
    -f "incrementals" \
    -w "${ti_wait}" \
    -i "${ti_interval}" \
    -a "$TI_ASG_NAME" >> /var/log/tarball_ingestion/tarball_ingestion.out 2>&1


echo "Execute Python script to process Full collections data..."
python3 /opt/tarball_ingestion/steps/copy_collections_to_s3.py -s "${ti_src_dir}" \
    -s3b "${ti_s3_bucket}" \
    -s3p "${ti_s3_prefix}" \
    -m "TI_MANIFEST_FILE_PATH" \
    -t "${ti_tmp_dir}" \
    -d "${dks_endpoint}" \
    -f "fulls" \
    -w "${ti_wait}" \
    -i "${ti_interval}" \
    -a "$TI_ASG_NAME" >> /var/log/tarball_ingestion/tarball_ingestion.out 2>&1
