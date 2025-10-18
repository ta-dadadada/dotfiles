## initialize

```sh
brew install fzf peco zoxide ripgrep fd bat jq chezmoi eza gh ghq
$(brew --prefix)/opt/fzf/install
```

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
chezmoi init github_username
chezmoi apply
```

## Aliases

### Modern CLI Tools
- `ls` → `eza` - Modern ls replacement with git integration
- `ll` → `eza -lh --git` - Long format with git status
- `la` → `eza -lha --git` - Long format including hidden files
- `cat` → `bat --paging=never` - Syntax highlighting cat replacement

## Keybindings

- `Ctrl-R` - Fuzzy search command history with fzf
- `Ctrl-T` - Fuzzy find files in current directory and insert to command line
- `Ctrl-G` - Fuzzy select ghq repository and cd into it
- `Alt-C` - Fuzzy find directories and cd into it

## Functions

### FZF-powered utilities
- `ff` - Select files with fzf and open in editor (multi-select)
- `fcd` - Select directory with fzf and cd into it
- `rgf <pattern>` - Ripgrep search and jump to line in editor

### Git utilities
- `gbs` - Git branch switch with fzf preview
- `gco-any` - Select any commit with fzf and checkout (detached)
- `prc` - GitHub PR checkout with gh CLI and fzf

### Other utilities
- `zfcd` - Select from zoxide history with fzf and cd
- `pzkill` - Select process with fzf and kill -9

## Configuration Structure

```
~/.zshenv           # Loads ~/.zshenv.d/*.zsh
~/.zshenv.d/
  ├── homebrew.zsh  # Homebrew PATH
  ├── editor.zsh    # EDITOR, PAGER
  ├── nodejs.zsh    # Node.js settings
  ├── rust.zsh      # Rust settings
  └── tools.zsh     # Development tools

~/.zshrc            # Loads ~/.zshrc.d/*.zsh
~/.zshrc.d/
  ├── shell-options.zsh  # Shell options & history
  ├── aliases.zsh        # Command aliases
  ├── zoxide.zsh         # zoxide integration
  ├── fzf-functions.zsh  # FZF utility functions
  ├── tools.zsh          # Tool integrations (mise, kiro)
  └── starship.zsh       # Prompt configuration

~/.fzf.zsh          # FZF configuration & keybindings
```