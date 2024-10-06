#!/bin/bash
ls *.deb

# Make apt shut up about various things to see relevant output better
export DEBIAN_FRONTEND=noninteractive
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Speed up aarch64 images that have snapd because it keeps churning back and forth with apt calls
>&2 echo "Disabling snapd, if it's there"
systemctl disable --now snapd.socket
systemctl disable --now snapd.seeded.service
systemctl disable --now snapd.service

apt update
apt install -y zsh  # So if the test user has zsh, it'll work here

# The alphabetical order just happens to be the right order, but the libs need to be intalled first.
for pkg in *.deb; do
	apt install -y "./${pkg}"
done

>&2 echo "Configuring kanidm-unixd"

mkdir /etc/kanidm
mv unixd.toml /etc/kanidm/unixd
mv kanidm.toml /etc/kanidm/config

>&2 echo "Starting unixd"

systemctl start kanidm-unixd.service
systemctl start kanidm-unixd-tasks.service

>&2 echo "Configuring NSS"
sed -E 's/(passwd|group): (.*)/\1: \2 kanidm/' -i /etc/nsswitch.conf

>&2 echo "Configuring sshd"

cat << EOT >> /etc/ssh/sshd_config
PubkeyAuthentication yes
UsePAM yes
AuthorizedKeysCommand /usr/sbin/kanidm_ssh_authorizedkeys %u
AuthorizedKeysCommandUser nobody
LogLevel DEBUG1
EOT
systemctl restart ssh.service

>&2 echo "Go test ssh login! Do a ^C here when you're done"
>&2 echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost -p 2222"
>&2 echo "Or for direct ssh skipping unixd:"
>&2 echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 -i ssh_ed25519"
>&2 echo "Now following ssh log:"
journalctl -fu ssh
