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

PAMAC_RULE_PATH="/etc/polkit-1/rules.d/99-pamac.rules"

PKGS_PACMAN=(
    base-devel adw-gtk-theme discord btop steam gamemode mangohud ryujinx 
    android-tools scrcpy faugus-launcher pcsx2 snes9x dolphin-emu 
    cemu drawing clapper telegram-desktop qbittorrent impression 
    lact-libadwaita gparted dconf-editor gdm-settings zed ghostty 
    nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils 
    nvidia-580xx-settings linux-zen-headers gstreamer-vaapi firefoxpwa
    noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions 
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions 
    npm ffmpegthumbnailer nautilus-open-any-terminal plymouth fastfetch 
    bibata-cursor-theme pamac bazaar fuse zen-browser lsfg-vk eden-git
)

PKGS_FLATPAK=(
    io.gitlab.theevilskeleton.Upscaler org.onlyoffice.desktopeditors 
    org.gnome.gitlab.somas.Apostrophe org.vinegarhq.Sober 
    io.mrarm.mcpelauncher com.dec05eba.gpu_screen_recorder 
    com.cassidyjames.clairvoyant io.github.jeffshee.Hidamari 
    com.vysp3r.ProtonPlus it.mijorus.gearlever com.github.tchx84.Flatseal 
    org.nickvision.tubeconverter io.github.vikdevelop.SaveDesktop 
    com.mattjakeman.ExtensionManager net.sourceforge.wxEDID io.missioncenter.MissionCenter
    io.github.diegopvlk.Cine
)

echo -e "${VERDE}Configurando Chaotic-AUR...${NC}"
sudo pacman -S git --noconfirm

if ! pacman -Qi chaotic-keyring &> /dev/null; then
    cd "$CACHE"
    git clone https://github.com/SharafatKarim/chaotic-AUR-installer.git
    cd chaotic-AUR-installer && chmod +x install.bash && sudo ./install.bash
    cd "$CACHE"
fi

echo -e "${VERDE}Atualizando sistema e instalando pacotes pacman...${NC}"
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

echo -e "${VERDE}Removendo Gnome Software...${NC}"
if pacman -Qs gnome-software > /dev/null; then
	sudo pacman -Rns gnome-software --noconfirm
else
    echo "O Gnome Software não está instalado."
fi

echo -e "${VERDE}Configurando Ghostty...${NC}"
mkdir -p "$HOME/.config/ghostty"
cat << 'EOF' > "$HOME/.config/ghostty/config"
theme = light:Adwaita,dark:Adwaita Dark
font-size = 11
window-padding-x = 8
window-height = 24
window-width = 70
gtk-titlebar-style = tabs
gtk-wide-tabs = false
gtk-custom-css = ./styles.css
background-opacity = 1
alpha-blending = native
EOF

cat << 'EOF' > "$HOME/.config/ghostty/styles.css"
revealer.raised.top-bar { 
    background: alpha(@view_bg_color, 1); 
    box-shadow: none; 
}
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
flatpak override --user --filesystem=xdg-cache/thumbnails
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
gsettings set org.gnome.desktop.interface color-scheme 'default'
gsettings set org.gnome.shell disable-extension-version-validation true

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

echo -e "${VERDE}Configurando tamanho do cursor e tema Bibata Modern Classic${NC}"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface cursor-size 20

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

echo -e "${VERDE}Instalando o tema Plymouth${NC}"
paru -S --noconfirm plymouth-theme-arch-darwin
sudo plymouth-set-default-theme -R arch-darwin

echo -e "${VERDE}Habilitando NTSYNC (Para jogos Windows via Proton/Wine)${NC}"
echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf

echo -e "${VERDE}Configurando Polkit rule para Pamac${NC}"
if grep -q '^wheel:' /etc/group; then USER_GROUP="wheel"; else USER_GROUP="sudo"; fi

sudo tee $PAMAC_RULE_PATH > /dev/null <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.manjaro.pamac.commit" ||
         action.id == "org.manjaro.pamac.modify") &&
        subject.isInGroup("$USER_GROUP")) {
        return polkit.Result.YES;
    }
});
EOF

echo -e "${VERDE}Limpando arquivos temporários...${NC}"
rm -rf "$CACHE"

echo -e "${VERDE}------------------------------------------${NC}"
echo "Instalação finalizada."
read -p "Deseja reiniciar o sistema? (s/n): " resposta

if [[ "$resposta" =~ ^[Ss]$ ]]; then
    systemctl reboot
fi
