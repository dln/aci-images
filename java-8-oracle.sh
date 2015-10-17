#!/bin/bash
set -e
source _common.sh

java_version_major=8
java_version_minor=60
java_version_build=27

aci_build=1

#### END CONFIG ####

aci_version="${java_version_major}.${java_version_minor}.${java_version_build}-${aci_build}"
jdk_root=/usr/lib/jvm/java-${java_version_major}-oracle
jdk_dir=${chroot_dir}${jdk_root}
jdk_url=http://download.oracle.com/otn-pub/java/jdk/${java_version_major}u${java_version_minor}-b${java_version_build}/jdk-${java_version_major}u${java_version_minor}-linux-x64.tar.gz

log "Creating directory structure"
mkdir -p ${chroot_dir}/usr/lib/jvm/ 
mkdir -p ${chroot_dir}/usr/bin

log "Downloading JDK distribution"
curl --progress-bar -jkSLH "Cookie: oraclelicense=accept-securebackup-cookie" ${jdk_url} \
  | tar -xz -P --transform="s,jdk[^/]*,${chroot_dir}${jdk_root}," 

log "Creating symlinks in /usr/bin/"
find ${jdk_dir}/bin/ -type f -printf "%f\n" | xargs -I '{}' -n 1 ln -s ${jdk_root}/bin/{} ${chroot_dir}/usr/bin/{}

log "Creating Centos symlinks for compatibility"
mkdir -p ${chroot_dir}/usr/java
ln -s ${jdk_root} ${chroot_dir}/usr/java/default

log "Removing non-server JDK/JRE stuff to reduce weight"
rm -rf \
  ${jdk_dir}/*src.zip \
  ${jdk_dir}/man \
  ${jdk_dir}/lib/missioncontrol \
  ${jdk_dir}/lib/visualvm \
  ${jdk_dir}/lib/*javafx* \
  ${jdk_dir}/jre/lib/plugin.jar \
  ${jdk_dir}/jre/lib/ext/jfxrt.jar \
  ${jdk_dir}/jre/bin/javaws \
  ${jdk_dir}/jre/lib/javaws.jar \
  ${jdk_dir}/jre/lib/desktop \
  ${jdk_dir}/jre/plugin \
  ${jdk_dir}/jre/lib/deploy* \
  ${jdk_dir}/jre/lib/*javafx* \
  ${jdk_dir}/jre/lib/*jfx* \
  ${jdk_dir}/jre/lib/amd64/libdecora_sse.so \
  ${jdk_dir}/jre/lib/amd64/libprism_*.so \
  ${jdk_dir}/jre/lib/amd64/libfxplugins.so \
  ${jdk_dir}/jre/lib/amd64/libglass.so \
  ${jdk_dir}/jre/lib/amd64/libgstreamer-lite.so \
  ${jdk_dir}/jre/lib/amd64/libjavafx*.so \
  ${jdk_dir}/jre/lib/amd64/libjfx*.so


write_manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.1",
  "name": "localhost/java-${java_version_major}-oracle",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "${timestamp}"},
    {"name": "description", "value": "Oracle Java Development Kit ${java_version_major}"}
  ]
}
EOF

build_aci java-${java_version_major}-oracle.aci
