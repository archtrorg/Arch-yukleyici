#!/bin/bash

root=$1
boot=$2

set -e

color(){
    case $1 in
        red)
            echo -e "\033[31m$2\033[0m"
        ;;
        yellow)
            echo -e "\033[33m$2\033[0m"
        ;;
    esac
}

config_base(){
    color yellow "Bilgisayar adını girin"
    read TMP
    echo $TMP > /etc/hostname
    color yellow "ROOT parolanızı girin"
    passwd
}

config_locale(){
    color yellow "Lütfen yerel saatinizi seçin"
    select TIME in `ls /usr/share/zoneinfo`;do
        if [ -d "/usr/share/zoneinfo/$TIME" ];then
            select time in `ls /usr/share/zoneinfo/$TIME`;do
                ln -sf /usr/share/zoneinfo/$TIME/$time /etc/localtime
                break
            done
        else
            ln -sf /usr/share/zoneinfo/$TIME /etc/localtime
            break
        fi
        break
    done
    hwclock --systohc --utc
    color yellow "Dilinizi seçin"
    select LNAG in "tr_TR.UTF-8" "en_US.UTF-8";do
        echo "$LNAG UTF-8" > /etc/locale.gen
        locale-gen
        echo LANG=$LANG > /etc/locale.conf
        break
    done
}

install_grub(){
    if (mount | grep efivarfs > /dev/null 2>&1);then
        pacman -S --noconfirm grub efibootmgr -y
	rm -f /sys/firmware/efi/efivars/dump-*
        grub-install --target=`uname -m`-efi --efi-directory=/boot --bootloader-id=Arch
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        pacman -S --noconfirm grub os-prober
        fdisk -l
        color yellow "Grubunu kurmak istediğiniz diski girin (/dev/sdX"
        read TMP
        grub-install --target=i386-pc $TMP
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

install_bootctl(){
    if (mount | grep efivarfs > /dev/null 2>&1);then
        bootctl --path=esp install
        cp /usr/share/systemd/bootctl/loader.conf /boot/loader/
	echo "timeout 4" >> /boot/loader/loader.conf
	echo -e "title          Arch Linux\nlinux          /vmlinuz-linux\ninitrd         /initramfs-linux.img" > /boot/loader/entries/arch.conf

    else
        color yellow "PC'nizin grub için UEFI modunu desteklemedigi anlaşılıyor.Çıkmak için q tuşunu (exit) kullanın."
        read TMP
        if [ "$TMP" == "" ];then
            install_grub
        else
            exit
        fi
    fi
}

install_efistub(){
    UUID=`blkid -s UUID -o value $root`
    efi=`echo $boot | grep -o "[0-9]*"`
    if (mount | grep efivarfs > /dev/null 2>&1);then
        pacman -S --noconfirm efibootmgr
        rm -f /sys/firmware/efi/efivars/dump-*
        efibootmgr --disk $boot --part $efi --create --label "Arch Linux" --loader /vmlinuz-linux --unicode "root=UUID=$UUID rw initrd=\initramfs-linux.img"
    else
        color yellow "Looks like your PC doesn't suppot UEFI or not in UEFI mode ENTER to use grub. Input q to quit"
        read TMP
        if [ "$TMP" == "" ];then
            install_grub
        else
            exit
        fi
    fi
}

add_user(){
    color yellow "Kullanmak istediğiniz kullanıcı adını girin (must be lower case)"
    read USER
    useradd -m -g users -G optical,storage,wheel,video,audio,users,power,network,log -s /bin/bash $USER
    color yellow "Parolanızı girin"
    passwd $USER
    pacman -S --noconfirm sudo
    sed -i 's/\# \%wheel ALL=(ALL) ALL/\%wheel ALL=(ALL) ALL/g' /etc/sudoers
    sed -i 's/\# \%wheel ALL=(ALL) NOPASSWD: ALL/\%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
}

install_graphic(){
    color yellow "Hangi video sürücüsü kurulsun?"
    select GPU in "Intel" "Nvidia" "Intel and Nvidia" "AMD";do
        case $GPU in
            "Intel")
                pacman -S --noconfirm xf86-video-intel -y
                break
            ;;
            "Nvidia")
                color yellow "Hangi versiyon yüklensin"
                select NVIDIA in "GeForce-8 and newer" "GeForce-6/7" "Older";do
                    case $NVIDIA in
                        "GeForce-8 and newer")
                            pacman -S --noconfirm nvidia -y
                            break
                        ;;
                        "GeForce-6/7")
                            pacman -S --noconfirm nvidia-304xx -y
                            break
                        ;;
                        "Older")
                            pacman -S --noconfirm nvidia-340xx -y
                            break
                        ;;
                        *)
                            color red "Hata ! Lütfen doğru numarayı giriniz"
                        ;;
                    esac
                done
                break
            ;;
            "Intel and Nvidia")
                pacman -S --noconfirm bumblebee -y
                systemctl enable bumblebeed
                color yellow "Version of nvidia-driver to install"
                select NVIDIA in "GeForce-8 and newer" "GeForce-6/7" "Older";do
                    case $NVIDIA in
                        "GeForce-8 and newer")
                            pacman -S --noconfirm nvidia -y
                            break
                        ;;
                        "GeForce-6/7")
                            pacman -S --noconfirm nvidia-304xx -y
                            break
                        ;;
                        "Older")
                            pacman -S --noconfirm nvidia-340xx -y
                            break
                        ;;
                        *)
                            color red "Hata ! Lütfen doğru numarayı giriniz"
                        ;;
                    esac
                done
                break
            ;;
            "AMD")
                pacman -S --noconfirm xf86-video-ati -y
                break
            ;;
            *)
                color red "Hata ! Lütfen doğru numarayı giriniz"
            ;;
        esac
    done
}

install_bluetooth(){
    pacman -S --noconfirm bluez
    systemctl enable bluetooth
    color yellow "Blueman yüklensin mi? y)YES ENTER)NO"
    read TMP
    if [ "$TMP" == "y" ];then
        pacman -S --noconfirm blueman
    fi
}

install_app(){
    color yellow "Yaourt yüklensin mi? (Yalnız Çin kullanıcıları için) y)YES ENTER)NO"
    read TMP
    if [ "$TMP" == "y" ];then
        sed -i '/archlinuxcn/d' /etc/pacman.conf
        sed -i '/archlinux-cn/d' /etc/pacman.conf
        select MIRROR in "USTC" "TUNA" "163";do
            case $MIRROR in
                "USTC")
                    echo -e "[archlinuxcn]\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch" >> /etc/pacman.conf
                    break
                ;;
                "TUNA")
                    echo -e "[archlinuxcn]\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch" >> /etc/pacman.conf
                    break
                ;;
                "163")
                    echo -e "[archlinuxcn]\nServer = http://mirrors.163.com/archlinux-cn/\$arch" >> /etc/pacman.conf
                    break
                ;;
                *)
                    color red "Hata ! Lütfen doğru numarayı giriniz"
                ;;
            esac
        done
        pacman -Sy
        pacman -S --noconfirm archlinuxcn-keyring
        pacman -S --noconfirm yaourt
    else
        pacman -S --noconfirm git
        su - $USER -c "cd ~
            git clone https://aur.archlinux.org/package-query.git
            cd package-query&&makepkg -si
            cd ..
            git clone https://aur.archlinux.org/yaourt.git
            cd yaourt&&makepkg -si
            cd ..
            rm -rf package-query yaourt"
        fi
    pacman -S --noconfirm networkmanager xorg-server firefox wqy-zenhei
    systemctl enable NetworkManager
    if [ "$GPU" == "Intel and Nvidia" ];then
        gpasswd -a $USER bumblebee
    fi
}

install_desktop(){
    color yellow "Kullanmak istediğiniz masaüstünü seçin"
    select DESKTOP in "KDE" "Gnome-Minimal" "Gnome" "Lxde" "Lxqt" "Mate" "Xfce" "Deepin" "Budgie" "Cinnamon";do
        case $DESKTOP in
            "KDE")
                pacman -S plasma kdebase kdeutils kdegraphics kde-l10n-tr sddm
                systemctl enable sddm
                break
            ;;
	    "Gnome-Minimal")
	        pacman -S gnome-shell gdm lightdm lightdm-gtk-greeter gnome-terminal gnome-settings-daemon gnome-control-center
		systemctl enable lightdm
		break
	    ;;
            "Gnome")
                pacman -S gnome gnome-terminal
                systemctl enable gdm
                break
            ;;
            "Lxde")
                pacman -S lxde lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            "Lxqt")
                pacman -S lxqt lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            "Mate")
                pacman -S mate mate-extra mate-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            "Xfce")
                pacman -S xfce4 xfce4-goodies xfce4-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            "Deepin")
                pacman -S deepin deepin-extra deepin-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                sed -i '108s/#greeter-session=example-gtk-gnome/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
                break
            ;;
            "Budgie")
                pacman -S budgie-desktop gnome-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            "Cinnamon")
                pacman -S cinnamon gnome-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                break
            ;;
            *)
                color red "Hata ! Lütfen doğru numarayı giriniz"
            ;;
        esac
    done
}

main(){
    config_base
    config_locale
    color yellow "GRUB veya Bootctl tercihiniz ? y)Bootctl ENTER)GRUB"
    read TMP
    if [ "$TMP" == "y" ];then
        install_bootctl
    else
        install_grub
    fi
    add_user
    install_graphic
    color yellow "Bluetooth var mı ? y)YES ENTER)NO"
    read TMP
    if [ "$TMP" == "y" ];then
        install_bluetooth
    fi
    install_app
    install_desktop
    color yellow "Bitti, kullandığınız için teşekkürler"
}

main
