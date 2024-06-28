FROM rubylang/ruby:3.2-jammy

RUN apt-get update && \
    apt-get install -y pkg-config libsqlite3-dev build-essential

COPY dockerbuild/base_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/base_setup.sh
COPY dockerbuild/perl_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/perl_setup.sh
COPY dockerbuild/ruby_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/ruby_setup.sh
COPY dockerbuild/ffmpeg_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/ffmpeg_setup.sh
ADD CDS /usr/src/CDS
COPY dockerbuild/cds_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/cds_setup.sh
COPY tests/runtests.sh /usr/src/CDS/
RUN chmod +x /usr/src/CDS/runtests.sh
