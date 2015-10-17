#!/bin/bash
set -e
source _common.sh

aci_version="1.0.0-1"

#### END CONFIG ####

write_manifest <<EOF
{
  "acKind": "ImageManifest",
  "acVersion": "0.7.1",
  "name": "localhost/bash",
  "labels": [
    {"name": "os", "value": "linux"},
    {"name": "arch", "value": "amd64"},
    {"name": "version", "value": "${aci_version}"}
  ],
  "annotations": [
    {"name": "authors", "value": "Daniel Lundin <dln@eintr.org>"},
    {"name": "created", "value": "${timestamp}"},
    {"name": "description", "value": "Starts a bash shell"}
  ],
  "dependencies": [
    {
      "imageName": "localhost/alpine-glibc",
      "labels": [
        {"name": "os", "value": "linux"},
        {"name": "arch", "value": "amd64"}
      ]
    }
  ],
  "app": {
    "exec": ["/bin/bash"],
    "user": "0",
    "group": "0",
    "workingDirectory": "/tmp",
    "mountPoints": [
      {"name": "resolv-conf", "path": "/etc/resolv.conf"}
    ],
    "eventHandlers": [
      {
        "name": "pre-start", "exec": [
          "/usr/sbin/ac_init_helper"
        ]
      }
    ]
  }
}
EOF

build_aci bash.aci
