#!/bin/bash

set -e

VERDE='\033[0;32m'
NC='\033[0m'
MK_CONF="/etc/mkinitcpio.conf"
LOADER_DIR="/boot/loader/entries"

sudo -v

if [ "$EUID" -eq 0 ]; then
  echo "Execute o script como usuário comum."
  exit 1
fi

CACHE="$HOME/.cache/script_arch"
rm -rf "$CACHE"
mkdir -p "$CACHE"

PKGS_PACMAN=(
    base-devel adw-gtk-theme discord btop steam gamemode mangohud ryujinx 
    android-tools scrcpy faugus-launcher pcsx2 snes9x dolphin-emu 
    cemu drawing clapper telegram-desktop qbittorrent impression 
    lact-libadwaita gparted dconf-editor gdm-settings zed ghostty 
    nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils 
    nvidia-settings linux-zen-headers gstreamer-vaapi 
    noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions 
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions 
    git npm ffmpegthumbnailer nautilus-open-any-terminal plymouth fastfetch bibata-cursor-theme
)

PKGS_FLATPAK=(
    io.gitlab.theevilskeleton.Upscaler org.onlyoffice.desktopeditors 
    org.gnome.gitlab.somas.Apostrophe org.vinegarhq.Sober 
    io.mrarm.mcpelauncher com.dec05eba.gpu_screen_recorder 
    com.cassidyjames.clairvoyant io.github.jeffshee.Hidamari 
    com.vysp3r.ProtonPlus it.mijorus.gearlever com.github.tchx84.Flatseal 
    org.nickvision.tubeconverter io.github.vikdevelop.SaveDesktop 
    com.mattjakeman.ExtensionManager
)

echo -e "${VERDE}Configurando Chaotic-AUR...${NC}"
if ! pacman -Qi chaotic-keyring &> /dev/null; then
    cd "$CACHE"
    git clone https://github.com/SharafatKarim/chaotic-AUR-installer.git
    cd chaotic-AUR-installer && sudo ./install.bash
    cd "$CACHE"
fi

echo -e "${VERDE}Atualizando sistema e instalando pacotes pacman...${NC}"
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

echo -e "${VERDE}Configurando Ghostty...${NC}"
mkdir -p "$HOME/.config/ghostty"
cat << 'EOF' > "$HOME/.config/ghostty/config"
theme = Adwaita Dark
font-size = 11
window-padding-x = 8
window-height = 24
window-width = 70
confirm-close-surface = false
EOF

echo -e "${VERDE}Configurando ZSH (Pure, History, Plugins)...${NC}"
sudo chsh -s "$(which zsh)" "$USER"
mkdir -p "$HOME/.zsh"
if [ ! -d "$HOME/.zsh/pure" ]; then
    git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
fi

cat << 'EOF' > "$HOME/.zshrc"
# Histórico
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space

# Pure Prompt
fpath+=$HOME/.zsh/pure
autoload -U promptinit; promptinit
prompt pure

# Autocomplete (ZSH completions)
autoload -Uz compinit
compinit

# Plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
EOF

echo -e "${VERDE}Habilitando serviços...${NC}"
sudo systemctl enable --now switcheroo-control.service

echo -e "${VERDE}Instalando pacotes Flatpak...${NC}"
flatpak install flathub "${PKGS_FLATPAK[@]}" -y

echo -e "${VERDE}Configurando temas Flatpak e overrides...${NC}"
flatpak install org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark -y
sudo flatpak override --filesystem=xdg-data/themes
sudo flatpak override --filesystem=xdg-config/gtk-3.0
sudo flatpak override --filesystem=xdg-config/gtk-4.0
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface color-scheme 'default'

echo -e "${VERDE}Instalando MoreWaita, Adwaita Colors e Lucidglyph...${NC}"
cd "$CACHE"
git clone https://github.com/somepaulo/MoreWaita.git
cd MoreWaita && sudo ./install.sh
gsettings set org.gnome.desktop.interface icon-theme 'MoreWaita'
cd "$CACHE"
git clone --depth 1 https://github.com/maximilionus/lucidglyph
cd lucidglyph && sudo ./lucidglyph.sh install
cd "$CACHE"
git clone https://github.com/dpejoh/Adwaita-colors
cd Adwaita-colors
sudo ./setup -i
sudo ./morewaita.sh

echo -e "${VERDE}Instalando Plymouth${NC}"
sudo sed -Ei '/^HOOKS=/ { /plymouth/! s/(udev)/\1 plymouth/ }' "$MK_CONF"

if [ -d "$LOADER_DIR" ]; then
    for conf in "$LOADER_DIR"/*.conf; do
        [ -f "$conf" ] && grep -q "^options" "$conf" || continue

        grep -q "quiet" "$conf"  || sudo sed -i '/^options/ s/$/ quiet/' "$conf"
        grep -q "splash" "$conf" || sudo sed -i '/^options/ s/$/ splash/' "$conf"
        
        echo " -> Configurado: $(basename "$conf")"
    done
else
    echo "Diretório $LOADER_DIR não encontrado. Pulando bootloader."
fi

echo "Regenerando initramfs..."
sudo mkinitcpio -P

echo -e "${VERDE}Instalando o tema ${NC}"
paru -S --noconfirm plymouth-theme-arch-darwin
sudo plymouth-set-default-theme -R arch-darwin

echo -e "${VERDE}Limpando arquivos temporários...${NC}"
rm -rf "$CACHE"

echo -e "${VERDE}------------------------------------------${NC}"
echo "Instalação finalizada."
read -p "Deseja reiniciar o sistema? (s/n): " resposta

if [[ "$resposta" =~ ^[Ss]$ ]]; then
    systemctl reboot
fi
