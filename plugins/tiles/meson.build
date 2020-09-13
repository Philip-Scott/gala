gala_tiling_sources = [
    'Main.vala',
    'forest/Node.vala'
]

gala_pip_lib = shared_library(
    'gala-tiling',
    gala_tiling_sources,
    dependencies: [gala_dep, gala_base_dep],
    include_directories: config_inc_dir,
    install: true,
    install_dir: plugins_dir,
    install_rpath: mutter_typelib_dir,
)
