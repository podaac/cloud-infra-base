#!/bin/bash

echo "====== Install Fuse Prerequisite ======"
yum install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel -y

echo "====== Download S3FS ======"
git clone https://github.com/s3fs-fuse/s3fs-fuse.git

echo "====== Install S3FS ======"
cd s3fs-fuse
./autogen.sh
./configure --prefix=/usr --with-openssl
make
make install

echo "====== Backup ssm-user Home Dir ======"
mv /home/ssm-user /home/ssm-user-backup

echo "====== Create S3FS Mounts and Populate FSTAB ======"
for dir in ${s3fs_directories}; do
    echo "making /$dir"
    mkdir -p /$dir
    echo "s3fs#${s3fs_bucket_name}:/$dir /$dir fuse _netdev,iam_role=auto,allow_other,use_cache=/tmp,uid=1001,gid=1001,umask=0022 0 0" >> /etc/fstab
done

echo "====== Create Persistent ======"
mkdir -p /persistent

echo "====== Update FSTAB with Persistent ======"
echo "s3fs#${s3fs_bucket_name} /persistent fuse _netdev,iam_role=auto,allow_other,use_cache=/tmp,uid=1001,gid=1001,umask=0022 0 0" >> /etc/fstab

echo "====== Mount It ALL ======"
mount -a

echo "====== Wait for s3fs boostrap mount ======"
while ! grep -q -s "s3fs /bootstrap" /proc/mounts; do
        echo "Waiting for /bootstrap mount"
        sleep 10
done

echo "====== Install Ansible ======"
# Need to install Ansible here because it breaks otherwise
yum install ansible -y

echo "====== Run Ansibles ======"
for site in $(find /bootstrap -mindepth 3 -maxdepth 3 -type f -path "/bootstrap/*/ansible/site.yml"); do
    echo "Found $site"
    ansible-playbook "$site" -v -i localhost, --connection=local
done

echo "====== DONE with User Data ======"