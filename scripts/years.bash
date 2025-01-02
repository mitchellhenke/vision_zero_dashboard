#!/usr/bin/env bash

if [ "$(date +'%-m')" -eq 1 ] && [ "$(date +'%-d')" -lt 7 ] ; then
  echo "$(($(date +'%Y') - 1))"
else
  echo "$(date +'%Y'),$(($(date +'%Y') - 1))"
fi
