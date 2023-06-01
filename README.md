# homebrew-musl-cross

[Homebrew](https://brew.sh/) package manager formula to install cross-compiler toolchains targeting Linux boxes.

The default installation contains toolchains for x86 64-bit Linux (`x86_64-linux-musl`) and ARM 32/64-bit Linux (`arm-linux-musleabihf`/`aarch64-linux-musl`) as used on Raspberry Pi and similar devices. Others can be installed with package options (see `brew info`).

Note, when using the toolchain, the generated binaries will only run on a system with `musl` libc installed. Either musl-based distributions like Alpine Linux or distributions having `musl` libc installed as separate packages (e.g., Debian/Ubuntu).

Binaries statically linked with `musl` libc (linked with `-static`) have no external dependencies, even for features like DNS lookups or character set conversions that are implemented with dynamic loading on glibc. The application can be deployed as a single binary file and run on any device with the appropriate ISA and Linux kernel or Linux syscall ABI emulation layer including bare docker containers.

**Tool Versions:**
- [Linux](https://kernel.org/) 6.1.31
- [GCC](https://gcc.gnu.org/) 13.1.0
- [binutils](https://www.gnu.org/software/binutils/) 2.40
- [musl libc](https://www.musl-libc.org/) 1.2.4

Partially based on:
 - [FiloSottile/homebrew-musl-cross](https://github.com/FiloSottile/homebrew-musl-cross)
 - [MarioSchwalbe/homebrew-gcc-musl-cross](https://github.com/MarioSchwalbe/homebrew-gcc-musl-cross)

Depends on [jthat/musl-cross-make](https://github.com/jthat/musl-cross-make) to do the heavy lifting, which is in turn based on [richfelker/musl-cross-make](https://github.com/richfelker/musl-cross-make).


# Usage

1. Install with Homebrew:
    ```sh
    $ brew tap jthat/musl-cross
    $ brew install musl-cross
    ```

2. For dynamically linked applications, ensure the correct version of `musl` is installed on the target device.

3. Compile with `<TARGET>-gcc` e.g., `x86_64-linux-musl-gcc`, deploy, and run.


# Supported Targets

- `i686-linux-musl`
- `x86_64-linux-musl`
- `x86_64-linux-muslx32`
- `arm-linux-musleabi`
- `arm-linux-musleabihf`
- `aarch64-linux-musl`
- `mips-linux-musl`
- `mips64-linux-musl`
- `powerpc-linux-musl`
- `powerpc64-linux-musl`
- `s390x-linux-musl`

Other targets or variants can be added easily by extending the hash `OPTION_TARGET_MAP` in the formula as long as `musl-cross-make` and `musl` libc also support them.
