FROM ubuntu:20.04

ARG OTP_VERSION=26.2.5
ARG ELIXIR_VERSION=1.18.4-otp-26
ARG NERVES_BOOTSTRAP_VERSION=1.13.0

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root

# We run as root to avoid permissions issues with the GitHub Actions runner.

# Install required repositories and packages, excluding cmake for now
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get install -y \
        pkg-config build-essential ninja-build automake autoconf libtool wget curl git libssl-dev bc squashfs-tools android-sdk-libsparse-utils \
        jq tclsh scons parallel ssh-client tree python3-dev python3-pip device-tree-compiler libssl-dev ssh cpio \
        fakeroot flex bison mtools gcc-11 g++-11 libbz2-dev zip unzip \
        android-sdk-ext4-utils python3-distutils slib libncurses5 rsync xxd libncurses-dev \
        ssh-askpass libmnl-dev libnl-genl-3-dev libncurses5-dev help2man libconfuse-dev libarchive-dev \
        libncurses-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
        libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses5-dev openjdk-11-jdk && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 60 && \
    pip3 install jinja2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install cmake 3.16.5 manually
RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.5/cmake-3.16.5-Linux-x86_64.tar.gz && \
    tar --strip-components=1 -xz -C /usr/local -f cmake-3.16.5-Linux-x86_64.tar.gz && \
    rm cmake-3.16.5-Linux-x86_64.tar.gz

# Make python3 available as python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install asdf for the root user
ENV ASDF_DIR="/root/.asdf"
ENV PATH="/root/.asdf/bin:/root/.asdf/shims:${PATH}"
SHELL ["/bin/bash", "-c"]

RUN git clone https://github.com/asdf-vm/asdf.git /root/.asdf --branch v0.14.0 && \
    echo -e '\n. /root/.asdf/asdf.sh' >> /root/.bashrc && \
    echo -e '\n. /root/.asdf/completions/asdf.bash' >> /root/.bashrc && \
    echo -e '\n. /root/.asdf/asdf.sh' >> /root/.profile

# Install all asdf plugins and tools in a single RUN command to ensure persistence
RUN source /root/.asdf/asdf.sh && \
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf plugin add fwup https://github.com/fwup-home/asdf-fwup.git && \
    asdf install erlang ${OTP_VERSION} && \
    asdf install elixir ${ELIXIR_VERSION} && \
    asdf install fwup ${NERVES_BOOTSTRAP_VERSION} && \
    asdf global erlang ${OTP_VERSION} && \
    asdf global elixir ${ELIXIR_VERSION} && \
    asdf global fwup ${NERVES_BOOTSTRAP_VERSION} && \
    asdf reshim
