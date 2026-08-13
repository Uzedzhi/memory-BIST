`ifndef _BIST_H
`define _BIST_H

`define CLOCK_TICK 10
`define DELAY_TICKS 4
`define DEFECT_ROW 3
`define DEFECT_COLUMN 2
`define RED_DELAY_MEMORY_TICKS 5
`define _DRF_MAX_DELAY 5 * `CLOCK_TICK
`define NUM_MARCH 9
`define DEPTH 5
`define WIDTH 10
`define ADDR_W $clog2(DEPTH)
`define DATA_W $clog2(WIDTH)


`define _MEMORY_DEFECT_NONE     0
`define _MEMORY_DEFECT_SAF_1    1
`define _MEMORY_DEFECT_SAF_0    2
`define _MEMORY_DEFECT_TF_0     3
`define _MEMORY_DEFECT_TF_1     4
`define _MEMORY_DEFECT_DRF_0    5
`define _MEMORY_DEFECT_DRF_1    6

`endif