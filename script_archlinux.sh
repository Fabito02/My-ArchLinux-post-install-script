#!/bin/bash

set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'
MK_CONF="/etc/mkinitcpio.conf"
LOADER_DIR="/boot/loader/entries"
CACHE="$HOME/.cache/script_arch"
PAMAC_RULE_PATH="/etc/polkit-1/rules.d/99-pamac.rules"
TEMPLATE_DIR=$(xdg-user-dir TEMPLATES)

OPT_NVIDIA=false
OPT_INTEL=false
OPT_UNDERVOLT_INTEL=false
OPT_LOW_RES=false

help() {
    echo -e "${BLUE}Uso do Script Pós-Instalação Arch Linux${NC}"
    echo ""
    echo "Opções:"
    echo "  -n,  --nvidia             Instala os drivers proprietários da Nvidia"
    echo "  -i,  --intel              Aplica a otimizações específicas para processadores Intel"
    echo "  -uv, --undervolt-intel    Aplica undervolt para processadores Intel"
    echo "  -lr, --low-res            Ajusta tamanho do cursor e UI para telas menores"
    echo "  -h,  --help               Mostra o menu de ajuda e sai"
    echo ""
    echo "Exemplo: ./script.sh -n -i -lr"
    exit 0
}

if [ "$#" -eq 0 ]; then
    sleep 0.2
    clear
    
    echo -e "${BLUE}Nenhum argumento fornecido. Iniciando modo interativo...${NC}"
    echo "Responda com 's' para sim ou aperte Enter para pular (não)."
    echo "------------------------------------------------------------"

    read -p " -> Instalar drivers proprietários da Nvidia? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_NVIDIA=true

    read -p " -> Aplicar otimizações para processadores Intel? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_INTEL=true

    read -p " -> Aplicar undervolt para processadores Intel? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_UNDERVOLT_INTEL=true

    read -p " -> Ajustar tamanho do cursor e UI para telas menores? (s/N): " resp
    [[ "$resp" =~ ^[SsYy]$ ]] && OPT_LOW_RES=true

    echo -e "------------------------------------------------------------\n"
else
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n|--nvidia) OPT_NVIDIA=true ;;
            -i|--intel) OPT_INTEL=true ;;
            -uv|--undervolt-intel) OPT_UNDERVOLT_INTEL=true ;;
            -lr|--low-res) OPT_LOW_RES=true ;;
            -h|--help) help ;;
            *) echo -e "${RED}Erro: Parâmetro desconhecido: $1${NC}"; exit 1 ;;
        esac
        shift
    done
fi

if [ "$EUID" -eq 0 ]; then
  echo "Execute o script como usuário comum."
  exit 1
fi

sudo -v

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
trap 'kill $(jobs -p)' EXIT

# --nvidia
NVIDIA_PKGS=()
if [ "$OPT_NVIDIA" = true ]; then
    echo -e "\n${BLUE}Configuração do Driver NVIDIA${NC}"
    echo "1) Instalar Driver Atual (nvidia-dkms)"
    echo "2) Instalar Driver Legado (nvidia-580xx-dkms)"
    read -p "Escolha a versão do driver (1 ou 2): " nv_escolha

    if [ "$nv_escolha" = "1" ]; then
        NVIDIA_PKGS=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings)
    elif [ "$nv_escolha" = "2" ]; then
        NVIDIA_PKGS=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-580xx-settings)
    else
        echo "Opção inválida. Pulando instalação dos drivers Nvidia."
    fi
fi

UV_VAL=""
if [ "$OPT_UNDERVOLT_INTEL" = true ]; then
    echo -e "\n${RED}==================================================================================${NC}"
    echo -e "${RED}AVISO: VALORES MUITO GRANDES PODEM GERAR TRAVAMENTO IMEDIATO E KERNEL PANIC${NC}"
    echo -e "${RED}==================================================================================${NC}"
    echo "Faça isso por sua conta e risco. É altamente recomendado que faça testes antes, para garantir que não acabe danificando o seu sistema."
    read -t 20 -p "Digite o valor em mV (ex: -50) ou Enter para cancelar: " UV_VAL || UV_VAL=""
    
    if [[ ! "$UV_VAL" =~ ^-[0-9]+$ ]]; then
        echo " -> Valor inválido ou vazio. Undervolt desativado."
        UV_VAL=""
    fi
fi

rm -rf "$CACHE"
mkdir -p "$CACHE"

PKGS_PACMAN=(
    base-devel adw-gtk-theme discord btop steam gamemode mangohud ryujinx 
    android-tools scrcpy faugus-launcher snes9x dolphin-emu drawing 
    qbittorrent impression flatpak firefoxpwa telegram-desktop 
    lact gparted dconf-editor gdm-settings zed ghostty ufw linux-zen 
    linux-zen-headers noto-fonts-cjk noto-fonts-emoji paru zsh zsh-completions 
    switcheroo-control zsh-syntax-highlighting zsh-autosuggestions 
    npm ffmpegthumbnailer plymouth fastfetch zram-generator tuned tuned-ppd
    bibata-cursor-theme pamac bazaar fuse zen-browser chromium lsfg-vk eden-git 
    extension-manager refine supertuxkart libgda6 geary github-cli 
    ghostty-nautilus valent-git gnome-boxes amberol mangojuice fractal newsflash
    cups cups-pdf cups-filters 
)

PKGS_FLATPAK=(
    io.gitlab.theevilskeleton.Upscaler org.onlyoffice.desktopeditors 
    org.gnome.gitlab.somas.Apostrophe org.vinegarhq.Sober 
    io.mrarm.mcpelauncher com.dec05eba.gpu_screen_recorder 
    com.cassidyjames.clairvoyant io.github.jeffshee.Hidamari 
    it.mijorus.gearlever com.github.tchx84.Flatseal 
    org.nickvision.tubeconverter io.github.vikdevelop.SaveDesktop 
    io.missioncenter.MissionCenter io.github.nozwock.Packet
    io.github.diegopvlk.Cine io.github.amit9838.mousam 
    com.pojtinger.felicitas.Sessions io.github.fabrialberio.pinapp
)

PKGS_AUR=(
    gnome-shell-extension-valent-git cemu-bin morewaita-icon-theme-git mixtapes-git pcsx2-latest-bin
)

if [ ${#NVIDIA_PKGS[@]} -gt 0 ]; then
    PKGS_PACMAN+=("${NVIDIA_PKGS[@]}")
fi

if [ "$OPT_UNDERVOLT_INTEL" = true ]; then
    PKGS_PACMAN+=(intel-undervolt)
fi

echo -e "${BLUE}Configurando Chaotic-AUR...${NC}"
sudo pacman-key --recv-key 3056513887B78AEB
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
fi

sudo pacman -Sy

echo -e "${BLUE}Atualizando sistema e instalando pacotes pacman e aur...${NC}"
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

echo -e "${BLUE}Instalando pacotes Flatpak...${NC}"
sudo flatpak install flathub "${PKGS_FLATPAK[@]}" -y

echo -e "${BLUE}Instalando pacotes AUR...${NC}"
paru -S --needed --noconfirm "${PKGS_AUR[@]}"

echo -e "${BLUE}Removendo aplicativos não utilizados...${NC}"
INSTALLED=$(pacman -Qq decibels showtime gnome-music gnome-console epiphany gnome-software gnome-weather yelp gnome-user-docs gnome-tour htop 2>/dev/null || true)

if [ -n "$INSTALLED" ]; then
    echo "$INSTALLED" | sudo pacman -Rns - --noconfirm
else
    echo " -> Nenhum dos aplicativos alvos está instalado. Pulando remoção."
fi

if [ -f "$HOME/.local/share/applications/org.gnome.Extensions.desktop" ]; then
    echo "O Gnome Extensions já está oculto."
elif [ -f "/usr/share/applications/org.gnome.Extensions.desktop" ]; then
    mkdir -p "$HOME/.local/share/applications/"
    cp /usr/share/applications/org.gnome.Extensions.desktop "$HOME/.local/share/applications/"
    echo "NoDisplay=true" >> "$HOME/.local/share/applications/org.gnome.Extensions.desktop"
else
    echo "Aviso: Atalho original do Extensions não encontrado. Pulando."
fi

echo -e "${BLUE}Configurando Ghostty...${NC}"
mkdir -p "$HOME/.config/ghostty"
cat << 'EOF' > "$HOME/.config/ghostty/config"
theme = light:Adwaita,dark:Adwaita Dark
font-size = 11
window-padding-x = 8
window-height = 24
window-width = 70
gtk-titlebar-style = tabs
gtk-wide-tabs = false
gtk-custom-css = ~/.config/ghostty/styles.css
background-opacity = 1
alpha-blending = native
background-opacity = 0
EOF

cat << 'EOF' > "$HOME/.config/ghostty/styles.css"
/* Habilita suporte ao tema tinted da extensão GNOME ChromaLeon */
@import url("/home/fabito02/.config/gtk-4.0/custom-accent.css");

window{ 
    background: @view_bg_color;
}

revealer.raised.top-bar {
    box-shadow: none;
    border: none;
}

scrolledwindow > widget > tabgrid,
toolbarview > overlay,
windowhandle {
    background-color: @view_bg_color;
}
EOF

echo -e "${BLUE}Configurando ZSH (Pure, History, Plugins)...${NC}"
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

echo -e "${BLUE}Criando arquivos modelo...${NC}"

if [ -d "$TEMPLATE_DIR" ]; then
    touch "$TEMPLATE_DIR/Documento de Texto.txt"
    touch "$TEMPLATE_DIR/Documento Markdown.md"
    
    echo -e "#!/bin/bash\n\necho \"Hello, World!\"" > "$TEMPLATE_DIR/Script Bash.sh"
    chmod +x "$TEMPLATE_DIR/Script Bash.sh"
    
    echo -e "#!/usr/bin/env python3\n\nprint(\"Hello, World!\")" > "$TEMPLATE_DIR/Script Python.py"
    chmod +x "$TEMPLATE_DIR/Script Python.py"
    
    cat << 'EOF' > "$TEMPLATE_DIR/Atalho de Aplicativo.desktop"
[Desktop Entry]
Type=Application
Name=Nome do App
Exec=caminho_do_executavel
Icon=caminho_do_icone
Terminal=false
Categories=Utility;
EOF

    echo " -> Modelos criados com sucesso em: $TEMPLATE_DIR"
else
    echo "Aviso: Pasta de modelos não encontrada pelo XDG. Pulando."
fi

echo -e "${BLUE}Configurando Interface e Temas...${NC}"
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
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.shell always-show-log-out true

if [ "$OPT_LOW_RES" = true ]; then
    gsettings set org.gnome.desktop.interface cursor-size 20
fi

cd "$CACHE"
git clone --depth 1 https://github.com/maximilionus/lucidglyph
cd lucidglyph && sudo ./lucidglyph.sh install
cd "$CACHE"

echo -e "${BLUE}Configurando Plymouth e Parâmetros do Kernel${NC}"
sudo sed -Ei '/^HOOKS=/ { /plymouth/! s/(udev)/\1 plymouth/ }' "$MK_CONF"

if [ -d "$LOADER_DIR" ]; then
    for conf in "$LOADER_DIR"/*.conf; do
        [ -f "$conf" ] && grep -q "^options" "$conf" || continue
        
        if [ "$OPT_INTEL" = true ]; then
            grep -q "intel_pstate=passive" "$conf"  || sudo sed -i '/^options/ s/$/ intel_pstate=passive/' "$conf"
        fi
        grep -q "quiet" "$conf"  || sudo sed -i '/^options/ s/$/ quiet/' "$conf"
        grep -q "splash" "$conf" || sudo sed -i '/^options/ s/$/ splash/' "$conf"
        sudo systemctl enable --now cups
        echo " -> Configurado: $(basename "$conf")"
    done
else
    echo "Diretório $LOADER_DIR não encontrado. Pulando bootloader."
fi

echo -e "${BLUE}Instalando o tema Plymouth${NC}"
paru -S --noconfirm plymouth-theme-arch-darwin
sudo plymouth-set-default-theme -R arch-darwin

echo -e "${BLUE}Habilitando NTSYNC (Para jogos Windows via Proton/Wine)${NC}"
echo "ntsync" | sudo tee /etc/modules-load.d/ntsync.conf

echo -e "${BLUE}Configurando Polkit rule para Pamac${NC}"
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

echo -e "${BLUE}Configurando ZRAM...${NC}"
echo -e "[zram0]\nzram-size = ram\ncompression-algorithm = zstd" | sudo tee /etc/systemd/zram-generator.conf > /dev/null

if [ -n "$UV_VAL" ]; then
    echo -e "${BLUE}Aplicando arquivo de configuração do Undervolt...${NC}"
    sudo cp /etc/intel-undervolt.conf /etc/intel-undervolt.conf.bak
    sudo sed -i "s/^undervolt 0.*/undervolt 0 'CPU' ${UV_VAL}/" /etc/intel-undervolt.conf
    sudo sed -i "s/^undervolt 2.*/undervolt 2 'CPU Cache' ${UV_VAL}/" /etc/intel-undervolt.conf
    sudo systemctl enable --now intel-undervolt.service
    sudo intel-undervolt apply
fi

echo -e "${BLUE}Configurando Protocolo TCP BBR para melhor desempenho de Rede...${NC}"
echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf > /dev/null
echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" | sudo tee /etc/sysctl.d/bbr.conf > /dev/null
echo " -> Módulo tcp_bbr e configurações sysctl aplicadas com sucesso."

echo -e "${BLUE}Configurando Segurança e Habilitando Serviços...${NC}"
# UFW e KDE Connect
sudo systemctl enable --now ufw.service
sudo ufw allow 1714:1764/udp
sudo ufw allow 1714:1764/tcp
sudo ufw --force enable

# Outros Serviços
sudo systemctl daemon-reload
sudo systemctl enable --now switcheroo-control.service
sudo systemctl enable --now tuned
sudo systemctl enable --now fstrim.timer
sudo systemctl enable --now cups

echo -e "${BLUE}Limpando arquivos temporários...${NC}"
rm -rf "$CACHE"
echo -e "${BLUE}------------------------------------------${NC}"
echo -e "${GREEN}Instalação finalizada. Algumas funções e otimizações entrarão em vigor após reinício.${NC}"
read -p "Deseja reiniciar o sistema? (s/n): " resposta

if [[ "$resposta" =~ ^[SsYy]$ ]]; then
    systemctl reboot
fi
