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

# Install Erlang/OTP directly
RUN wget https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/otp_src_${OTP_VERSION}.tar.gz && \
    tar -xzf otp_src_${OTP_VERSION}.tar.gz && \
    cd otp_src_${OTP_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf otp_src_${OTP_VERSION} otp_src_${OTP_VERSION}.tar.gz

# Install Elixir directly
RUN wget https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-26.zip && \
    unzip elixir-otp-26.zip -d /usr/local && \
    rm elixir-otp-26.zip

# Install fwup directly
RUN wget https://github.com/fwup-home/fwup/releases/download/v${NERVES_BOOTSTRAP_VERSION}/fwup_${NERVES_BOOTSTRAP_VERSION}_amd64.deb && \
    dpkg -i fwup_${NERVES_BOOTSTRAP_VERSION}_amd64.deb && \
    rm fwup_${NERVES_BOOTSTRAP_VERSION}_amd64.deb

# Update PATH to include Elixir binaries
ENV PATH="/usr/local/bin:${PATH}"
