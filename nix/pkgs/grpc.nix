{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  openssl,
  zlib,
}:
{
  version ? "v1.74.1",
  buildType ? "Release",
  platform ? "linux",
  cmakeGenerator ? if platform == "windows" then "Visual Studio 17 2022" else "Ninja Multi-Config",
}:

stdenv.mkDerivation {
  name = "grpc";
  inherit version;

  src = fetchGit {
    url = "https://github.com/grpc/grpc";
    ref = "refs/tags/${version}";
    rev = "893bdadd56dbb75fb156175afdaa2b0d47e1c15b";
    submodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    stdenv.cc
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
  ]
  ++ lib.optionals (platform == "linux") [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  configurePhase = ''
    cmake -S . -B build -G "${cmakeGenerator}" -DCMAKE_INSTALL_PREFIX=$out $cmakeFlags
  '';

  buildPhase = ''
    cmake --build build --config ${buildType} --parallel $NIX_BUILD_CORES
  '';

  installPhase = ''
    cmake --install build --config ${buildType}

    # Create an archive of the installation for compatibility with existing scripts
    # First create a stable copy of files to prevent "file changed as we read it" errors
    mkdir -p $out/dist
    mkdir -p $TMPDIR/grpc-archive
    cp -R $out/* $TMPDIR/grpc-archive/
    tar -czf $out/dist/grpc-${version}-${platform}-${buildType}.tar.gz -C $TMPDIR/grpc-archive .
  '';

  meta = with lib; {
    description = "A high performance, open source universal RPC framework";
    homepage = "https://grpc.io/";
    license = licenses.asl20;
    platforms = if platform == "windows" then platforms.windows else platforms.linux;
  };
}
