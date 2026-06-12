#!/bin/bash

set -Eeuo pipefail
sudo pacman -Sy

cd /home/build

git config --global init.defaultBranch master

sudo sed -i 's/unshare --user/true/' /usr/bin/makechrootpkg
sudo sed -i 's/unshare --mount pacstrap/pacstrap/' /usr/bin/mkarchroot
sudo sed -i 's/unshare --fork --pid gpg/gpg/' /usr/bin/arch-nspawn

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
        pacstrap -GMc "$CHROOT_DIR/root" base-devel
        echo "1" > "$CHROOT_DIR/root/.arch-chroot"
        printf '%s.UTF-8 UTF-8\n' en_US de_DE > "$CHROOT_DIR/root/etc/locale.gen"
        echo 'LANG=C.UTF-8' > "$CHROOT_DIR/root/etc/locale.conf"
    fi
else
    echo "$TARGET_HOSTS" | base64 -d | sudo tee -a /etc/hosts >/dev/null

    if [ ! -d "$CHROOT_DIR/root" ]; then
        sudo mkdir -p "$CHROOT_DIR"
        sudo pacstrap -GMc "$CHROOT_DIR/root" base-devel
        echo "1" | sudo tee "$CHROOT_DIR/root/.arch-chroot" >/dev/null
        printf '%s.UTF-8 UTF-8\n' en_US de_DE | sudo tee "$CHROOT_DIR/root/etc/locale.gen" >/dev/null
        echo 'LANG=C.UTF-8' | sudo tee "$CHROOT_DIR/root/etc/locale.conf" >/dev/null
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

