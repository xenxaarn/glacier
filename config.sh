#!/bin/bash

set -euxo pipefail

test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

: "${kiwi_iname:=Glacier}"
echo "Configure image: [$kiwi_iname]..."

/usr/libexec/glacier-branding

EXT_LIST="/usr/share/glacier/extensions.txt"
if [ -f "$EXT_LIST" ]; then
  gnome_shell_version=$(rpm -q --qf '%{VERSION}' gnome-shell)
  gnome_shell_major=${gnome_shell_version%%.*}
  ext_dir=/usr/share/gnome-shell/extensions
  tmp_dir=$(mktemp -d)
  installed_list=""

  while read -r uuid; do
    case "$uuid" in
    '' | '#'*) continue ;;
    esac

    # Fetch errors abort the build.
    code=$(curl -sS --retry 3 --retry-delay 2 -o "$tmp_dir/info.json" -w '%{http_code}' \
      "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$gnome_shell_major")
    if [ "$code" != 200 ]; then
      echo "ERROR: extensions.gnome.org returned HTTP $code for $uuid" >&2
      exit 1
    fi
    dl_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("download_url",""))' "$tmp_dir/info.json")
    if [ -z "$dl_url" ]; then
      echo "WARN: $uuid has no build for GNOME Shell $gnome_shell_major, skipping" >&2
      continue
    fi

    curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_dir/ext.zip" "https://extensions.gnome.org$dl_url"
    python3 -m zipfile -e "$tmp_dir/ext.zip" "$ext_dir/$uuid"
    if [ -d "$ext_dir/$uuid/schemas" ]; then
      glib-compile-schemas "$ext_dir/$uuid/schemas"
    fi

    installed_list="${installed_list:+$installed_list, }'$uuid'"
  done <"$EXT_LIST"

  if [ -n "$installed_list" ]; then
    mkdir -p /etc/dconf/db/local.d
    printf '[org/gnome/shell]\nenabled-extensions=[%s]\n' "$installed_list" \
      >/etc/dconf/db/local.d/01-extensions
  fi
  rm -rf "$tmp_dir"
fi

OMAPIXICON_REV=2db7f6f069a526c101e5d87c7d92c40b77d5ffe7
git init -q /opt/omapixicon
git -C /opt/omapixicon fetch -q --depth 1 https://github.com/xenxaarn/omapixicon.git "$OMAPIXICON_REV"
git -C /opt/omapixicon checkout -q FETCH_HEAD
python3 /opt/omapixicon/engine/render.py --out /usr/share/icons/OmaPixIcon --inherits Adwaita,hicolor
rm -rf /opt/omapixicon
printf "[org/gnome/desktop/interface]\nicon-theme='OmaPixIcon'\n" >/etc/dconf/db/local.d/02-icons

if command -v dconf >/dev/null 2>&1; then
  dconf update
fi

firewall-offline-cmd --add-service=kdeconnect || echo "WARN: kdeconnect firewall rule not applied"
systemctl enable \
  gdm \
  NetworkManager \
  bluetooth \
  power-profiles-daemon \
  firewalld \
  flatpaks \
  glacier-branding.service \
  glacier-branding.path
systemctl set-default graphical.target

rm -f /etc/machine-id
echo 'uninitialized' >/etc/machine-id
rm -f /var/lib/systemd/random-seed

echo "GRUB_DEFAULT=saved" >>/etc/default/grub
echo "GRUB_DISABLE_SUBMENU=true" >>/etc/default/grub
echo "GRUB_DISABLE_RECOVERY=true" >>/etc/default/grub

passwd -d root
passwd -l root

touch /var/lib/rpm/.updated
touch /var/lib/rpm/.rpmdb

ln -sf /usr/bin/nvim /usr/local/bin/neovim
if [ -f /etc/skel/.config/nvim/lazy-lock.json ]; then
  lazy_cmd="Lazy! restore"
else
  lazy_cmd="Lazy! sync"
fi
XDG_CONFIG_HOME=/etc/skel/.config XDG_DATA_HOME=/etc/skel/.local/share XDG_STATE_HOME=/tmp/nvs XDG_CACHE_HOME=/tmp/nvc nvim --headless "+$lazy_cmd" +qa
rm -rf /tmp/nvs /tmp/nvc
test -d /etc/skel/.local/share/nvim/lazy/LazyVim
chmod 0755 /usr/bin/glacier-install
echo "Glacier image configuration complete"
