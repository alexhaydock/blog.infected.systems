#!/usr/bin/env sh
find ./content/ -iname '*.png' -exec optipng {} \;
