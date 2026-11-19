#!/bin/bash

configure_centos7_vault() {
    local epel_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

    find /etc/yum.repos.d -maxdepth 1 -type f -name '*.repo' -delete
    cat > /etc/yum.repos.d/CentOS-Base.repo <<'EOF'
[base]
name=CentOS-7 - Base
baseurl=https://archive.kernel.org/centos-vault/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1

[updates]
name=CentOS-7 - Updates
baseurl=https://archive.kernel.org/centos-vault/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1

[extras]
name=CentOS-7 - Extras
baseurl=https://archive.kernel.org/centos-vault/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=1
EOF

    curl -fsSL --retry 3 \
        https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
        -o "$epel_key"
    printf '%s  %s\n' \
        '028b9accc59bab1d21f2f3f544df5469910581e728a64fd8c411a725a82300c2' \
        "$epel_key" | sha256sum --check --status || {
        echo 'EPEL 7 archive key checksum mismatch' >&2
        exit 1
    }
    rpm --import "$epel_key"

    cat > /etc/yum.repos.d/epel-archive.repo <<'EOF'
[epel-archive]
name=EPEL 7 Archive
baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
enabled=1
EOF

    yum -q clean all
}
