# X2O Octopus

## X2O QSFP-DD link map

NOTE: the QSFP-DD cage numbers and firmware link numbers are counted from BOTTOM TO TOP (blame Michalis :) ), starting at 0.
Link numbers are sequential from bottom to top, but skipping the QSFP cages dedicated to DTH

| QSFP-DD cage | SLR   | MGTs     | FW link # | FW link usage                    | Connection at b904           |
| ------------ | ----- | -------- | --------- | -------------------------------- | ---------------------------- |
| Cage #14     | SLR 0 | 120, 121 | 52-55     | ME0 OH2                          |                              |
| Cage #13     | SLR 0 | 123, 122 | 48-51     | ME0 OH2                          | FS 100G -- No fiber (faulty?)|
| Cage #12     | SLR 1 | 124      | 44-47     | CSC TTC TX                       | SFP+ 1G -- ME2/1 CCB         |
| Cage #11     | SLR 2 | 128      | 40-43     | CSC GBTX (PROMless)              | FS 40G -- ODMB7              |
| Cage #10     | SLR 2 | 131      | 36-39     | GEM LDAQ                         | FS 100G -- No fiber          |
| Cage #9      | SLR 3 | 132, 135 | 32-35     | ME0 OH0                          | FS 100G -- ME0               |
| Cage #8      | SLR 3 | 134, 135 | 28-31     | ME0 OH0                          | FS 100G -- ME0               |
| Cage #7      | SLR 3 | 234, 235 | 24-27     | ME0 OH1 / GE21 OH0/1             | FS 40G -- GE2/1 M1           |
| Cage #6      | SLR 3 | 232, 235 | 20-23     | ME0 OH1 / GE21 OH2/3             | FS 100G -- No fiber          |
| Cage #5      | SLR 2 | 231      | ---       | DTH DAQ                          | FS 100G -- DTH               |
| Cage #4      | SLR 2 | 228      | 16-19     | CSC DMB (ch 1&2), CSC LDAQ (ch4) | FS 40G -- ch2 ME21, ch3 LDAQ |
| Cage #3      | SLR 1 | 227      | 12-15     |                                  |                              |
| Cage #2      | SLR 1 | 224      | 8-11      |                                  | I2C problem                  |
| Cage #1      | SLR 0 | 223, 222 | 4-7       | ME0 OH3                          |                              |
| Cage #0      | SLR 0 | 220, 221 | 0-3       | ME0 OH3                          |                              |

## Sync refclk

All sync clocks are connected to refclk1

| fw name        | MGT    | Schematic          | SI5395J out |
| -------------- | ------ | ------------------ | ----------- |
| refclk_sync(0) | 121    | SI5395J_VU+_CLK+_0 | 4           |
| refclk_sync(1) | 125    | SI5395J_VU+_CLK+_1 | 5           |
| refclk_sync(2) | 129    | SI5395J_VU+_CLK+_2 | 7           |
| refclk_sync(3) | 133    | SI5395J_VU+_CLK+_3 | 6           |
| refclk_sync(4) | 221    | SI5395J_VU+_CLK+_4 | 0           |
| refclk_sync(5) | 225    | SI5395J_VU+_CLK+_5 | 1           |
| refclk_sync(6) | 229    | SI5395J_VU+_CLK+_6 | 2           |
| refclk_sync(7) | 233    | SI5395J_VU+_CLK+_7 | 3           |
| refclk_sync    | K7 115 | SI5395J_K7_CLK+    | 8           |

## Async refclk

Every quad has a 156.25MHz async clock connected to refclk0
