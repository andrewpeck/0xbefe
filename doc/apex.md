# APEX
## MGT mapping
The following table shows how the front panel ports on the prototype board at 904 are mapped to MGTs and refclks

| FPGA                   | Col 1 MGT loc      | Col 1 FW link    | Col 2 MGT loc      | Col 2 FW link               |
|:---------------------- | ------------------ | ---------------- | ------------------ | --------------------------- |
| Top (904 rev 2 CSC)    | 224 (GTH X0Y0-3)   |                  | 127 (GTY X0Y0-3)   |                             |
| Top (904 rev 2 CSC)    | 225 (GTH X0Y4-7)   |                  | 128 (GTY X0Y4-7)   | 0-3 -- DMB,DMB,lDAQ,X (40G) |
| Top (904 rev 2 CSC)    | 129 (GTY X0Y8-11)  |                  | 130 (GTY X0Y12-15) | 4-7 -- ODMB7 (100G)         |
| Top (904 rev 2 CSC)    | 131 (GTY X0Y16-19) |                  | 132 (GTY X0Y20-23) | SlinkRocket (100G)          |
| Top (904 rev 2 CSC)    | 134 (GTY X0Y28-31) |                  | 133 (GTY X0Y24-27) |                             |
| Top (904 rev 2 CSC)    | 234 (GTH X0Y40-43) |                  | 233 (GTH X0Y36-39) |                             |
| Bottom (904 rev 1 GEM) | 224 (GTH X0Y0-3)   |                  | 226 (GTH X0Y8-11)  |                             |
| Bottom (904 rev 1 GEM) | X                  |                  | 225 (GTH X0Y4-7)   |                             |
| Bottom (904 rev 1 GEM) | 128 (GTY X0Y4-7)   |                  | 127 (GTY X0Y0-3)   |                             |
| Bottom (904 rev 1 GEM) | 129 (GTY X0Y8-11)  | 0-3 -- GBT (40G) | 130 (GTY X0Y12-15) | 8-11 -- lDAQ (40G)          |
| Bottom (904 rev 1 GEM) | 131 (GTY X0Y16-19) | 4-7 -- GBT (40G) | 132 (GTY X0Y20-23) | SlinkRocket (100G)          |
| Bottom (904 rev 1 GEM) | 133 (GTY X0Y24-27) |                  | 134 (GTY X0Y28-31) |                             |
| Bottom (904 rev 1 GEM) | 233 (GTH X0Y36-39) |                  | 234 (GTH X0Y40-43) |                             |

Refclk connections:

| Refclk in schematics | refclk in fw  | MGT |
|----------------------|---------------|-----|
| SCLK2 / ACLK2        | gth_refclk(0) | 226 |
| SCLK1 / ACLK1        | gth_refclk(1) | 229 |
| SCLK0 / ACLK0        | gth_refclk(2) | 232 |
| SCLK0 / ACLK0        | gty_refclk(0) | 128 |
| SCLK1 / ACLK1        | gty_refclk(1) | 131 |
| SCLK2 / ACLK2        | gty_refclk(2) | 134 |
