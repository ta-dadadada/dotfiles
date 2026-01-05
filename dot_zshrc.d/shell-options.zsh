# Shell options and history configuration

# Basic options
setopt AUTO_CD           # cd by typing directory name
setopt AUTO_PUSHD        # Make cd push the old directory onto the directory stack
setopt PUSHD_SILENT      # Don't print the directory stack after pushd or popd
setopt EXTENDED_GLOB     # Use extended globbing syntax
setopt HIST_IGNORE_DUPS  # Don't record an entry that was just recorded again
setopt SHARE_HISTORY     # Share history between all sessions

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# Enable colors
autoload -Uz colors && colors

