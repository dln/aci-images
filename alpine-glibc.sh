#!/bin/bash
set -ex

alpine_version=3.2

aci_build=6
aci_version=${alpine_version}-${aci_build}

apk_mirror=http://nl.alpinelinux.org/alpine
glibc_apk_url=https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk


[ "$UID" == "0" ] || (echo "Must run as root." ; exit 1)


work_dir=$(mktemp -d /tmp/aci-apk-glibc-tmp.XXXXXX)
chroot_dir=${work_dir}/rootfs

function cleanup {
  unmount
  rm -rf ${chroot_dir}
}
trap cleanup EXIT

function unmount() {
  umount ${chroot_dir}/proc || true
  umount ${chroot_dir}/sys || true
}

function setup_devices() {
  mknod -m 666 ${chroot_dir}/dev/full c 1 7
  mknod -m 666 ${chroot_dir}/dev/ptmx c 5 2
  mknod -m 644 ${chroot_dir}/dev/random c 1 8
  mknod -m 644 ${chroot_dir}/dev/urandom c 1 9
  mknod -m 666 ${chroot_dir}/dev/zero c 1 5
  mknod -m 666 ${chroot_dir}/dev/tty c 5 0
}

function setup_netconf() {
  cat >${chroot_dir}/etc/resolv.conf <<EOF
nameserver 127.0.0.1
nameserver 8.8.8.8
nameserver 169.254.169.253
EOF

  cat >${chroot_dir}/etc/nsswitch.conf <<EOF
passwd:         compat
group:          compat
shadow:         compat
hosts:          files mdns4_minimal [NOTFOUND=return] dns
networks:       files
protocols:      db files
services:       db files
ethers:         db files
rpc:            db files
netgroup:       nis
EOF

  chmod 666 ${chroot_dir}/etc/hosts
}

function setup_packages() {
  mkdir -p ${chroot_dir}/etc/apk
  echo "${apk_mirror}/v${alpine_version}/main" > ${chroot_dir}/etc/apk/repositories

  # Install glibc
  curl -L -o ${chroot_dir}/tmp/glibc.apk ${glibc_apk_url}
  enter apk --update add bash ca-certificates wget
  enter apk add --allow-untrusted /tmp/glibc.apk
  rm -f ${chroot_dir}/tmp/glibc.apk
}

function setup_init_helper() {
  cat >${chroot_dir}/usr/sbin/ac_init_helper <<EOF
#!/bin/sh
echo "127.0.0.1 \$HOSTNAME localhost localhost.localdomain" >/etc/hosts
EOF
  chmod +x ${chroot_dir}/usr/sbin/ac_init_helper
}

function enter() {
  mount -t proc none ${chroot_dir}/proc
  mount -o bind /sys ${chroot_dir}/sys
  cmdline=$@
  chroot ${chroot_dir} /bin/sh -l -c "${cmdline}"
  unmount
}

test -d ${chroot_dir} && echo "${chroot_dir} already exists." && exit 1 
mkdir -p ${chroot_dir}
curl ${apk_mirror}/v${alpine_version}/main/x86_64/apk-tools-static-2.6.3-r0.apk | tar xz
./sbin/apk.static -X ${apk_mirror}/v${alpine_version}/main -U --allow-untrusted --root ${chroot_dir} --initdb add alpine-base

setup_netconf
setup_packages
setup_init_helper

cat >${work_dir}/manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.0",
  "name": "dln/alpine-glibc",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "$(TZ=Z date '+%Y-%m-%dT%H:%M:%SZ')"},
    {"name": "description", "value": "Alpine Linux minimal base image with glibc"}
  ]
}
EOF

actool build --overwrite ${work_dir} alpine-glibc.${aci_version}.linux.amd64.aci
