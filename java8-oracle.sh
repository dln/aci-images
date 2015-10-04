#!/bin/bash
set -ex

java_version_major=8
java_version_minor=60
java_version_build=27

aci_build=1
aci_version="${java_version_major}.${java_version_minor}.${java_version_build}-${aci_build}"

jdk_root=/usr/lib/jvm/java-${java_version_major}-oracle

## END CONFIG ##

work_dir=$(mktemp -d /tmp/aci-jdk-tmp.XXXXXX)
chroot_dir=${work_dir}/rootfs

function cleanup {
  rm -rf ${chroot_dir}
}
trap cleanup EXIT

jdk_dir=${chroot_dir}${jdk_root}

jdk_url=http://download.oracle.com/otn-pub/java/jdk/${java_version_major}u${java_version_minor}-b${java_version_build}/jdk-${java_version_major}u${java_version_minor}-linux-x64.tar.gz

mkdir -p ${chroot_dir}/usr/lib/jvm/ 
mkdir -p ${chroot_dir}/usr/bin

curl -jkSLH "Cookie: oraclelicense=accept-securebackup-cookie" ${jdk_url} \
  | tar -xz -C ${chroot_dir} --transform="s,jdk[^/]*,${jdk_root},"

find ${jdk_dir}/bin/ -type f -printf "%f\n" | xargs -I '{}' -n 1 ln -s ${jdk_root}/bin/{} ${chroot_dir}/usr/bin/{}

mkdir -p ${chroot_dir}/usr/java
ln -s ${jdk_root} ${chroot_dir}/usr/java/default

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

cat >${work_dir}/manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.0",
  "name": "dln/java${java_version_major}-oracle",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "$(TZ=Z date '+%Y-%m-%dT%H:%M:%SZ')"},
    {"name": "description", "value": "Oracle Java Development Kit ${java_version_major}"}
  ]
}
EOF

actool build ${work_dir} java${java_version_major}-oracle.${aci_version}.linux.amd64.aci
