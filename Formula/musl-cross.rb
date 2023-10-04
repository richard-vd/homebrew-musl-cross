# typed: false
# frozen_string_literal: true

class MuslCross < Formula
  desc "Linux cross compilers based on gcc and musl libc"
  homepage "https://github.com/jthat/musl-cross-make"
  url "https://github.com/jthat/musl-cross-make/archive/v1.0.0.tar.gz"
  sha256 "7074507b9f068c80fe769350e3b613702652704e89f2887702551be94e6d4d0e"
  head "https://github.com/jthat/musl-cross-make.git", branch: "master"
  bottle do
    root_url "https://github.com/jthat/homebrew-musl-cross/releases/download/musl-cross-1.0.0"
    sha256 cellar: :any,                 ventura:      "fdc4ca687ff1b6f6ecdb4d4a92e8fdd96b2b3055ac84646d794fface520777bb"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "7c27418063115d699dbce9d499ca3c85e97d84cb887d625adc27f44d5c31bb5c"
  end

  LINUX_VER      = "4.19.284"
  GCC_VER        = "13.1.0"
  BINUTILS_VER   = "2.40"
  MUSL_VER       = "1.2.4"
  CONFIG_SUB_REV = "63acb96f9247"

  OPTION_TARGET_MAP = {
    "x86"       => "i686-linux-musl",
    "x86_64"    => "x86_64-linux-musl",
    "x86_64x32" => "x86_64-linux-muslx32",
    "aarch64"   => "aarch64-linux-musl",
    "arm"       => "arm-linux-musleabi",
    "armhf"     => "arm-linux-musleabihf",
    "mips"      => "mips-linux-musl",
    "mips64"    => "mips64-linux-musl",
    "powerpc"   => "powerpc-linux-musl",
    "powerpc64" => "powerpc64-linux-musl",
    "s390x"     => "s390x-linux-musl",
  }.freeze

  DEFAULT_TARGETS = %w[x86_64].freeze

  OPTION_TARGET_MAP.each do |option, target|
    if DEFAULT_TARGETS.include? option
      option "without-#{option}", "Do not build cross-compilers for #{target}"
    else
      option "with-#{option}", "Build cross-compilers for #{target}"
    end
  end

  option "with-all-targets", "Build cross-compilers for all targets"

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

  resource "linux-#{LINUX_VER}.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v#{LINUX_VER.sub(/^([^.])\..*$/, '\1')}.x/linux-#{LINUX_VER}.tar.xz"
    sha256 "7fb9ee20c7e52f9be6d9f501e8498a22f4b364abfde136143749a77e597fd03e"
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
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=#{CONFIG_SUB_REV}"
    sha256 "b45ba96fa578cfca60ed16e27e689f10812c3f946535e779229afe7a840763e6"
  end

  def install
    targets = []
    OPTION_TARGET_MAP.each do |option, target|
      targets.push target if build.with?(option) || build.with?("all-targets")
    end

    (buildpath/"resources").mkpath
    resources.each do |resource|
      cp resource.fetch, buildpath/"resources"/resource.name
    end

    languages = %w[c c++]

    pkgversion = "Homebrew GCC musl cross #{pkg_version} #{build.used_options*" "}".strip
    bugurl = "https://github.com/jthat/homebrew-musl-cross/issues"

    common_config = %W[
      --disable-nls
      --enable-checking=release
      --enable-languages=#{languages.join(",")}
      --with-gmp=#{Formula["gmp"].opt_prefix}
      --with-mpfr=#{Formula["mpfr"].opt_prefix}
      --with-mpc=#{Formula["libmpc"].opt_prefix}
      --with-isl=#{Formula["isl"].opt_prefix}
      --with-zstd=#{Formula["zstd"].opt_prefix}
      --with-system-zlib
      --with-pkgversion=#{pkgversion}
      --with-bugurl=#{bugurl}
      --with-debug-prefix-map=#{buildpath}=
    ]

    gcc_config = %w[
      --disable-libquadmath
      --disable-decimal-float
      --disable-libitm
      --disable-fixed-point
    ]

    (buildpath/"config.mak").write <<~EOS
      SOURCES = #{buildpath/"resources"}
      OUTPUT = #{libexec}

      # Versions
      LINUX_VER = #{LINUX_VER}
      BINUTILS_VER = #{BINUTILS_VER}
      GCC_VER  = #{GCC_VER}
      MUSL_VER = #{MUSL_VER}
      CONFIG_SUB_REV = #{CONFIG_SUB_REV}

      # Use libs from Homebrew
      GMP_VER  =
      MPC_VER  =
      MPFR_VER =
      ISL_VER  =

      # https://llvm.org/bugs/show_bug.cgi?id=19650
      # https://github.com/richfelker/musl-cross-make/issues/11
      ifeq ($(shell $(CXX) -v 2>&1 | grep -c "clang"), 1)
      TOOLCHAIN_CONFIG += CXX="$(CXX) -fbracket-depth=512"
      endif

      #{common_config.map { |o| "COMMON_CONFIG += #{o}\n" }.join}
      #{gcc_config.map { |o| "GCC_CONFIG += #{o}\n" }.join}
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

  TEST_OPTION_MAP = {
    "readelf" => ["-a"],
    "objdump" => ["-ldSC"],
    "strings" => [],
    "size"    => [],
    "nm"      => [],
    "strip"   => [],
  }.freeze

  test do
    ENV.clear

    (testpath/"hello.c").write <<-EOS
      #include <stdio.h>
      int main(void) {
          puts("Hello World!");
          return 0;
      }
    EOS

    (testpath/"hello.cpp").write <<-EOS
      #include <iostream>
      int main(void) {
          std::cout << "Hello World!" << std::endl;
          return 0;
      }
    EOS

    OPTION_TARGET_MAP.each do |option, target|
      next if build.without?(option) && build.without?("all-targets")

      test_prog = "hello-#{target}"
      system bin/"#{target}-cc", "-O2", "hello.c", "-o", test_prog
      assert_predicate testpath/test_prog, :exist?
      TEST_OPTION_MAP.each do |prog, options|
        system bin/"#{target}-#{prog}", *options, test_prog
      end

      system bin/"#{target}-c++", "-O2", "hello.cpp", "-o", test_prog
      assert_predicate testpath/test_prog, :exist?
      TEST_OPTION_MAP.each do |prog, options|
        system bin/"#{target}-#{prog}", *options, test_prog
      end
    end
  end
end
