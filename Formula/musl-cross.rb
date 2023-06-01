# typed: false
# frozen_string_literal: true

class MuslCross < Formula
  GCC_VER      = "13.1.0"
  BINUTILS_VER = "2.40"
  MUSL_VER     = "1.2.4"

  desc "Linux cross compilers based on gcc and musl libc"
  homepage "https://github.com/jthat/musl-cross-make"
  url "https://github.com/jthat/musl-cross-make/archive/d1993a6.tar.gz"
  version "0.9.9-d1993a6"
  sha256 "12256deee0f9ad50eb7ffa81af22c252f4953c1423e9011fe3acdb025a0ce43d"
  head "https://github.com/jthat/musl-cross-make.git", branch: "d1993a6"

  option "with-aarch64", "Build cross-compilers targeting aarch64-linux-musl"
  option "with-arm-hf", "Build cross-compilers targeting arm-linux-musleabihf"
  option "with-arm", "Build cross-compilers targeting arm-linux-musleabi"
  option "with-i486", "Build cross-compilers targeting i486-linux-musl"
  option "with-mips", "Build cross-compilers targeting mips-linux-musl"
  option "with-mipsel", "Build cross-compilers targeting mipsel-linux-musl"
  option "with-mips64", "Build cross-compilers targeting mips64-linux-musl"
  option "with-mips64el", "Build cross-compilers targeting mips64el-linux-musl"
  option "with-powerpc", "Build cross-compilers targeting powerpc-linux-musl"
  option "with-powerpc-sf", "Build cross-compilers targeting powerpc-linux-muslsf"
  option "without-x86_64", "Do not build cross-compilers targeting x86_64-linux-musl"

  depends_on "bison"   => :build
  depends_on "gnu-sed" => :build
  depends_on "make"    => :build

  depends_on "gmp"
  depends_on "isl"
  depends_on "libmpc"
  depends_on "mpfr"
  depends_on "zstd"

  uses_from_macos "flex" => :build
  uses_from_macos "zlib"

  resource "linux-6.1.31.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.31.tar.xz"
    sha256 "e86917bba1990e967943645484182a64ba325f98b114a1906cc1d50992e073c1"
  end

  resource "gcc-#{GCC_VER}.tar.xz" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-#{GCC_VER}/gcc-#{GCC_VER}.tar.xz"
    sha256 "61d684f0aa5e76ac6585ad8898a2427aade8979ed5e7f85492286c4dfc13ee86"
  end

  resource "binutils-#{BINUTILS_VER}.tar.xz" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-#{BINUTILS_VER}.tar.xz"
    sha256 "0f8a4c272d7f17f369ded10a4aca28b8e304828e95526da482b0ccc4dfc9d8e1"
  end

  resource "musl-#{MUSL_VER}.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-#{MUSL_VER}.tar.gz"
    sha256 "7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=63acb96f9247"
    sha256 "b45ba96fa578cfca60ed16e27e689f10812c3f946535e779229afe7a840763e6"
  end

  def install
    targets = []
    targets.push "x86_64-linux-musl" if build.with? "x86_64"
    targets.push "aarch64-linux-musl" if build.with? "aarch64"
    targets.push "arm-linux-musleabihf" if build.with? "arm-hf"
    targets.push "arm-linux-musleabi" if build.with? "arm"
    targets.push "i486-linux-musl" if build.with? "i486"
    targets.push "mips-linux-musl" if build.with? "mips"
    targets.push "mipsel-linux-musl" if build.with? "mipsel"
    targets.push "mips64-linux-musl" if build.with? "mips64"
    targets.push "mips64el-linux-musl" if build.with? "mips64el"
    targets.push "powerpc-linux-musl" if build.with? "powerpc"
    targets.push "powerpc-linux-muslsf" if build.with? "powerpc-sf"

    (buildpath/"resources").mkpath
    resources.each do |resource|
      cp resource.fetch, buildpath/"resources"/resource.name
    end

    (buildpath/"config.mak").write <<~EOS
      SOURCES = #{buildpath/"resources"}
      OUTPUT = #{libexec}

      # Versions
      BINUTILS_VER = #{BINUTILS_VER}
      GCC_VER  = #{GCC_VER}
      MUSL_VER = #{MUSL_VER}

      # Use libs from Homebrew
      GMP_VER  =
      MPC_VER  =
      MPFR_VER =
      ISL_VER  =
      COMMON_CONFIG += --with-gmp=#{Formula["gmp"].opt_prefix}
      COMMON_CONFIG += --with-mpc=#{Formula["libmpc"].opt_prefix}
      COMMON_CONFIG += --with-mpfr=#{Formula["mpfr"].opt_prefix}
      COMMON_CONFIG += --with-isl=#{Formula["isl"].opt_prefix}
      COMMON_CONFIG += --with-zstd=#{Formula["zstd"].opt_prefix}
      COMMON_CONFIG += --with-system-zlib

      # Release build options
      COMMON_CONFIG += --enable-checking=release
      COMMON_CONFIG += --with-pkgversion="Homebrew GCC #{pkg_version} musl cross"
      COMMON_CONFIG += --with-bugurl="https://github.com/jthat/homebrew-musl-cross/issues"

      # Drop some features for faster and smaller builds
      COMMON_CONFIG += --disable-nls
      GCC_CONFIG += --disable-libquadmath --disable-decimal-float
      GCC_CONFIG += --disable-libitm --disable-fixed-point

      # Keep the local build path out of binaries and libraries
      COMMON_CONFIG += --with-debug-prefix-map=#{buildpath}=

      # https://llvm.org/bugs/show_bug.cgi?id=19650
      # https://github.com/richfelker/musl-cross-make/issues/11
      ifeq ($(shell $(CXX) -v 2>&1 | grep -c "clang"), 1)
      TOOLCHAIN_CONFIG += CXX="$(CXX) -fbracket-depth=512"
      endif
    EOS

    if OS.mac?
      ENV.prepend_path "PATH", "#{Formula["gnu-sed"].opt_libexec}/gnubin"
      make = Formula["make"].opt_bin/"gmake"
    else
      make = "make"

      # Linux build fails because gprofng finds Java SDK
      # https://github.com/jthat/homebrew-musl-cross/issues/6
      begin
        # Cause binutils gprofng to find a fake jdk, and thus disable Java profiling support
        fakejdk_bin = buildpath/"fakejdk/bin"
        fakejdk_bin.mkpath
        %w[javac java].each do |b|
          (fakejdk_bin/b).write <<~EOS
            #!/bin/sh
            exit 1
          EOS
          chmod "+x", fakejdk_bin/b
        end
        ENV.prepend_path "PATH", fakejdk_bin
      end

    end
    targets.each do |target|
      system make, "install", "TARGET=#{target}"
    end

    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    (testpath/"hello.c").write <<~EOS
      #include <stdio.h>

      int main()
      {
          printf("Hello, world!");
      }
    EOS

    system "#{bin}/x86_64-linux-musl-cc", (testpath/"hello.c") if build.with? "x86_64"
    system "#{bin}/i486-linux-musl-cc", (testpath/"hello.c") if build.with? "i486"
    system "#{bin}/aarch64-linux-musl-cc", (testpath/"hello.c") if build.with? "aarch64"
    system "#{bin}/arm-linux-musleabihf-cc", (testpath/"hello.c") if build.with? "arm-hf"
    system "#{bin}/arm-linux-musleabi-cc", (testpath/"hello.c") if build.with? "arm"
    system "#{bin}/mips-linux-musl-cc", (testpath/"hello.c") if build.with? "mips"
    system "#{bin}/mipsel-linux-musl-cc", (testpath/"hello.c") if build.with? "mipsel"
    system "#{bin}/mips64-linux-musl-cc", (testpath/"hello.c") if build.with? "mips64"
    system "#{bin}/mips64el-linux-musl-cc", (testpath/"hello.c") if build.with? "mips64el"
    system "#{bin}/powerpc-linux-musl-cc", (testpath/"hello.c") if build.with? "powerpc"
    system "#{bin}/powerpc-linux-muslsf-cc", (testpath/"hello.c") if build.with? "powerpc-sf"
  end
end
