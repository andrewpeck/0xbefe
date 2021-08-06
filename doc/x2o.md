# X2O Octopus

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

## ARF6 to MGT mapping

J5: left back #1 (counting from bottom up with FPGA facing up):

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 132 | 0        | YES      |
| RX 1      | 132 | 0        | NO       |
| TX 2      | 134 | 2        | YES      |
| RX 2      | 134 | 2        | NO       |
| TX 3      | 135 | 2        | YES      |
| RX 3      | 132 | 2        | NO       |
| TX 4      | 135 | 0        | YES      |
| RX 4      | 135 | 0        | NO       |
| TX 5      | 132 | 2        | YES      |
| RX 5      | 133 | 0        | NO       |
| TX 6      | 134 | 0        | YES      |
| RX 6      | 135 | 2        | NO       |
| TX 7      | 133 | 0        | YES      |
| RX 7      | 133 | 2        | NO       |
| TX 8      | 133 | 2        | YES      |
| RX 8      | 134 | 0        | NO       |

J15: left back #2 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 128 | 0        | YES      |
| RX 1      | 128 | 0        | NO       |
| TX 2      | 131 | 2        | YES      |
| RX 2      | 131 | 2        | NO       |
| TX 3      | 128 | 2        | YES      |
| RX 3      | 128 | 2        | NO       |
| TX 4      | 131 | 0        | YES      |
| RX 4      | 131 | 0        | NO       |
| TX 5      | 129 | 0        | YES      |
| RX 5      | 129 | 0        | NO       |
| TX 6      | 130 | 2        | YES      |
| RX 6      | 130 | 2        | NO       |
| TX 7      | 129 | 2        | YES      |
| RX 7      | 129 | 2        | NO       |
| TX 8      | 130 | 0        | YES      |
| RX 8      | 130 | 0        | NO       |

J12: left back #3 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 124 | 0        | NO       |
| RX 1      | 124 | 0        | YES      |
| TX 2      | 127 | 2        | NO       |
| RX 2      | 127 | 2        | YES      |
| TX 3      | 124 | 2        | NO       |
| RX 3      | 124 | 2        | YES      |
| TX 4      | 127 | 0        | NO       |
| RX 4      | 127 | 0        | YES      |
| TX 5      | 125 | 0        | NO       |
| RX 5      | 125 | 0        | YES      |
| TX 6      | 126 | 2        | NO       |
| RX 6      | 126 | 2        | YES      |
| TX 7      | 125 | 2        | NO       |
| RX 7      | 125 | 2        | YES      |
| TX 8      | 126 | 0        | NO       |
| RX 8      | 126 | 0        | YES      |

J19: left back #4 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 120 | 2        | NO       |
| RX 1      | 120 | 2        | YES      |
| TX 2      | 123 | 2        | NO       |
| RX 2      | 123 | 2        | YES      |
| TX 3      | 121 | 0        | NO       |
| RX 3      | 120 | 0        | YES      |
| TX 4      | 123 | 0        | YES      |
| RX 4      | 123 | 0        | YES      |
| TX 5      | 120 | 0        | NO       |
| RX 5      | 121 | 0        | YES      |
| TX 6      | 122 | 2        | NO       |
| RX 6      | 122 | 2        | YES      |
| TX 7      | 121 | 2        | NO       |
| RX 7      | 121 | 2        | YES      |
| TX 8      | 122 | 0        | NO       |
| RX 8      | 122 | 0        | YES      |

J6: left top #1 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J16: left top #2 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J11: left top #3 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J20: left top #4 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J4: Right back #1 (counting from bottom up with FPGA facing up):

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J14: Right back #2 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J7: Right back #3 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 227 | 2        | NO       |
| RX 1      | 227 | 2        | NO       |
| TX 2      | 224 | 0        | NO       |
| RX 2      | 224 | 0        | NO       |
| TX 3      | 227 | 0        | NO       |
| RX 3      | 227 | 0        | NO       |
| TX 4      | 224 | 2        | NO       |
| RX 4      | 224 | 2        | NO       |
| TX 5      | 226 | 2        | NO       |
| RX 5      | 226 | 2        | NO       |
| TX 6      | 225 | 0        | NO       |
| RX 6      | 225 | 0        | NO       |
| TX 7      | 226 | 0        | NO       |
| RX 7      | 226 | 0        | NO       |
| TX 8      | 225 | 2        | NO       |
| RX 8      | 225 | 2        | NO       |

J18: Right back #4 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J3: Right top #1 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J13: Right top #2 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |

J10: Right top #3 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      | 224 | 1        | NO       | 
| RX 1      | 224 | 1        | YES      |
| TX 2      | 227 | 3        | NO       |
| RX 2      | 227 | 3        | YES      |
| TX 3      | 224 | 3        | NO       |
| RX 3      | 224 | 3        | YES      |
| TX 4      | 227 | 1        | NO       |
| RX 4      | 227 | 1        | YES      |
| TX 5      | 225 | 1        | NO       |
| RX 5      | 225 | 1        | YES      |
| TX 6      | 226 | 3        | NO       |
| RX 6      | 226 | 3        | YES      |
| TX 7      | 225 | 3        | NO       |
| RX 7      | 225 | 3        | YES      |
| TX 8      | 226 | 1        | NO       |
| RX 8      | 226 | 1        | YES      |

J17: Right top #4 (counting from bottom up with FPGA facing up)

| ARF6 chan | MGT | MGT chan | Inverted |
| --------- | --- | -------- | -------- |
| TX 1      |     |          |          |
| RX 1      |     |          |          |
| TX 2      |     |          |          |
| RX 2      |     |          |          |
| TX 3      |     |          |          |
| RX 3      |     |          |          |
| TX 4      |     |          |          |
| RX 4      |     |          |          |
| TX 5      |     |          |          |
| RX 5      |     |          |          |
| TX 6      |     |          |          |
| RX 6      |     |          |          |
| TX 7      |     |          |          |
| RX 7      |     |          |          |
| TX 8      |     |          |          |
| RX 8      |     |          |          |
