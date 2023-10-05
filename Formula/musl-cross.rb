# typed: false
# frozen_string_literal: true

class MuslCross < Formula
  desc "Linux cross compilers based on gcc and musl libc"
  homepage "https://github.com/jthat/musl-cross-make"
  url "https://github.com/jthat/musl-cross-make/archive/v1.1.0.tar.gz"
  sha256 "ee9b6e5c84e1e0e7a9c69ba110ec503d63781c4be4a9d767dfad36200690ce30"
  head "https://github.com/jthat/musl-cross-make.git", branch: "master"

  LINUX_VER      = "4.19.295"
  GCC_VER        = "13.2.0"
  BINUTILS_VER   = "2.41"
  MUSL_VER       = "1.2.4"
  CONFIG_SUB_REV = "28ea239c53a2"

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
    sha256 "b732c2e4f08576a9dd5bb14213cead3835acbb101a91aaba3d6ace302fd538ac"
  end

  resource "gcc-#{GCC_VER}.tar.xz" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-#{GCC_VER}/gcc-#{GCC_VER}.tar.xz"
    sha256 "e275e76442a6067341a27f04c5c6b83d8613144004c0413528863dc6b5c743da"
  end

  resource "binutils-#{BINUTILS_VER}.tar.xz" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-#{BINUTILS_VER}.tar.xz"
    sha256 "ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450"
  end

  resource "musl-#{MUSL_VER}.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-#{MUSL_VER}.tar.gz"
    sha256 "7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=#{CONFIG_SUB_REV}"
    sha256 "465c5fe67c7d36b72e808812716445d4d38d4b94734ca8d36a8639d12323878b"
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
