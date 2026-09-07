set -euxo pipefail

rm -rf build || true
mkdir build
cd build

export QT_HOST_PATH="$PREFIX"

if [[ "$target_platform" == "linux-aarch64" ]]; then
    # The clang toolchain here does not ship LLVMgold.so, so -flto=auto causes
    # pybind link to fail when ld tries to load the plugin.
    export CFLAGS="${CFLAGS//-flto=auto/} -fno-lto"
    export CXXFLAGS="${CXXFLAGS//-flto=auto/} -fno-lto"
    export LDFLAGS="${LDFLAGS//-flto=auto/} -fno-lto"
fi

cmake ${SRC_DIR} ${CMAKE_ARGS} \
    -DCLANG_LIBDIR=${PREFIX}/lib \
    -DFILAMENT_C_COMPILER=${CC} \
    -DFILAMENT_CXX_COMPILER=${CXX} \
    -DBUILD_AZURE_KINECT=OFF \
    -DBUILD_BENCHMARKS=OFF \
    -DBUILD_CUDA_MODULE=OFF \
    -DBUILD_COMMON_CUDA_ARCHS=OFF \
    -DBUILD_CACHED_CUDA_MANAGER=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_ISPC_MODULE=OFF \
    -DBUILD_GUI=ON \
    -DBUILD_LIBREALSENSE=OFF \
    -DBUILD_PYTORCH_OPS=OFF \
    -DBUILD_REALSENSE=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TENSORFLOW_OPS=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DBUILD_WEBRTC=OFF \
    -DENABLE_HEADLESS_RENDERING=OFF \
    -DBUILD_JUPYTER_EXTENSION=OFF \
    -DOPEN3D_USE_ONEAPI_PACKAGES=OFF \
    -DUSE_BLAS=ON \
    -DUSE_SYSTEM_ASSIMP=ON \
    -DUSE_SYSTEM_BLAS=ON \
    -DUSE_SYSTEM_CURL=ON \
    -DUSE_SYSTEM_EIGEN3=ON \
    -DUSE_SYSTEM_EMBREE=ON \
    -DUSE_SYSTEM_FMT=ON \
    -DUSE_SYSTEM_GLEW=ON \
    -DUSE_SYSTEM_GLFW=ON \
    -DUSE_SYSTEM_GOOGLETEST=ON \
    -DUSE_SYSTEM_IMGUI=OFF \
    -DUSE_SYSTEM_JPEG=ON \
    -DUSE_SYSTEM_JSONCPP=ON \
    -DUSE_SYSTEM_LIBLZF=ON \
    -DUSE_SYSTEM_LIBREALSENSE=OFF \
    -DUSE_SYSTEM_MSGPACK=ON \
    -DUSE_SYSTEM_NANOFLANN=ON \
    -DUSE_SYSTEM_OPENSSL=ON \
    -DUSE_SYSTEM_PNG=ON \
    -DUSE_SYSTEM_PYBIND11=ON \
    -DUSE_SYSTEM_QHULLCPP=ON \
    -DUSE_SYSTEM_TBB=ON \
    -DUSE_SYSTEM_TINYGLTF=OFF \
    -DUSE_SYSTEM_TINYOBJLOADER=ON \
    -DUSE_SYSTEM_VTK=ON \
    -DUSE_SYSTEM_ZEROMQ=ON \
    -DWITH_IPP=OFF \
    -DWITH_FAISS=OFF \
    -DPython3_EXECUTABLE=$PYTHON

cmake --build . --config Release -- -j$CPU_COUNT
cmake --build . --config Release --target install
cmake --build . --config Release --target install-pip-package

# open3d's wheel builder reads the platform tag from the build-time glibc
# (gnu_get_libc_version), not from the sysroot, so the installed wheel is tagged
# for the build host glibc while the real floor is __glibc >=${c_stdlib_version}.
# Rewrite the Tag to the sysroot baseline (derived from the c_stdlib_version
# variant) so pip introspection does not mark the package unsupported on older
# glibc, and so the pin is tracked automatically when the floor is bumped.
if [[ "$target_platform" == linux-* ]]; then
    manylinux_tag="manylinux_${c_stdlib_version//./_}"
    echo "Retagging open3d wheel platform tag to ${manylinux_tag} (c_stdlib_version=${c_stdlib_version})"
    for wheel in "${SP_DIR}"/open3d*.dist-info/WHEEL; do
        sed -i -E "s/manylinux_[0-9]+_[0-9]+/${manylinux_tag}/g" "$wheel"
    done
fi

if [[ "$target_platform" == "linux-64" ]]; then
    alias_name="open3d"
    alias_stem="open3d"
else
    alias_name="open3d-cpu"
    alias_stem="open3d_cpu"
fi

alias_metadata_dir="${SP_DIR}/${alias_stem}-${PKG_VERSION}.dist-info"
test ! -e "$alias_metadata_dir"
mkdir "$alias_metadata_dir"
cat >"${alias_metadata_dir}/METADATA" <<EOF
Metadata-Version: 2.1
Name: ${alias_name}
Version: ${PKG_VERSION}
EOF
printf 'conda\n' >"${alias_metadata_dir}/INSTALLER"
