# my dotfiles

```bash
$ sudo apt-get install git
$ git clone https://github.com/gillchristian/dotfiles.git ~/dev/dotfiles
$ cd ~/dev/dotfiles
$ ./install.sh
```

After that ~hopefully~ goes well, close the terminal and open it again and run this:

```bash
$ cd ~/dev/dotfiles
$ ./postinstall.sh
```

## TODOs

- Test (_maybe inside a Docker container_).
- Report of what went well and what not.
- Improve output & progress.
- Unify `install.sh` and `postinstall.sh` in one script (not not possible
  because `nvm` is installing by zsh plugin when running zsh for the first time).

## Inspiration

[HeroCC's dotfiles](https://github.com/HeroCC/dotfiles).
