# Static Builds of Fluent Bit

TLDR: This repo creates statically-linked builds of [Fluent Bit](https://fluentbit.io/), shortly after they are released to the main repo.  A multi-platform OCI image is available, as well as individual binaries.

## Motivation

I created this project because I wanted to use the latest version of Fluent Bit on my home router, which runs [Alpine Linux](https://alpinelinux.org/) on an ARM64 platform.  Alpine can be a challenge due to using musl libc instead of glibc - I wanted a distribution of Fluent Bit that could be used similar to a Go binary, without any concern for the underlying libraries.

Since I was using Docker buildx to enable building on many platforms via GitHub Actions, I also realized that a docker container based on `scratch` has some benefits as well for people using Docker on embedded platforms, in that it is much smaller to download and has a smaller attack surface, though there is a tradeoff in security that comes from embedding the dependencies (see Security Considerations).

## Security Considerations

These images/binaries are built using the `debian` container image, which provides the compatibility needed to build successfully on all of Fluent Bit's supported architectures.  Because these builds are statically linked, they represent a point-in-time version of the libraries which are linked into the build.  If a vulnerability is discovered in a linked library, that vulnerability will persist until a new build is created against the patched library.  Since builds are automated this may not occur until the next upstream release.

Since the typical use case for Fluent Bit is to read locally and make outgoing connections to deliver logs to a platform, this helps to mitigate remote code execution vulnerabilities.

## Known Limitations

The `systemd` input plugin is supported from version `5.2.0` onward.  Debian does not ship a static libsystemd (see this Debian [bug report](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=915566)), so one is compiled from Debian's systemd source package as part of the build.  It reads journals written by newer versions of systemd, including fields compressed with zstd, xz or lz4.  Journal sealing (FSS) verification is not included.

The Lua and WASM filters were disabled from version `2.0.0` through `5.1.x` and are enabled again from `5.2.0` onward.  Because the binary is statically linked, Lua scripts cannot `require` C modules or use the LuaJIT FFI to load shared libraries; pure Lua scripts work normally.  For the same reason, Fluent Bit's dynamically loaded plugins (`-e` / `plugins_file`, including Go plugins) are not usable.
