FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install sudo and add a non-root user with UID and GID 1000
RUN apt-get update && \
    apt-get install -y sudo && \
    groupadd -g 1000 user && \
    useradd -m -u 1000 -g 1000 -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

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
        ssh-askpass libmnl-dev libnl-genl-3-dev libncurses5-dev help2man libconfuse-dev libarchive-dev && \
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

# Install erlang & elixir with asdf
USER root
RUN apt-get update && \
    apt-get install -y libncurses-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
    libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses5-dev openjdk-11-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER user
WORKDIR /home/user
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0 && \
    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc && \
    echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

ENV PATH="/home/user/.asdf/bin:/home/user/.asdf/shims:${PATH}"
ENV USER=user
SHELL ["/bin/bash", "-c"]

RUN source ~/.asdf/asdf.sh && \
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf install erlang 28.0.1 && \
    asdf global erlang 28.0.1

RUN source ~/.asdf/asdf.sh && \
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf install elixir 1.18.4-otp-28 && \
    asdf global elixir 1.18.4-otp-28

RUN source ~/.asdf/asdf.sh && \
    asdf plugin add fwup https://github.com/fwup-home/asdf-fwup.git && \
    asdf install fwup 1.13.0 && \
    asdf global fwup 1.13.0
