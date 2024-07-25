#!/bin/bash

python3 init_frontend.py
python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 2  -p downlink -r start
python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 1 2 3 -p uplink -r run -t 1440
python3 me0_optical_link_bert_fec.py -s backend -q ME0 -o 0 -g 0 2  -p downlink -r stop
