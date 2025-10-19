{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  pkg-config,
  openssl,
  zlib,
  zip,
}:
{
  version ? "1.56.0",
  buildType ? "Release",
}:

stdenv.mkDerivation {
  pname = "grpc-windows";
  inherit version;

  src = fetchgit {
    url = "https://github.com/grpc/grpc";
    rev = "v${version}";
    fetchSubmodules = true;
    # IMPORTANT: This hash needs to be updated when changing versions
    # When you change the version, the build will fail with the correct hash to use
    # Just copy the hash from the error message and paste it here
    hash = "sha256-0000000000000000000000000000000000000000000000000000";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    zip
  ];
  buildInputs = [
    openssl
    zlib
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=${buildType}"
    "-DCMAKE_CXX_STANDARD=20"
    "-DgRPC_INSTALL=ON"
    "-DgRPC_BUILD_TESTS=OFF"
    "-Dprotobuf_INSTALL=ON"

    "-G\"Visual Studio 17 2022\""
  ];

  configurePhase = ''
    cmake -S . -B build $cmakeFlags -DCMAKE_INSTALL_PREFIX=$out
  '';

  buildPhase = ''
    cmake --build build --config ${buildType} --parallel $NIX_BUILD_CORES
  '';

  installPhase = ''
    cmake --install build --config ${buildType}

    # Create a ZIP archive of the installation for compatibility with Windows scripts
    mkdir -p $out/dist
    (cd $out && zip -r dist/grpc-${version}-windows-${buildType}.zip .)
  '';

  meta = with lib; {
    description = "A high performance, open source universal RPC framework";
    homepage = "https://grpc.io/";
    license = licenses.asl20;
    platforms = platforms.windows;
  };
}
