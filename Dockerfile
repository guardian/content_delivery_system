FROM ubuntu:latest

COPY dockerbuild/base_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/base_setup.sh
COPY dockerbuild/perl_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/perl_setup.sh
COPY dockerbuild/ruby_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/ruby_setup.sh
COPY dockerbuild/js_setup.sh dockerbuild/package.json /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/js_setup.sh
COPY dockerbuild/ffmpeg_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/ffmpeg_setup.sh
ADD CDS /usr/src/CDS
COPY dockerbuild/cds_setup.sh /tmp/dockerbuild/
RUN bash -e /tmp/dockerbuild/cds_setup.sh
COPY tests/runtests.sh /usr/src/CDS
