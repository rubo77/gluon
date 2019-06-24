FROM debian:buster-slim

RUN apt update && apt install -y --no-install-recommends \
    ca-certificates \
    file \
    git \
    subversion \
    python \
    build-essential \
    gawk \
    unzip \
    libncurses5-dev \
    zlib1g-dev \
    libssl-dev \
    libelf-dev \
    wget \
    time \
    ecdsautils \
    lua-check \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -d /gluon gluon
RUN mkdir /gluon
RUN chown -R gluon:gluon /gluon

USER gluon
RUN cd /gluon
RUN git clone https://github.com/rubo77/gluon/ gluon
RUN cd gluon

VOLUME /gluon
WORKDIR /gluon

RUN git checkout docker
RUN cp -a docs/site-example/ site ; \
    luacheck . ; if [ $? -gt 0 ]; then exit 1; fi ; \
    make update ; \
    echo "in the max Duration time of 240 minutes it is not possible to make GLUON_TARGET=x86-64" ; \
    echo finished successfull
