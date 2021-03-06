
# core-tools

This is the central module for managing my scripts and tools.

## Useful Features

The core tools hold a number of useful functions.

### Battery

If you are using a laptop, then you can use `battery` to display your remaining battery life.

### Network Connection Listing

You can use the `connections-in` and `connections-out` functions to list all incoming and outgoing network connections not to localhost.

This function have a number of variations (there is also an outgoing version for each incoming version listed. Consider, for example, `connections-in-local` and `connections-out-local`):

* `connections-in-local`: The inverse of `connections-in`, list all connections involving localhost.
* `connections-in-lan`: List incoming connections coming from IP addresses beginning in `10.`, `172.16.` to `172.32.`, or `192.`.
* `connections-in-remote`: The inverse of `connections-in-lan`, lists IPs not beginning in `10.`, `172.16.` to `172.32.`, or `192.168`.
* `connections-in-all`: List all incoming connections. All functions for incoming connections filter the output of this function.
* `connections-lan`: An alias of `connections-out-lan`.

### Prompt

I've added a number of bells and whistles my prompt:

* Dynamic colouring for the following areas:
  * Username changes depending on who the current user is.
  * Hostname:
     * Certain network-only servers have blue hostnames.
     * Servers that I use for a desktop environment have green hostnames.
     * Some development or work machines have red hostnames.
   * File Path:
     * Local filesystems (**ext2**, **ext3**, **ext4**, **xfs**) are green.
     * Network file systems (**nfs**, **cifs**) are blue.
     * OS and memory-based filesystems (**sysfs**, **proc**, any kind of **tmpfs**) are purple.
     * Hot-plugged filesystems (**udf**, **fuseblk**, any kind of **ntfs** or **fat** filesystem) are red.
  * Box edges are set by the output of `uname`:
     * Linux systems are in a blue box.
     * FreeBSD systems are in a red box.
     * Mac OSX systems are in a yellow box.
     * Windows systems using MobaXterm are in a cyan box.
  * Prompt Symbol (**$** for non-root, **#** for root):
     * If the previous command was not found (*exit code 127*), then the symbol will be yellow.
     * If we attempted to run a script without the execute permission (*exit code 126*), then the symbol will by cyan.
     * If the previous command gave a non-zero exit code not covered above, then the symbol will be red.
     * If the previous command exited successfully with an exit code of *0*, then the symbol will be white.
* Remote SSH client.
  * The remote address will not be displayed if your terminal session was started within a `tmux`, `screen`, or `vnc` session.
* SVN version information (Credit: Eric Leblond)
* Git branch and status information (Credit: http://ezprompt.net/)
  * If you need a reminder of what the red indicators on the `git` part of the prompt mean, use `git-prompt-reminder`.
* Compression. If the prompt gets to be so large that you begin running out of room, then the prompt will be shortened:
  * Hostname will be shortened to one character.
  * Username will be shortened to one character.
  * Only the name of the current directory will be displayed.
* Temporary hostname/username display change, useful for when you are debugging or recording demonstration videos.
  * Setting `DISPLAY_USER` will override the display of your session's real username in the prompt.
  * Setting `DISPLAY_HOSTNAME` will override the display of your server's real hostname in the prompt.

#### Variables

If you want to disable all of these bells and whistles, set the `BASIC_PROMPT` variable to **1**.

### rdp

The `rdp` function is made to make the `xfreerdp` command more convenient to use.

It boils down basic usage to a basic `rdp target-server`, whether you are using a older version of `xfreerdp` or a modern one.

If you want to add additional arguments, the second argument to `rdp` and onwards will be passed directly through to `xfreerdp`.

#### Variables

You can set the following envirnoment variables to adjust your RDP resolution:

* `RDP_WIDTH` sets the width of the `rdp` window (default: 1600).
* `RDP_HEIGHT` sets the height of the `rdp` window (default: 900).

### Sleep

A few lazy functions for sleeping (each one only accepts integers):

* `sleep-minutes`
* `sleep-hours`
* `sleep-days`

## Modules

I made a module-based system for storing functions in order to limit unneeded data leaks.

### Module Creation

A directory is considered to be a module if it has a `bash/bashrc` file that defines a tools directory variable.

The tools directory variable must:

* Have a unique amongst the tool directories.
* Draw off of `$__current_module_dir` variable, which is set in the cycling of the `bashrc` file of these core tools that loads in modules.
  * The exception to this is $toolsDir`, which is set in a system bashrc or `~/.bashrc` by the setup script.
    * A number of modules do fall back to guessing at a location, but this is not recommended.
* End in `ToolsDir` (case-insensitive).
    This is necessary because some functions (`ssh-compile-config`, for example)
    actually looks for tool directory variables in order to work.

### Locations

Modules are read out of the following directories:

| Location                                                         | Example(s)                                            |
|------------------------------------------------------------------|-------------------------------------------------------|
| `~/tools` directory                                              | `~/tools`, `~/tools/core-tools`                    |
| `~/work`directory                                                | `~/work/company-a-tools`, `~/work/company-b/tools` |
| `modules`directory, nested within core tools checkout (SVN checkout only) | `modules/sound-tools`                               |
| `secure` directory, nested within core tools checkout (SVN checkout only) | `secure/`                                           |

### History

The original tools were just a single directory stored in SVN in order to avoid having to manually keep my different scripts in sync.

As my needs for my tools expanded, I wanted to start placing them on more systems.
The problem with this was that the original tools directories had some very sensitive material on them, 
    such as network configurations, passwords, and SSH keys.

I originally only had one "*secure*" module, which would be checked out to the `secure/` path within the tools checkout.
The nesting relied on the `svn` command throwing an error if someone tried to add it to tools. Even with `.gitignore` as an option,
    the modern core-tools will not accept nesting in a `git` checkout.

Over time, I needed to split things up even more.
The following kind of problems were not covered by just the main tools and "*secure*" tools:

* Sharing functions/aliases affecting a private resource.
* Needing specific pieces of the "*secure*" tools on a system that I didn't want other information on.
* A lot of functions that would **never** even need to be considered on certain systems. For example:
  * A headless server will never need sound-playing aliases.
  * A headless server or work-oriented machine should never need to load game aliases.
* Work-related information that I did not want to live in any locally hosted repository.

