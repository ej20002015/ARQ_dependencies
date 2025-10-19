{
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
}