#!/usr/bin/env bash
# Central location for Build System configuration

declare -A SecureApt=(
  [debian_10.gpg]="https://ftp-master.debian.org/keys/archive-key-10.asc" \
    [nodesource.gpg]="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"  \
    [lesbonscomptes.gpg]="https://www.lesbonscomptes.com/pages/jf-at-dockes.org.pgp" \
    #TODO Not needed for arm64 and x86
    [raspbian.gpg]="https://archive.raspbian.org/raspbian.public.key" \
    [raspberrypi.gpg]="http://archive.raspberrypi.org/debian/raspberrypi.gpg.key" \
  )

## Path to the volumio repo
VOLBINSREPO="https://repo.volumio.org/Volumio2/Buster/Custom%20Packages"

## Array of volumio binaries
declare -A VOLBINS=(
[init-updater]="volumio-init-updater-v2"
)

## Array of custom packages 
# TODO: merge into VOLBINS!
declare -A CUSTOM_PKGS=(
  # For example only. This particular package isn't going to work on buster.
  [wiringpi]="https://repo.volumio.org/Volumio2/Binaries/wiringpi-2.29-1.deb" \
)

## Backend and Frontend Repository details
# VOL_BE_REPO="https://github.com/ashthespy/Volumio2.git"
# VOL_BE_REPO_BRANCH="buster_upstream"
VOL_BE_REPO="https://github.com/volumio/Volumio2.git"
VOL_BE_REPO_BRANCH="master"

## NodeJS Controls 
# Semver is only used w.t.r modules fetched from repo, 
# actual node version installs only respects the current major versions (Major.x)
# NODE_VERSION=14
NODE_VERSION=8.11.1  
# Used to pull the right version of modules
# expected format node_modules_{arm/x86}-v${NODE_VERSION}.tar.gz
NODE_MODULES_REPO="http://repo.volumio.org/Volumio2/"

export SecureApt VOLBINSREPO VOLBINS VOL_BE_REPO VOL_BE_REPO_BRANCH NODE_VERSION NODE_MODULES_REPO CUSTOM_PKGS
