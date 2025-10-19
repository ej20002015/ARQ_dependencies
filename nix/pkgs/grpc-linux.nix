{ 
  lib, 
  stdenv, 
  fetchgit, 
  cmake, 
  ninja, 
  pkg-config, 
  openssl,
  zlib, 
}:

{
  version ? "1.56.0",
  buildType ? "Release",
}:

stdenv.mkDerivation {
  pname = "grpc";
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
    
    "-GNinja"
  ];

  configurePhase = ''
    cmake -S . -B build $cmakeFlags -DCMAKE_INSTALL_PREFIX=$out
  '';

  buildPhase = ''
    cmake --build build --parallel $NIX_BUILD_CORES
  '';

  installPhase = ''
    cmake --install build

    # Create a tarball of the installation for compatibility with existing scripts
    mkdir -p $out/dist
    tar -czf $out/dist/grpc-${version}-linux-${buildType}.tar.gz -C $out .
  '';

  meta = with lib; {
    description = "A high performance, open source universal RPC framework";
    homepage = "https://grpc.io/";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
