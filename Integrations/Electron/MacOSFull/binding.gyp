{
  "targets": [
    {
      "target_name": "guance_electron",
      "sources": ["src/native/guance_electron.mm"],
      "include_dirs": [
        "NativeBridge/Public"
      ],
      "libraries": [
        "-L<(module_root_dir)/native",
        "-lGuanceElectronNative",
        "-framework Foundation",
        "-framework AppKit"
      ],
      "xcode_settings": {
        "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
        "MACOSX_DEPLOYMENT_TARGET": "10.14",
        "OTHER_LDFLAGS": ["-Wl,-rpath,@loader_path"]
      }
    }
  ]
}
