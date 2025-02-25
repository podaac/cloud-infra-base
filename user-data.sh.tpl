#!/bin/bash

yum install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel -y

git clone https://github.com/s3fs-fuse/s3fs-fuse.git

cd s3fs-fuse
./autogen.sh
./configure --prefix=/usr --with-openssl
make
make install

mv /home/ssm-user /home/ssm-user-backup

for dir in ${s3fs_directories}; do
    echo "making /$dir"
    mkdir -p /$dir
    s3fs ${s3fs_bucket_name}:/$dir /$dir -o iam_role=auto -o allow_other -o use_cache=/tmp
    echo "s3fs#${s3fs_bucket_name}:/$dir /$dir fuse _netdev,iam_role=auto,allow_other,use_cache=/tmp 0 0" >> /etc/fstab
    chown -R ssm-user:ssm-user /$dir

done

mkdir -p /persistent
s3fs ${s3fs_bucket_name} /persistent -o iam_role=auto -o allow_other -o use_cache=/tmp
echo "s3fs#${s3fs_bucket_name} /persistent fuse _netdev,iam_role=auto,allow_other,use_cache=/tmp 0 0" >> /etc/fstab
chown -R ssm-user:ssm-user /persistent

# Need to install Ansible here because it breaks otherwise
yum install ansible -y

for site in $(find /bootstrap -type f -name "site.yml"); do
    ansible-playbook "$site" -i localhost, --connection=local
done
