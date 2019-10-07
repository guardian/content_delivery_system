FROM ubuntu:latest

COPY dockerbuild/base_setup.sh /tmp
RUN bash -e /tmp/base_setup.sh && rm -f /tmp/base_setup.sh
