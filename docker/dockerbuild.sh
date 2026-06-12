#!/bin/bash

set -Eeuo pipefail
sudo pacman -Sy

cd /home/build

git config --global init.defaultBranch master

sudo sed -i 's/unshare --user/true/' /usr/bin/makechrootpkg
sudo ed -i 's/unshare --fork --pid gpg/gpg/g' /usr/bin/arch-nspawn
sudo sed -i 's/unshare --mount pacstrap/pacstrap/g' /usr/bin/mkarchroot

if [ -f ./hook-run.sh ]; then
   . ./hook-run.sh
fi

if [ ! -d repos ]; then
  git clone --depth=3 $1 repos


  pushd repos
  git checkout "$CHECKOUT_BRANCH"
  git fetch --recurse-submodules -j2
  git submodule update --init

  git submodule set-branch --branch chroot utils
  git submodule update --remote utils
  popd
fi

export DOCKER_SETUP_SCRIPT=1

CHROOT_DIR="${CHROOT_DIR:-/var/lib/archbuild/extra-x86_64}"

if [ $UID -eq 0 ]; then
    chown -R build:build repos

    echo "$TARGET_HOSTS" | base64 -d >> /etc/hosts

    if [ ! -d "$CHROOT_DIR/root" ]; then
        mkdir -p "$CHROOT_DIR"
        mkarchroot "$CHROOT_DIR/root" base-devel
    fi
else
    echo "$TARGET_HOSTS" | base64 -d | sudo tee -a /etc/hosts >/dev/null

    if [ ! -d "$CHROOT_DIR/root" ]; then
        sudo mkdir -p "$CHROOT_DIR"
        sudo mkarchroot "$CHROOT_DIR/root" base-devel
    fi
fi

pushd repos
if [ $UID -eq 0 ]; then

    su -c "echo $GPG_PRIV_KEY | base64 -d | gpg --import" build

    su -c './utils/pkgbuild_bootstrap' build

else

    echo $GPG_PRIV_KEY | base64 -d | gpg --import

    ./utils/pkgbuild_bootstrap

fi

popd

