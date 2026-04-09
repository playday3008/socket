FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV THEOS=/opt/theos

# 1. Install dependencies
#    1.1. Install Theos prerequisites
#    1.2. Pre-install Theos dependencies
#    1.3. Clean up apt cache to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        curl \
        sudo \
        build-essential \
        fakeroot \
        git \
        libxml2 \
        perl \
        rsync \
        zip \
        libtinfo6 \
    && rm -rf /var/lib/apt/lists/*

# 2. Non-root user (Theos installer refuses to run as root)
RUN useradd -m builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p $THEOS && chown builder:builder $THEOS

# 3. Install Theos (CI=1 skips interactive prompts)
USER builder
RUN CI=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# 4. Remove auto-downloaded SDKs
RUN rm -rf $THEOS/sdks/*.sdk

# 5. Install iPhoneOS 10.3 SDK
RUN $THEOS/bin/install-sdk iPhoneOS10.3

# 6. Strip i386/x86_64 from top-level TBD archs so the linker doesn't
#    mistake them for simulator libs (theos/sdks#56, still open).
RUN find $THEOS/sdks/iPhoneOS10.3.sdk -type f -name '*.tbd' -exec sed -i \
        -e '/^archs:/s/, x86_64//g' \
        -e '/^archs:/s/x86_64, //g' \
        -e '/^archs:/s/, i386//g' \
        -e '/^archs:/s/i386, //g' {} +

# 7. Patch libsystem_c.tbd to add standard C symbols missing from the
#    SDK stubs (memcpy, memset, strcmp, etc.). Without these the linker
#    fails when the compiler emits non-inlined calls to them.
RUN sed -i '/symbols:.*\[.*_OSMemoryNotificationCurrentLevel/s/\[/[ _memcmp, _memcpy, _memmove, _memset, _memset_pattern16, _strcmp, _strncmp, _strlen, _strncpy, _strlcpy, _strlcat, _bzero, /' \
    $THEOS/sdks/iPhoneOS10.3.sdk/usr/lib/system/libsystem_c.tbd

# 8. Remove module maps — newer Clang can't build modules from the
#    old SDK, and Theos forces -fmodules after our -fno-modules.
RUN find $THEOS/sdks/iPhoneOS10.3.sdk -name 'module.map' -delete && \
    find $THEOS/sdks/iPhoneOS10.3.sdk -name 'module.modulemap' -delete

USER root

WORKDIR /build
CMD ["bash", "-c", "make clean package FINALPACKAGE=1 && mkdir -p /build/Payload && cp -R /build/.theos/_/Applications/socket.app /build/Payload/ && cd /build && zip -r socket.ipa Payload && rm -rf Payload"]
