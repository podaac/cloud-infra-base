#!/bin/bash
set -eo pipefail

cat << EOF > /etc/carpathia_status
--- CARPATHIA IS INITIALIZING ---
The instance will be unstable for a few minutes while the setup is in progress.
Please wait until the setup is complete before using the instance.
EOF

# Override original /bin/bash with custom init script
mv /bin/bash /bin/bash.real
cat << EOF > /bin/bash
#!/bin/bash.real
if [ "\$(whoami)" == "ssm-user" ] && [ "\$SHLVL" == "1" ]; then
  # Make the terminal look nice
  export PS1='[\u@\h \W]\$ '

  cd ~

  # if /etc/carpathia_status exists, display its contents
  if [ -f /etc/carpathia_status ]; then
    cat /etc/carpathia_status
  fi

  # Source the .bashrc only when logging in as ssm-user
  source ~/.bashrc
fi

exec /bin/bash.real "\$@"
EOF
chmod +x /bin/bash
