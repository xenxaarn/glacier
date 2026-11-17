#!/bin/bash

set -euxo pipefail

test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

sed -i \
	-e 's/^NAME=.*/NAME="Glacier"/' \
	-e 's/^PRETTY_NAME=.*/PRETTY_NAME="Glacier"/' \
	/usr/lib/os-release

EXT_LIST="/usr/share/glacier/extensions.txt"
if [ -f "$EXT_LIST" ]; then
	gnome_shell_version=$(rpm -q --qf '%{VERSION}' gnome-shell)
	gnome_shell_major=${gnome_shell_version%%.*}
	ext_dir=/usr/share/gnome-shell/extensions
	installed_list=""

	while read -r uuid; do
		case "$uuid" in
			''|'#'*) continue ;;
		esac
		info=$(curl -sS "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$gnome_shell_major" 2>/dev/null || true)
		dl_url=$(printf '%s' "$info" | python3 -c \
			'import sys,json
s=sys.stdin.read()
print(json.loads(s).get("download_url","") if s.lstrip().startswith("{") else "")' 2>/dev/null || true)

		if [ -z "$dl_url" ]; then
			echo "SKIP $uuid: no build for shell $gnome_shell_major or offline"
			continue
		fi

		curl -fsSL -o /tmp/glacier-ext.zip "https://extensions.gnome.org$dl_url" \
			&& python3 -m zipfile -e /tmp/glacier-ext.zip "$ext_dir/$uuid" \
			&& [ -d "$ext_dir/$uuid/schemas" ] \
			&& glib-compile-schemas "$ext_dir/$uuid/schemas"

		installed_list="${installed_list:+$installed_list, }'$uuid'"
	done < "$EXT_LIST"

	if [ -n "$installed_list" ]; then
		mkdir -p /etc/dconf/db/local.d
		printf '[org/gnome/shell]\nenabled-extensions=[%s]\n' "$installed_list" \
			> /etc/dconf/db/local.d/01-extensions
	fi
	rm -f /tmp/glacier-ext.zip
fi

if command -v dconf >/dev/null 2>&1; then
	dconf update
fi

systemctl enable \
	gdm \
	NetworkManager \
	bluetooth \
	power-profiles-daemon \
	firewalld \
	flatpaks
systemctl set-default graphical.target

rm -f /etc/machine-id
echo 'uninitialized' > /etc/machine-id
rm -f /var/lib/systemd/random-seed

echo "GRUB_DEFAULT=saved" >> /etc/default/grub
echo "GRUB_DISABLE_SUBMENU=true" >> /etc/default/grub
echo "GRUB_DISABLE_RECOVERY=true" >> /etc/default/grub

passwd -d root
passwd -l root

touch /var/lib/rpm/.updated
touch /var/lib/rpm/.rpmdb

ln -sf /usr/bin/nvim /usr/local/bin/neovim; XDG_CONFIG_HOME=/etc/skel/.config XDG_DATA_HOME=/etc/skel/.local/share XDG_STATE_HOME=/tmp/nvs XDG_CACHE_HOME=/tmp/nvc nvim --headless "+Lazy! sync" +qa; rm -rf /tmp/nvs /tmp/nvc; test -d /etc/skel/.local/share/nvim/lazy/LazyVim
echo "Glacier image configuration complete"
