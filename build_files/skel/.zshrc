unset LD_PRELOAD
LD_PRELOAD=""

export PATH=$PATH:$HOME/go/bin:$HOME/.local/bin:$HOME/.npm-global/bin:/home/linuxbrew/.linuxbrew/bin

export ZSH="$HOME/.oh-my-zsh"

if [ "$container" = "podman" ] || [ "$container" = "docker" ]; then
    ZSH_THEME="af-magic"
else
    ZSH_THEME="xiong-chiamiov-plus"
fi

plugins=(git zsh-autosuggestions zsh-syntax-highlighting battery chucknorris colored-man-pages zsh-history-substring-search autoswitch_virtualenv)
RPROMPT='$(battery_pct_prompt)'
BATTERY_CHARGING="⚡️"

source $ZSH/oh-my-zsh.sh

alias brew="/home/linuxbrew/.linuxbrew/bin/brew"

alias updnf="echo 'UPGRADING DNF...'; echo; sudo dnf update -y"
alias upbootc="echo 'UPGRADING BOOTC IMAGE...'; echo; bootc upgrade"
alias upflatpak="echo 'UPGRADING FLATPAK...'; echo; flatpak update"
alias upbrew="echo 'UPGRADING BREW...'; echo; brew upgrade"
alias upall="upbootc; upflatpak; upbrew; echo; echo 'ALL DONE — reboot to apply bootc upgrade :)'"

alias neofetch="fastfetch"

# Distrobox shortcuts
alias dbx='distrobox enter'
alias dbx-export-app='distrobox-export --app'
alias dbx-export-bin='distrobox-export --bin'
alias dbx-ls='distrobox list'

alias rscp='rsync -aP'
alias rsmv='rsync -aP --remove-source-files'

alias findstr="function _findstr() { find \"\$1\" -type f -exec grep -H \"\$2\" {} +; }; _findstr"

# Cloudflare WARP
alias warp-on="sudo systemctl start warp-svc && warp-cli connect"
alias warp-off="warp-cli disconnect && sudo systemctl stop warp-svc"
alias warp-status="warp-cli status"

# mise — per-project language versions (node/python/go/java/…)
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# AUR via Arch distrobox (create first: distrobox assemble create --file /etc/distrobox/arch-aur.ini)
alias aur='distrobox enter arch-aur --'
alias dbx-create-arch='distrobox assemble create --file /etc/distrobox/arch-aur.ini'

command -v chuck_cow >/dev/null 2>&1 && chuck_cow || true

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/bin/terraform terraform 2>/dev/null || true
