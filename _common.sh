work_dir=$(mktemp -d /tmp/aci-tmp.XXXXXX)
aci_dir=${work_dir}/layout
chroot_dir=${aci_dir}/rootfs

timestamp=$(TZ=Z date '+%Y-%m-%dT%H:%M:%SZ')

function cleanup {
  rm -rf ${chroot_dir}
}
trap cleanup EXIT

function log() {
  echo -e "\e[32m ** " $1 "\e[0m"
}

log "Initializing"
mkdir -p ${chroot_dir} ${aci_dir}


function write_manifest {
  log "Writing manifest"
  cat >${aci_dir}/manifest
}

function build_aci {
  aci_output=$1

  log "Building ACI"
  actool build --overwrite ${aci_dir} ${aci_output}
  actool validate ${aci_output}
  echo "All done."
  echo "=> ${aci_output}"
}

