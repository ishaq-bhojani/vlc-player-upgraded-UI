#  nsis packaging

nsis_required = get_option('nsis').allowed() and not get_option('nsis').auto()
makensis = find_program('makensis', required: nsis_required)

nsi_conf = configuration_data()
nsi_conf.merge_from(cdata)
nsi_conf.set('BUILD_LUA_TRUE', lua_dep.found() and get_option('lua').allowed() ? '' : ';')
nsi_conf.set('BUILD_SKINS_TRUE', skins2_feasible ? '' : ';')
nsi_conf.set('HAVE_WIN64_TRUE',  have_win64 ? '' : ';')
nsi_conf.set('HAVE_WIN64_FALSE', have_win64 ? ';' : '')
nsi_conf.set('HAVE_ARM64_TRUE',  host_machine.cpu_family() == 'aarch64' or host_machine.cpu() == 'arm64' ? '' : ';')
nsi_conf.set('HAVE_ARM64_FALSE', host_machine.cpu_family() == 'aarch64' or host_machine.cpu() == 'arm64' ? ';' : '')
nsi_conf.set('PROGRAMFILES', have_win64 ? 'PROGRAMFILES64' : 'PROGRAMFILES')
nsi_conf.set('HAVE_NLS_TRUE', nsi_conf.get('ENABLE_NLS', 0) == 1 ? '' : ';')
# Vireo: display version of the installer (Apps & Features); the engine VERSION stays 4.0.0-dev style
nsi_conf.set('REDESIGN_RELEASE_VERSION', get_option('redesign_release_version'))
nsi_conf.set('REDESIGN_BUILD_NUMBER', get_option('redesign_build_number'))
redesign_release_parts = get_option('redesign_release_version').split('.')
assert(redesign_release_parts.length() == 3, 'redesign_release_version must be major.minor.patch')
nsi_conf.set('REDESIGN_RELEASE_MAJOR', redesign_release_parts[0])
nsi_conf.set('REDESIGN_RELEASE_MINOR', redesign_release_parts[1])

nsProcess_cargs = ['-D_UNICODE=1', '-DUNICODE=1']
if not have_win64
    nsProcess_cargs += '-D_WIN32_IE=0x0601'
endif
nsProcess_link_args = ['-static-libgcc']

# TODO use nsis-pluginapi if possible to be compatible with the system makensis
# it provides the matching pluginapi.h and a library to link with

nsProcess_sources = files('nsProcess/nsProcess.c', 'nsProcess/nsis/pluginapi.c')
nsProcess_src = []
nsProcess_obj = []
nsProcess_gcc32 = disabler()
if host_machine.cpu_family() != 'x86'
    # nsProcess.dll needs to be a 32-bit DLL
    # with clang we can link a i686 DLL via -target i686-w64-mingw32
    # Vireo: with gcc (the win64 Docker image) the i686 MinGW-w64 gcc builds and links the DLL itself
    if not cc.has_link_argument(['--target=i686-w64-mingw32'], required: false)
        nsProcess_gcc32 = find_program('i686-w64-mingw32-gcc', required: nsis_required)
    endif
    if cc.has_link_argument(['--target=i686-w64-mingw32'], required: false)
        nsProcess_link_args += '--target=i686-w64-mingw32'

        x86_compiler = generator(find_program('i686-w64-mingw32-gcc'),
          output: ['@BASENAME@.obj'],
          arguments: ['@INPUT@', '-c', '-o', '@OUTPUT@', nsProcess_cargs])

        nsProcess_obj += x86_compiler.process(nsProcess_sources)
    endif
else
    # TODO always use this mode when we switch to a native .exe installer
    # for each architecture
    nsProcess_src = nsProcess_sources
endif
if nsProcess_gcc32.found()
    nsProcess = custom_target('nsProcess',
                              input: [nsProcess_sources, files('nsProcess.def')],
                              output: 'nsProcess.dll',
                              command: [nsProcess_gcc32, '-shared', '-O2', nsProcess_cargs, nsProcess_link_args,
                                        '-o', '@OUTPUT@', '@INPUT@'],
                              install: true,
                              install_dir: 'NSIS')
else
    nsProcess = shared_library('nsProcess',
                               nsProcess_src,
                               c_args: nsProcess_cargs,
                               link_args: nsProcess_link_args,
                               objects: nsProcess_obj,
                               vs_module_defs: 'nsProcess.def',
                               name_prefix: '',
                               link_language: 'c',  # avoid using nasm linker and miss the .dll.a
                               install: true,
                               install_dir: 'NSIS')
endif

vlc_nsi = configure_file(
  input: 'vlc.win32.nsi.in',
  output: 'vlc.win32.nsi',
  configuration: nsi_conf,
  format: 'cmake@',
  install: true,
  install_dir: '.',
)

spad_nsi = configure_file(
  input: 'spad.nsi.in',
  output: 'spad.nsi',
  configuration: nsi_conf,
  format: 'cmake@',
  install: true,
  install_dir: '.',
)

install_data('nsProcess.nsh',    install_dir : 'NSIS')
install_data('vireo_branding.bmp', install_dir : 'NSIS')
# Vireo: the same panel rendered for 125 to 200% display scaling (helpers/vireo_panels.nsh)
install_data('vireo_branding_125.bmp', 'vireo_branding_150.bmp', 'vireo_branding_175.bmp', 'vireo_branding_200.bmp', install_dir : 'NSIS')
install_subdir('languages',      install_dir : '.')
install_subdir('helpers',        install_dir : '.')

if have_win_store
  nsi_script_dir = 'vlc-' + winstaller_suffix + '-uwp'
elif cc.compiles(ucrt_version_test, name: 'compiles with Universal C Runtime')
  nsi_script_dir = 'vlc-' + winstaller_suffix + '-ucrt'
else
  nsi_script_dir = 'vlc-' + winstaller_suffix
endif

if makensis.found()
    spad_nsis = custom_target(
        command: [makensis, nsi_script_dir / 'spad.nsi'],
        input: spad_nsi,
        output: 'spad-setup.exe', # real name but located in installed folder
        build_by_default: false,
        console: true)

    vlc_nsis = custom_target(
        command: [makensis, nsi_script_dir / 'vlc.win32.nsi'],
        input: vlc_nsi,
        output: 'vireo-' + get_option('redesign_release_version') + '-' + winstaller_suffix + '.exe', # real name but root build folder
        build_by_default: false,
        console: true,
        depends: nsProcess)

    alias_target('package-win32-exe', spad_nsis, vlc_nsis)
endif
