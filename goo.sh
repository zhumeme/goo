#!/bin/bash -ex

is_git_installed=$(which git)
if [ -z "${is_git_installed}" ]; then
  echo "git not installed"
  return
fi

old_version=$(go version | awk '{ print $3 }' | sed 's/go//g') # e.g. 1.16.3
new_version=$1                                                 # e.g. 1.16.4
go_root_parent=$(echo "$GOROOT" | xargs dirname)               # e.g. /usr/local
new_root="${go_root_parent}"/go${new_version}                  # e.g. /usr/local/go1.16.4
old_root=$GOROOT                                               # e.g. /usr/local/go1.16.3

if [ "$1" = "list" ]; then # list all versions
  local_list=$(ls -1 "${go_root_parent}" | grep -E "^go[0-9]+\.[0-9]+\.[0-9]+$" | awk -Fgo '{ print $NF }')
  echo "${local_list}"
  return
fi

exportGoVersion() { # export env vars
  export GOROOT=${new_root} &&
    export GOBIN=${new_root}/bin &&
    export PATH=${PATH//${old_root}/${new_root}}
  echo "Now use go version ${new_version}"
  return
}

if [ -z "${new_version}" ]; then # no version specified
  echo "Usage: goo $0 <version>"
fi

if [ -d "${new_root}" ]; then # new version dir already exist
  #  Go version already exist
  exportGoVersion
fi

new_version_found=false
list=$(git ls-remote -t https://github.com/golang/go | awk -F/ '{ print $NF }' | grep -Ev "^.*(rc|beta).*$" | grep go | sort -n) # e.g. go1.16.3 go1.16.4

if [ "$1" = "listall" ]; then # list all versions
  echo "All versions:
${list}"
  return
fi

if [ -z "${list}" ]; then # no version found in github repo tags
  echo "No version found in github repo tags"
  return
fi

if [ "${old_version}" = "${new_version}" ]; then # old version == new version
  echo "Go version ${new_version} already use in current shell"
  exportGoVersion
  return
fi

for v in ${list}; do
  if [ "${v}" = "go${new_version}" ]; then
    echo "Go version ${new_version} found"
    new_version_found=true
  fi
done

if [ "${new_version_found}" = false ]; then # new version not found in github repo tags
  echo "Go version ${new_version} not found"
  return
fi

if [ ! -d "${new_root}" ]; then # new version dir not exist
  echo "Go version dir not exist. now installing go${new_version} to ${new_root}"
  os=$(uname -s | tr '[:upper:]' '[:lower:]')      # e.g. darwin
  tar_name="go${new_version}.${os}-$(arch).tar.gz" # e.g. go1.16.4.darwin-amd64.tar.gz

  if [ ! -f /tmp/"${tar_name}" ]; then # tar.gz not exist in /tmp
    # download tar.gz
    git ls-remote -t https://github.com/golang/go |
      awk -F/ '{ print $NF }' |
      grep -E "^go(${new_version})$" | grep -vE "^.*(rc|beta).*$" |
      xargs -I {} wget -q --show-progress https://go.dev/dl/{}."${os}"-"$(arch)".tar.gz -P /tmp

  fi
  #  extract tar.gz
  echo "/tmp/${tar_name} downloaded. now extracting"
  (cd "${go_root_parent}") &&
    mkdir -p "${go_root_parent}/go${new_version}" &&
    tar -xf /tmp/"${tar_name}" -C "${go_root_parent}/go${new_version}" && # e.g. /usr/local/go1.16.4
    exportGoVersion
else
  echo "Go version ${new_version} already installed"
  exportGoVersion
fi
