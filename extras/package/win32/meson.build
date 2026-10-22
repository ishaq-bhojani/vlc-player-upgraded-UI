# TODO handle msi packaging

# Vireo: README.txt and RELEASE-NOTES.txt are Vireo's own (this directory); VLC's authors and
# thanks files stay (GPL credit) under names that say whose they are; VLC's NEWS is not shipped.
install_data('../../../COPYING',   rename : 'COPYING.txt',      install_dir : '.')
install_data('README.txt',         install_dir : '.')
install_data('RELEASE-NOTES.txt',  install_dir : '.')
install_data('../../../AUTHORS',   rename : 'VLC-AUTHORS.txt',  install_dir : '.')
install_data('../../../THANKS',    rename : 'VLC-THANKS.txt',    install_dir : '.')
# Vireo: licence of the bundled Inter font; the installer picks up *.txt
install_data('../../../modules/gui/qt/redesign/assets/fonts/OFL.txt', rename : 'Inter-OFL.txt', install_dir : '.')

install_data('../../../share/icons/vireo.ico',  install_dir : '.')

have_win64 = host_machine.cpu_family() == 'x86_64' or host_machine.cpu_family() == 'aarch64' or host_machine.cpu() == 'arm64'
if have_win64
    if host_machine.cpu_family() == 'aarch64'
        winstaller_suffix = 'winarm64'
    else
        winstaller_suffix = 'win64'
    endif
else
    if host_machine.cpu_family() == 'arm'
        winstaller_suffix = 'winarm'
    else
        winstaller_suffix = 'win32'
    endif
endif

if get_option('nsis').disable_auto_if(
    host_system != 'windows' or have_win_store).allowed()
    subdir('NSIS')
endif

if get_option('wix').disable_auto_if(
    host_system != 'windows' or have_win_store).allowed()
    subdir('msi')
endif
