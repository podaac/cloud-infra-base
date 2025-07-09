#!/bin/bash

echo "====== Install Fuse Prerequisite ======"
yum install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel -y

echo "====== Download S3FS ======"
git clone https://github.com/s3fs-fuse/s3fs-fuse.git

echo "====== Install S3FS ======"
cd s3fs-fuse
git checkout v1.95
./autogen.sh
./configure --prefix=/usr --with-openssl
make
make install

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

echo "====== Inject bash hook ======"
# Override original /bin/bash with custom init script
mv /bin/bash /bin/bash.real
cat << EOF > /bin/bash
#!/bin/bash.real
if [ "$(whoami)" == "ssm-user" ] && [ "$SHLVL" == "1" ]; then
  # Make the terminal look nice
  export PS1='[\u@\h \W]\$ '

  cd ~

  # Source the .bashrc only when logging in as ssm-user
  source ~/.bashrc
fi

exec /bin/bash.real $@
EOF
chmod +x /bin/bash

# Write .bashrc for ssm-user if doesn't exist
if ! [ -f "/home/ssm-user/.bashrc" ]; then
  cat << EOF > /home/ssm-user/.bashrc
export AWS_REGION=${aws_region}
export AWS_DEFAULT_REGION=${aws_region}
EOF
fi

echo "====== DONE with User Data ======"
