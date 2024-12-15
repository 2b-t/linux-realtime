FROM ubuntu:latest

ENV WS_DIR="/benchmark"
WORKDIR ${WS_DIR}

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# Dependencies for latency plot
RUN apt-get update \
 && apt-get install -y \
    build-essential \
    curl \
    gnuplot-qt \
    libnuma-dev \
    make \
    python3 \
 && rm -rf /var/lib/apt/lists/*

# Dependencies for Bash unit-tests
RUN apt-get update \
 && apt-get install -y \
    bats \
    dialog \
    tmux \
 && rm -rf /var/lib/apt/lists/*

# Cyclictest and mklatencyplot
RUN apt-get update \
 && apt-get install -y \
    rt-tests \
 && rm -rf /var/lib/apt/lists/* \
 && cd ${WS_DIR} \
 && curl -SLO --fail https://www.osadl.org/uploads/media/mklatencyplot.bash \
 && sed -i -E "s/(cores=).*/\1\$(nproc)/" mklatencyplot.bash \
 && chmod +x mklatencyplot.bash

ARG DEBIAN_FRONTEND=dialog

