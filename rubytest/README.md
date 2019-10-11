# rubytest

This directory contains the source for the `guardianmultimedia/cds-rubytest` docker
image which is used for (quickly) running Ruby tests standalone or in CI

## Usage

```
$ docker run --rm -v $PWD:/usr/src/cds -w /usr/src/cds/CDS/Ruby/PLUTO guardianmultimedia/cds-rubytest:1 rake spec
```
will run the tests for the PLUTO integration gem