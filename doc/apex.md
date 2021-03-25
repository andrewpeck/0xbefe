# APEX
## MGT mapping
The following table shows how the front panel ports on the prototype board at 904 are mapped to MGTs and refclks
|  Column 1 MGT loc  |  Column 2 MGT loc  |
|--------------------|--------------------|
| X                  | X                  |
| X                  | X                  |
| X                  | X                  |
| X                  | X                  |
| X                  | X                  |
| X                  | X                  |
| 224 (GTH X0Y0-3)   | 226 (GTH X0Y8-11)  |
| X                  | 225 (GTH X0Y4-7)   |
| 128 (GTY X0Y4-7)   | 127 (GTY X0Y0-3)   |
| 129 (GTY X0Y8-11)  | 130 (GTY X0Y12-15) |
| 131 (GTY X0Y16-19) | 132 (GTY X0Y20-23) |
| 134 (??)           | 134 (GTY X0Y28-31) |
| 233 (GTH X0Y36-39) | 234 (GTH X0Y40-43) |

Refclk connections:
| Refclk in schematics | refclk in fw  | MGT |
|----------------------|---------------|-----|
| SCLK2 / ACLK2        | gth_refclk(0) | 226 |
| SCLK1 / ACLK1        | gth_refclk(1) | 229 |
| SCLK0 / ACLK0        | gth_refclk(2) | 232 |
| SCLK0 / ACLK0        | gty_refclk(0) | 128 |
| SCLK1 / ACLK1        | gty_refclk(1) | 131 |
| SCLK2 / ACLK2        | gty_refclk(2) | 134 |

