#!/bin/bash
set -e

alpine_version=3.2

aci_build=7
aci_version=${alpine_version}-${aci_build}

aci_output=alpine-glibc.aci

apk_mirror=http://nl.alpinelinux.org/alpine
glibc_apk_url=https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk


[ "$UID" == "0" ] || (echo "Must run as root." ; exit 1)

work_dir=$(mktemp -d /tmp/aci-apk-glibc-tmp.XXXXXX)
aci_dir=${work_dir}/layout
chroot_dir=${aci_dir}/rootfs

function cleanup {
  rm -rf ${work_dir}
}
trap cleanup EXIT

function log() {
  echo -e "\e[32m ** " $1 "\e[0m"
}

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

  log "Preparing /etc/hosts"
  chmod 666 ${chroot_dir}/etc/hosts
}

function setup_init_helper() {
  log "Creating ac_init_helper script"
  cat >${chroot_dir}/usr/sbin/ac_init_helper <<EOF
#!/bin/sh
echo "127.0.0.1 \$HOSTNAME localhost localhost.localdomain" >/etc/hosts
EOF
  chmod +x ${chroot_dir}/usr/sbin/ac_init_helper
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

  log "Installing packages"
  ${work_dir}/sbin/apk.static -X ${apk_mirror}/v${alpine_version}/main -U --allow-untrusted --root ${chroot_dir} --initdb add \
    alpine-base \
    bash \
    ca-certificates \
    curl \
    wget \
    ${work_dir}/glibc.apk
}

function write_manifest() {
  log "Writing ACI manifest"
  cat >${aci_dir}/manifest <<EOF
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
}


initialize
setup_packages
setup_netconf
setup_init_helper
write_manifest

log "Building ACI"
actool build --overwrite ${aci_dir} ${aci_output}

log "All done => ${aci_output}"
