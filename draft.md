I recently moved from Ubuntu to MacOS and in the process I made several changes
to my dotfiles to make them work. But I wasn't happy with the result, specially
because `zsh` initialization time ended up being 3-4s. That doesn't seem like
much but for someone that works mostly on the terminal (alacritty, tmux & vim) is a deal breaker.

So I decided to look into the problem and find a way to optimize my zsh init time.

It makes sense to describe a bit what I had in my dotfiles.

- [Antibody](#) as the loader of plugins.
- Several [oh-my-zsh](#) plugins, most of them I didn't use.
- A custon zsh plugin I built to have _directory based aliases_. I use it mostly to have project related commands (which are usually the same command with a few different tweaks: e.g. different projects requiren spinning up a server in different ways but they all have the same "run-server" alias).
- zsh syntax highligh
- zsh suggestions
- [purs](#) as the prompt, which is also quite fast

The first attempt was to remove a few things from my Antibody plugin list. But sadly it wasn't that much of an improvemnt. I didn't know yet how slow my dir_alias plugin was.

After googling for a bit I found out these two articles which basically had all I needed to optimize zsh init time properly.

- [Speeding up my ZSH load](https://carlosbecker.com/posts/speeding-up-zsh/)
- [How to debug zsh startup time](https://blog.askesis.pl/post/2017/04/how-to-debug-zsh-startup-time.html)

### Debugging zsh initialization

I found very useful to be able to debug and profile zsh. Instead of guessing what could be taking so much time.

**Check zsh init time N times**

```zsh
$ repeat 10 {/usr/bin/time zsh -i -c exit}
```

This is useful to find the mean time your zsh takes to initialize. As I said, In
my case it was around 3-4s.

**Debug mode**

Prints everything that runs during initialization. This is helpful to see what
sort of things are part of your zsh initialziation. I didn't make much use of it
but can be handy if you want to make further, more granular improvements.

```zsh
$ zsh -i -v
```

**Profiling**

This was by far the more useful thing I learned about zsh.

Add this line to the top of your `~/.zshrc`:

```zsh
zmodload zsh/zprof
```

And this line to the end, after anything else:

```zsh
zprof
```

Or if you want to play around with the output dump it in a file:

```
zprof > ~/zsh-profiling.txt
```

This will output a table with the top ten slowest commands run during initialization, sorted by the time they took.

```
num  calls                time                       self                name
-----------------------------------------------------------------------------------
 1)    3        10.15    10.15   15.22%     10.15    10.15   15.22%   command_name
 ...
```

### The slow ones

After profiling I found out that my dir_alias plugin was quite slow. It uses a zsh hook to run whenever a directory changes, it checks if the current directory or any parent one contain `.aliasfile`, sets the aliases from them and also cleans up the ones from the previous directory. Which is quite slow done in bash. So, good by friend :wave:

But `compaudit` & `compinit` were the slowest ones in my case. They are used to setup completion. Which is something I was not ready to give up. But there's something that can be done. `compinit` reads `~/.zcompdump` every time, which can be changed to only check it once a day.

```zsh
# Take from:  https://gist.github.com/ctechols/ca1035271ad134841284
# Adapted by: https://carlosbecker.com/posts/speeding-up-zsh/

autoload -Uz compinit
if [ $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]; then
  compinit
else
  compinit -C
fi
```

These were the two changes that made the most improvements. Besides that I removed a few other plugins that wasn't using, added a function to lazy load some programs that I rearely use ([code here](#)) and tiddied? up a bit my zsh.

Now my init time is around 170-180ms. That's something I can live with :racing_car: :tada:

## References

Most of the things I share here are taken from these two articles:

- [Speeding up my ZSH load](https://carlosbecker.com/posts/speeding-up-zsh/)
- [How to debug zsh startup time](https://blog.askesis.pl/post/2017/04/how-to-debug-zsh-startup-time.html)
