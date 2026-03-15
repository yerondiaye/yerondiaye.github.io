#!/usr/bin/env bash

rev < "meta/$CYC_FILE.title"
#           ^^^^^^^^^ this is supplied by cyc

# In the example setup, CYC_FILE is index.html because this script will be
# called by content/index.html. What the above line does is read the title
# of the page from the metadata folder and put it through rev.
