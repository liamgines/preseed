preseed
========

A script for creating a preseeded debian iso.

Usage
--------
First, download a debian iso.

Then create a preseed configuration file (e.g. `preseed.cfg`) that will be referenced when automating part of the install.

Finally, provide the script with the names of the iso and configuration file and run it:

    ./seed.sh debian-amd64-netinst.iso preseed.cfg
