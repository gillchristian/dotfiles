- [Safer bash scripts with 'set -euxo pipefail'](https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/)

---

Things missing

- [ ] fzf
- [ ] antibody installation (installs in the current dir, on ./bin)
- [ ] purs installation
- [ ] PureScript installation
- [ ] Nix installation?
- [ ] Cleanup of things that aren't used anymore (k8s, minikube, etc)
- [ ] `tool-sync` installation and link of config file
- [ ] Extend the `env-tools` & add installation for it
- [ ] Add [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)

## 2022-11-09

### Rust & OpenSSL

OpenSSL v3.x.x doesn't work with Rust.

The steps from <https://askubuntu.com/a/1407024> > _Old version of this article_

This also required pointing Rust to the right directory

```sh
OPENSSL_DIR=/usr/local/ssl cargo build --release
```

There was another OpenSSL problem.

```
libssl.so.1.1: cannot open shared object file: No such file or directory
```

```bash
wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb

sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
```

Reference: <https://stackoverflow.com/questions/72133316/ubuntu-22-04-libssl-so-1-1-cannot-open-shared-object-file-no-such-file-or-di>

### Key bindings

To set the AltGr modifier for Intl characters (like `ñ`) I the following works:

_Settings > keyboard > + > English (United States) > "English (intl., with AltGr dead keys)"_

Reference: <https://askubuntu.com/questions/1420153/english-international-with-altgr-in-ubuntu-22-04-lts>

And for making Caps Lock to be Ctrl

> Install and use `gnome-tweaks` > Keyboard & Mouse > Keyboard > Additional Layout Options > Caps Lock behavior._

Reference: <https://askubuntu.com/questions/33774/how-do-i-remap-the-caps-lock-and-ctrl-keys>

### Installing AppImage as desktop apps

[Obsidian](https://obsidian.md/) provides an `AppImage` format for their installation.

The file can be executed directly and it will run the program, but it won't show as an application.

Adding a `.desktop` file to `~/.local/share/applications` solves the problem.

Here's the file:

```toml
[Desktop Entry]
Type=Application
Name=Obsidian
Comment="A second brain, for you, forever."
Icon=/home/bb8/Applications/Obsidian/icon.png
Exec=/home/bb8/Applications/Obsidian/obsidian
Terminal=false
```

To validate and install the file run:

```bash
$ desktop-file-validate ~/.local/share/applications/Obsidian.desktop
$ sudo update-desktop-database
```

Reference: <https://askubuntu.com/a/907572> & <https://askubuntu.com/a/805143>

### Installing Java xD

https://www.youtube.com/watch?v=F1fh4W_TXa8 => the update alternative part is also required
