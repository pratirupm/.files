# Thin wrappers over bin/dotfiles. All logic lives in bin/dotfiles.

dotfiles-install() { command dotfiles install "$@" }
dotfiles-update() { command dotfiles update "$@" }
dotfiles-upgrade() { command dotfiles upgrade "$@" }
dotfiles-uninstall() { command dotfiles uninstall "$@" }
dotfiles-doctor() { command dotfiles doctor "$@" }
dotfiles-status() { command dotfiles status "$@" }
