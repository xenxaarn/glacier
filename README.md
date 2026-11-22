# Glacier
 
A minimal, dark-themed GNOME desktop built on **Fedora 45**.
Try it live from a USB stick, or install it to disk as a normal, updatable
Fedora system (`dnf5` + Flatpak).
 
![home](images/home.png)
![menu](images/menu.png)
 
## Features
 
- Fedora 45 with GNOME 51
- Dark theme: `adw-gtk3-dark`, Inter, JetBrains Mono, OmaPixIcon icons
- Kitty terminal, a pinned dock, and GNOME Shell extensions: Blur my Shell, RunCat, Clipboard History, Caffeine, Dash to Dock, GSConnect
- Neovim with LazyVim ready to use
- Discord and RustDesk from Flathub, installed automatically on first boot (needs a network connection)
- Boots on UEFI and BIOS machines (x86_64)
## Included apps
 
Firefox, VLC, Loupe, Kitty, Nautilus, Neovim, Lazygit, Btop, Fastfetch, Marknote, and more.
 
## Editions
 
| | Minimal | Dev |
| --- | :---: | :---: |
| Desktop and apps | ✓ | ✓ |
| Git, Python 3, gcc, make, curl, wget | ✓ | ✓ |
| g++, clang, cmake, ninja, gdb, lldb, valgrind, pip, Python and OpenSSL headers | | ✓ |
 
## Download
 
Get an ISO and `SHA256SUMS` from the
[Releases](https://github.com/xenxaarn/glacier/releases) page, then verify it:
 
```sh
sha256sum -c SHA256SUMS --ignore-missing
```
 
## Building from source
 
Requires Podman or Docker:
 
```sh
./build.sh                  # minimal edition
./build.sh --profile dev    # dev edition
```
 
Other modes: `--native` (on a Fedora host) and `--boxbuild`.
The ISO and a `SHA256SUMS` file are written to `output/`.
 
## License
 
[MIT](LICENSE)
 
