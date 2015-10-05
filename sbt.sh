#!/bin/bash
set -e
source _common.sh

aci_version="1.0.4-1"

sbt_extras_revision=master

#### END CONFIG ####

log "Downloading sbt launch script from sbt-extras"
mkdir -p ${chroot_dir}/usr/bin
curl -sL https://raw.githubusercontent.com/paulp/sbt-extras/master/sbt > ${chroot_dir}/usr/bin/sbt
chmod +x ${chroot_dir}/usr/bin/sbt

write_manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.0",
  "name": "dln/sbt",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "${timestamp}"},
    {"name": "description", "value": "The simple/scala/standard build tool"}
  ],
  "dependencies": [
    {
      "imageName": "dln/alpine-glibc",
      "labels": [
        {"name": "os", "value": "linux"},
        {"name": "arch", "value": "amd64"}
      ]
    },
    {
      "imageName": "dln/java-8-oracle",
      "labels": [
        {"name": "os", "value": "linux"},
        {"name": "arch", "value": "amd64"}
      ]
    }
  ],
  "app": {
    "exec": ["/usr/bin/sbt"],
    "user": "0",
    "group": "0",
    "workingDirectory": "/work",
    "mountPoints": [
      {"name": "resolv-conf", "path": "/etc/resolv.conf"},
      {"name": "work", "path": "/work"},
      {"name": "home", "path": "/root"}
    ],
    "eventHandlers": [
      {
        "name": "pre-start",
        "exec": [
          "/usr/sbin/ac_init_helper"
        ]
      }
    ],
    "environment": [
      {"name": "JAVA_HOME", "value": "/usr/lib/jvm/java-8-oracle"}
    ]
  }
}
EOF

build_aci sbt.aci
