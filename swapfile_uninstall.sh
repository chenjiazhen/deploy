#!/bin/bash

# check permission
if [ `id -u` != '0' ]; then
  echo 'Error: You must be root to run this script'
  exit 1
fi

swapoff /swapfile
rm -fr /swapfile  

echo 'Uninstalled successfully'