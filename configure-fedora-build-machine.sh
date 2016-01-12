#!/bin/bash

echo "*** Download and build Clang for RedHat EL7+ and Fedora 23+ Based OS ***"
echo " Note: I'm a big fan of MySQL, if you are too, then uncomment 'install_extras'"
echo "       to have this script get and install MySQL 5.7 from Oracle."
echo "       Due to licensing MySQL 5.7 is not configured and install by default"
echo "         and as such you need to register an account with Oracle.

SCRIPT_DIR="$(pwd)"
SOURCE_DIR="${SCRIPT_DIR}/source"
BUILD_DIR="${SCRIPT_DIR}/build"
VERSION="371"
SUBVERSION="final"

function create_directories()
{
  mkdir -p ${SOURCE_DIR}
  mkdir -p ${BUILD_DIR}
}

function install_tools()
{
  sudo dnf install wget unzip make cmake gcc gcc-c++ svn git python m4 autoconf automake libtool zlib libxml zlib-devel python-devel bzip2-devel
}

function get_repos()
{
  if [ ! -d "${SOURCE_DIR}/llvm" ]; then
    cd "${SOURCE_DIR}"
    svn checkout http://llvm.org/svn/llvm-project/llvm/tags/RELEASE_${VERSION}/${SUBVERSION} llvm
    cd "${SOURCE_DIR}/llvm/tools"
    svn checkout http://llvm.org/svn/llvm-project/cfe/tags/RELEASE_${VERSION}/${SUBVERSION} clang
    cd "${SOURCE_DIR}/llvm/projects"
    svn checkout http://llvm.org/svn/llvm-project/compiler-rt/tags/RELEASE_${VERSION}/${SUBVERSION} compiler-rt
    svn checkout http://llvm.org/svn/llvm-project/libcxx/tags/RELEASE_${VERSION}/${SUBVERSION} libcxx
    svn checkout http://llvm.org/svn/llvm-project/libcxxabi/tags/RELEASE_${VERSION}/${SUBVERSION} libcxxabi
    # svn checkout http://llvm.org/svn/llvm-project/test-suite/tags/RELEASE_${VERSION}/${SUBVERSION} test-suite
  fi
}

function do_build()
{
  cd "${BUILD_DIR}"
  cmake "${SOURCE_DIR}/llvm" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_CXX1Y=ON -DLIBCXX_ENABLE_CXX1Y=ON -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXXABI_ENABLE_SHARED=OFF -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLIBCXXABI_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON 
  make -j4
  sudo make install
}

function solve_circular_dependancy()
{
  cd "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}/libcxxabi"
  cd "${BUILD_DIR}/libcxxabi"
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_C_COMPILER=/usr/local/bin/clang -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ -DCMAKE_CXX_FLAGS="-std=c++14" -DLIBCXXABI_LIBCXX_INCLUDES=${SOURCE_DIR}/llvm/projects/libcxx/include ${SOURCE_DIR}/llvm/projects/libcxxabi 
  make -j8
  sudo make install

  mkdir -p "${BUILD_DIR}/libcxx"
  cd "${BUILD_DIR}/libcxx"
  cmake -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_C_COMPILER=/usr/local/bin/clang -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS=${SOURCE_DIR}/llvm/projects/libcxxabi/include -DLIBCXX_ENABLE_CXX1Y=ON -DLIBCXX_ENABLE_SHARED=ON ${SOURCE_DIR}/llvm/projects/libcxx
  make -j8
  sudo make install

  local _ld_conf=$(cat <<EOF
/usr/local/lib
EOF
)
  sudo sh -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/clang.conf'  
  sudo ldconfig
}

function do_test()
{

  local _source_code=$(cat <<EOF
#include <iostream>
#include <string>
using namespace std;

int main(int argc, char** argv)
{
  auto str = "Clang is functional";
  cout << str << endl;
  return 0;
}

EOF
)

  echo "${_source_code}" > "${SCRIPT_DIR}/test.cpp"
  clang++ -std=c++14 -stdlib=libc++ -o "${SCRIPT_DIR}/test" "${SCRIPT_DIR}/test.cpp"
  "${SCRIPT_DIR}/test"
}

function set_defaults()
{
  local _local_var=$(cat <<EOF

  # Default compiler config
  export CC=clang
  export CXX=clang++
 
EOF
)
  if grep -Fxq "export CXX=clang++" ~/.bash_profile; then
    echo "${_local_var}" ~/.bash_profile
  fi
}

function install_extras()
{
  cd "${SCRIPT_DIR}"

  # Check if the repo has been downloaded and installed
  if [ ! -e "/etc/yum.repos.d/mysql-community.repo" ]; then
    wget http://dev.mysql.com/get/mysql57-community-release-fc23-7.noarch.rpm
    sudo dnf install mysql57-community-release-fc23-7.noarch.rpm
  fi

  sudo dnf config-manager --disablerepo mysql56-community
  sudo dnf config-manager --enable mysql57-community  
  sudo dnf update
  sudo dnf install --nogpgcheck mysql-community-server mysql-community-devel
}

create_directories
install_tools
get_repos
do_build
solve_circular_dependancy
do_test
set_defaults
# install_extras
