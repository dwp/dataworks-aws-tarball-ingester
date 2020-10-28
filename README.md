# dataworks-aws-tarball-ingester

The tarball ingestion service provides an HTTPS endpoint for receiving UCFS'
business data tarballs.

## Overview

![Infrastructure](docs/infra.png)

UCFS will, on a daily basis, send full and incremental tarballs from their
business-data MongoDB clusters. Files will be transferred over HTTPS via a
VPC endpoint service fronting a deployment of a [MinIO](https://min.io/)
server.

Upon receipt of those files, the Tarball Ingestion service will encrypt the
files using DKS, then push the tarballs and encryption metadata to S3.

## Interfaces

### UCFS Data Interface

* UCFS will produce a number of tarballs from their MongoDB export process,
  one file per database cluster
* The tar files will be named
  `mongoc<cluster_name>-<backup_server_fqdn>-<YYYYMMDD>.tar`, e.g.
  `mongocmydb-backup00.example.com-20201028.tar`
* The tar files will contain one JSON-L file per collection contained in the
  MongoDB Export for a given cluster. The JSON-L file will be compressed using
  GZip.
* The JSON-L files will be called
  `srv/data/export/mongoc<cluster_name>-<backup_server_fqdn>-<YYYYMMDD>/<db_name>_<collection_name>_<YYYYMMDDHHMMSS>.json.gz`, e.g.
  `mongocadb-backup00.example.com-20201028/mydb_mycollection_20201028103145.json.gz`
* Each line in the JSON-L file will contain a single JSON document, as output by
  the MongoDB Export process
* The tar files will be sent to the `ucfs-business-data-tarballs` S3 bucket
  fronted by the MinIO service and placed under a date-based prefix of `YYYYMMDD/`

### Output Data Interface

* The Tarball Ingester will maintain the same file structure as defined in
  [UCFS Data Interface](#ucfs-data-interface) above.
* Additionally, though, the files will be encrypted using DKS
* The encryption metadata will be stored in the S3 object's metadata as follows:
  * `x-amz-meta-ciphertext`: The encrypted datakey used to encrypt the object
  * `x-amz-meta-datakeyencryptionkeyid`: The key ID used to encrypt the datakey,
    e.g. `cloudhsm:123456,789012`
  * `x-amz-meta-iv`: The initialisation vector used when encrypting the datakey
* The encrypted files will be stored in the `processed` S3 bucket under a key of
  `businessdata/tarball-mongo/ucdata/YYYY-MM-DD/mongoc<cluster_name>-<backup_server_fqdn>-<YYYYMMDD>.tar.enc`, e.g.
  `businessdata/tarball-mongo/ucdata/2020-10-28/mongocmydb-backup00.example.com-20201028.tar.enc`

### TLS Interface

* The Tarball Ingestion service will only be available over HTTPS with TLSv1.2
  encryption.
* The Tarball Ingestion service's certificate will be signed using DataWorks'
  ACM-PCA based CA; clients will need to import that CA's public certificate
  in order to use the service.

### DNS Interface

* Clients of the service will be able to resolve the service's IP address using
  DNS over the AWS PrivateLink connection

### Authentication

* Clients will authenticate to the Tarball Ingestion service using a shared
  secret (IAM-like access key ID and secret access key)
