#!/bin/bash

configure_centos8_vault() {
    find /etc/yum.repos.d -maxdepth 1 -type f -name '*.repo' -delete
    cat > /etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
[baseos]
name=CentOS Linux 8.5 - BaseOS
baseurl=https://archive.kernel.org/centos-vault/8.5.2111/BaseOS/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
enabled=1

[appstream]
name=CentOS Linux 8.5 - AppStream
baseurl=https://archive.kernel.org/centos-vault/8.5.2111/AppStream/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
enabled=1

[powertools]
name=CentOS Linux 8.5 - PowerTools
baseurl=https://archive.kernel.org/centos-vault/8.5.2111/PowerTools/$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
enabled=1
EOF

    dnf -q clean all
}
