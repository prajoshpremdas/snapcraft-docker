FROM arm32v7/ubuntu:18.04 as builder

COPY qemu-arm-static /usr/bin/

# Grab dependencies
RUN apt-get update
RUN apt-get dist-upgrade --yes
RUN apt-get install --yes \
      curl \
      jq \
      squashfs-tools

RUN ln -sf /bin/bash /bin/sh

RUN if [ `arch` == "x86_64" ]; then export ARCH=amd64; elif [ `arch` == "aarch64" ]; then export ARCH=arm64; elif [ `arch` == "armv7l" ]; then export ARCH=armhf; else export ARCH=`arch`; fi && \
    curl -L $(curl -H 'X-Ubuntu-Series: 16' -H "X-Ubuntu-Architecture: $ARCH" 'https://api.snapcraft.io/api/v1/snaps/details/core' | jq '.download_url' -r) --output core.snap && \
    curl -L $(curl -H 'X-Ubuntu-Series: 16' -H "X-Ubuntu-Architecture: $ARCH" 'https://api.snapcraft.io/api/v1/snaps/details/core18' | jq '.download_url' -r) --output core18.snap && \
    curl -L $(curl -H 'X-Ubuntu-Series: 16' -H "X-Ubuntu-Architecture: $ARCH" 'https://api.snapcraft.io/api/v1/snaps/details/snapcraft?channel=stable' | jq '.download_url' -r) --output snapcraft.snap

# Grab the core snap from the stable channel and unpack it in the proper place
RUN mkdir -p /snap/core
RUN unsquashfs -d /snap/core/current core.snap

# Grab the core18 snap (which snapcraft uses as a base) from the stable channel
# and unpack it in the proper place.
RUN mkdir -p /snap/core18
RUN unsquashfs -d /snap/core18/current core18.snap

# Grab the snapcraft snap from the stable channel and unpack it in the proper place
RUN mkdir -p /snap/snapcraft
RUN unsquashfs -d /snap/snapcraft/current snapcraft.snap

# Create a snapcraft runner (TODO: move version detection to the core of snapcraft)
RUN mkdir -p /snap/bin
RUN echo "#!/bin/sh" > /snap/bin/snapcraft
RUN snap_version="$(awk '/^version:/{print $2}' /snap/snapcraft/current/meta/snap.yaml)" && echo "export SNAP_VERSION=\"$snap_version\"" >> /snap/bin/snapcraft
RUN echo 'exec "$SNAP/usr/bin/python3" "$SNAP/bin/snapcraft" "$@"' >> /snap/bin/snapcraft
RUN chmod +x /snap/bin/snapcraft

# Multi-stage build, only need the snaps from the builder. Copy them one at a
# time so they can be cached.
FROM arm32v7/ubuntu:18.04
COPY --from=builder /snap/core /snap/core
COPY --from=builder /snap/snapcraft /snap/snapcraft
COPY --from=builder /snap/bin/snapcraft /snap/bin/snapcraft


# Set the proper environment
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV PATH="/snap/bin:$PATH"
ENV SNAP="/snap/snapcraft/current"
ENV SNAP_NAME="snapcraft"
ENV SNAP_ARCH="amrhf"

COPY qemu-arm-static /usr/bin/

RUN ln -sf /bin/bash /bin/sh
# Generate locale
RUN apt-get update && apt-get dist-upgrade --yes && apt-get install --yes sudo locales && locale-gen en_US.UTF-8

RUN apt-get install -y \
    git \
    openssh-server \
    build-essential \
    python2.7 \
    python2.7-dev \
    python-setuptools \
    python3-setuptools \
    python3-dev \
    python3-pip \
    make \
    g++

