#!/bin/bash

echo "checking if the site.conf is a valid lua dict ..."
GLUON_SITEDIR="docs/site-example" lua5.1 scripts/site_config.lua

echo "check bash files ..."
find . -not -path '*/\.*' \
  -type f -exec awk 'FNR == 1 && /^#!.*sh/{print FILENAME}' {} + | \
  while IFS= read -r f; do 
    echo "checking $f ..."
    bash -n "$f"
done

cp -a tests/travis-site/ site
TARGET=ar71xx-generic
echo "build gluon target $TARGET ..."
set -x
make update GLUON_TARGET=$TARGET V=s
make clean GLUON_TARGET=$TARGET V=s
# The real build with build environment uses more than the 3GB storage in the travis VM at the moment:
# DEVICES="DEVICES=tp-link-tl-wr842n-nd-v3"
# there are two cores available.
# CORES="-CORES="-j$CORES$(lscpu|grep -e '^CPU(s):'|xargs|cut -d" " -f2)"
# time make GLUON_TARGET=$TARGET $DEVICES $CORES
