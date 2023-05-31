# typed: false
# frozen_string_literal: true

class MuslCross < Formula
  desc "Linux cross compilers based on musl libc"
  homepage "https://github.com/jthat/musl-cross-make"
  url "https://github.com/jthat/musl-cross-make/archive/f2313df.tar.gz"
  version "0.9.9-f2313df"
  sha256 "cc566f2284ee2ad11de968b8a2587c63a1b513aa0ff9c55c6c1b126d33778c2e"
  head "https://github.com/jthat/musl-cross-make.git", branch: "f2313df"

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

  depends_on "bison" => :build
  depends_on "flex" => :build
  depends_on "make" => :build

  on_macos do
    depends_on "gnu-sed" => :build
  end

  resource "linux-6.1.29.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.29.tar.xz"
    sha256 "1e736cc9bd6036379a1d915e518abd4c2c94ad0fd1ea0da961c3489308b8fcfb"
  end

  resource "mpfr-4.2.0.tar.xz" do
    url "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz"
    sha256 "06a378df13501248c1b2db5aa977a2c8126ae849a9d9b7be2546fb4a9c26d993"
  end

  resource "mpc-1.3.1.tar.gz" do
    url "https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"
    sha256 "ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8"
  end

  resource "gmp-6.2.1.tar.xz" do
    url "https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz"
    sha256 "fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2"
  end

  resource "musl-1.2.4.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-1.2.4.tar.gz"
    sha256 "7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039"
  end

  resource "binutils-2.40.tar.xz" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz"
    sha256 "0f8a4c272d7f17f369ded10a4aca28b8e304828e95526da482b0ccc4dfc9d8e1"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=63acb96f9247"
    sha256 "b45ba96fa578cfca60ed16e27e689f10812c3f946535e779229afe7a840763e6"
  end

  resource "gcc-13.1.0.tar.xz" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-13.1.0/gcc-13.1.0.tar.xz"
    sha256 "61d684f0aa5e76ac6585ad8898a2427aade8979ed5e7f85492286c4dfc13ee86"
  end

  resource "isl-0.26.tar.xz" do
    url "https://downloads.sourceforge.net/project/libisl/isl-0.26.tar.xz"
    sha256 "a0b5cb06d24f9fa9e77b55fabbe9a3c94a336190345c2555f9915bb38e976504"
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

      # Drop some features for faster and smaller builds
      COMMON_CONFIG += --disable-nls
      GCC_CONFIG += --disable-libquadmath --disable-decimal-float
      GCC_CONFIG += --disable-libitm --disable-fixed-point

      # Keep the local build path out of binaries and libraries
      COMMON_CONFIG += --with-debug-prefix-map=#{buildpath}=

      # Explicitly enable libisl support to avoid opportunistic linking
      ISL_VER = 0.26
      GCC_VER = 13.1.0

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
