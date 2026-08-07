#!/bin/bash -i
#
# This build runs on registry.fit2cloud.com/public/python:3
utils_dir=$(pwd)
project_dir=$(dirname "$utils_dir")
release_dir=${project_dir}/release

# Enable alias
shopt -s expand_aliases
# Package
cd "${project_dir}" || exit 3
rm -rf "${release_dir:?}"/*
to_dir="${release_dir}/jumpserver-installer"
mkdir -p "${to_dir}"

if [[ -d '.git' ]]; then
  command -v git || yum -q -y install git
  git archive --format tar HEAD | tar x -C "${to_dir}"
else
  cp -R . /tmp/jumpserver
  mv /tmp/jumpserver/* "${to_dir}"
fi

shopt -s expand_aliases
if [[ $(uname) == 'Darwin' ]]; then
  alias sedi='sed -i ""'
else
  alias sedi='sed -i'
fi

# Update the version file
if [[ -n ${VERSION} ]]; then
  sedi "s@VERSION=.*@VERSION=\"${VERSION}\"@g" "${to_dir}/static.env"
fi
