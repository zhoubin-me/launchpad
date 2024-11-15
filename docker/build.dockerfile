ARG cpu_base_image="tensorflow/build:latest-python3.12"
ARG base_image=$cpu_base_image
FROM $base_image
LABEL maintainer="no-reply@google.com"

# Re-declare args because the args declared before FROM can't be used in any
# instruction after a FROM.
ARG python_version="python3.12"
ARG APT_COMMAND="apt-get -o Acquire::Retries=3 -y"

# Stops tzdata from asking about timezones and blocking install on user input.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Pick up some TF dependencies
RUN ${APT_COMMAND} update && ${APT_COMMAND} install -y --no-install-recommends \
        software-properties-common \
        aria2 \
        build-essential \
        curl \
        git \
        less \
        libfreetype6-dev \
        libhdf5-serial-dev \docker build --tag launchpad:devel - < docker/build.dockerfile
        docker run --rm --mount "type=bind,src=$PWD,dst=/tmp/launchpad" \
          -it launchpad:devel /tmp/launchpad/oss_build.sh
        libpng-dev \
        libzmq3-dev \
        lsof \
        pkg-config \
        python3.12-dev \
        rename \
        rsync \
        sox \
        unzip \
        vim \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -O https://bootstrap.pypa.io/get-pip.py

# Installs known working version of bazel.
# ARG bazel_version=6.1.0
# ENV BAZEL_VERSION ${bazel_version}
# RUN mkdir /bazel && \
#     cd /bazel && \
#     curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
#     chmod +x bazel-*.sh && \
#     ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
#     cd / && \
#     rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

RUN pip install \
      absl-py \
      contextlib2 \
      dataclasses \
      dm-tree>=0.1.5 \
      h5py \
      mock \
      oauth2client \
      pandas \
      portpicker

RUN pip install tensorflow==2.18.0 --upgrade
RUN pip install numpy==2.1.3

# Removes existing links so they can be created to point where we expect.
RUN rm /dt9/usr/include/x86_64-linux-gnu/python3.12

# Needed until this is included in the base TF image.
RUN ln -s "/usr/include/x86_64-linux-gnu/python3.12" "/dt9/usr/include/x86_64-linux-gnu/python3.12"

# bazel build -c opt --copt=-mavx --config=manylinux2014 --test_output=errors //...

# Update binutils to avoid linker(gold) issue. See b/227299577#comment9
# RUN \
#  wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_2.35.1-1ubuntu1_amd64.deb \
#  && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-x86-64-linux-gnu_2.35.1-1ubuntu1_amd64.deb \
#  && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-common_2.35.1-1ubuntu1_amd64.deb \
#  && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/libbinutils_2.35.1-1ubuntu1_amd64.deb

# RUN \
#   dpkg -i binutils_2.35.1-1ubuntu1_amd64.deb \
#             binutils-x86-64-linux-gnu_2.35.1-1ubuntu1_amd64.deb \
#             binutils-common_2.35.1-1ubuntu1_amd64.deb \
#             libbinutils_2.35.1-1ubuntu1_amd64.deb
WORKDIR "/tmp/launchpad"
CMD ["/bin/bash"]
