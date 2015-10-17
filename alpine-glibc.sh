#!/bin/bash
if [ "$UID" != "0" ]; then
  echo "$0 must be run as root."
  exit 1
fi

set -e
source _common.sh

alpine_version=3.2
aci_build=7
aci_version=${alpine_version}-${aci_build}

apk_mirror=http://nl.alpinelinux.org/alpine
glibc_apk_url=https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk
glibc_bin_apk_url=https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-bin-2.21-r2.apk

#### END CONFIG ####

function setup_netconf() {
  log "Creating initial resolv.conf"
  cat >${chroot_dir}/etc/resolv.conf <<EOF
nameserver 127.0.0.1
nameserver 8.8.8.8
nameserver 169.254.169.253
EOF

  log "Creating nsswitch.conf"
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
}

function initialize() {
  log "Initializing chroot: ${chroot_dir}"
  mkdir -p ${aci_dir} ${chroot_dir}
  mkdir -p ${chroot_dir}/etc/apk
}

function setup_packages() {
  log "Bootstrapping apk"
  curl -s ${apk_mirror}/v${alpine_version}/main/x86_64/apk-tools-static-2.6.3-r0.apk | tar -C ${work_dir} -xz

  log "Adding apk repositories"
  echo "${apk_mirror}/v${alpine_version}/main" > ${chroot_dir}/etc/apk/repositories

  log "Downloading glibc package"
  curl -s -L -o ${work_dir}/glibc.apk ${glibc_apk_url}
  curl -s -L -o ${work_dir}/glibc-bin.apk ${glibc_bin_apk_url}

  log "Installing packages"
  ${work_dir}/sbin/apk.static \
    -X ${apk_mirror}/v${alpine_version}/main -U --allow-untrusted --root ${chroot_dir} --initdb add \
      alpine-base \
      bash \
      ca-certificates \
      curl \
      wget \
      ${work_dir}/glibc.apk \
      ${work_dir}/glibc-bin.apk

  chroot ${chroot_dir} /usr/glibc/usr/bin/ldconfig /lib /usr/glibc/usr/lib
}

initialize
setup_packages
setup_netconf

write_manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.1",
  "name": "localhost/alpine-glibc",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "${timestamp}"},
    {"name": "description", "value": "Alpine Linux minimal base image with glibc"}
  ]
}
EOF

build_aci alpine-glibc.aci
