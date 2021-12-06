#!/bin/bash
#Scrip to create a tunnel to
#the CMS DBs
ssh \
    -L 10131:cmsrac31-v.cern.ch:10121 \
    -L 10132:cmsrac32-v.cern.ch:10121 \
    -L 10141:cmsrac41-v.cern.ch:10121 \
    -L 10142:cmsrac42-v.cern.ch:10121 \
    -L 10101:itrac1601-v.cern.ch:10121 \
    -L 10109:itrac1609-v.cern.ch:10121 \
  userName@lxplus7.cern.ch
