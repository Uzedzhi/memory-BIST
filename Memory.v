`ifndef _BIST_MEMORY
`define _BIST_MEMORY

// ----------------------Однопортовая память с column redundancy------------------
// Синхронная память DEPTH x WIDTH с поддержкой ремонта одной колонки.
// После получения red_en фиксирует номер дефектной колонки
// и дальше при каждом обращении подменяет бит этой колонки на бит из SpareColumn
// PARAMS:      DEPTH        - кол-во строк памяти
//              WIDTH        - ширина строки памяти
// INPUTS:      clock        - тактовый сигнал
//              reset        - синхронный сброс
//              ce           - флаг включения чипа (chip enable)
//              we           - флаг включения записи (write enable)
//              red_en       - импульс включения ремонта
//              DefectColumn - номер дефектной колонки, которую нужно чинить
//              addr         - адрес обращения
//              data_in      - входные данные для записи
// OUTPUTS:     data_out     - считанные данные
//              red_done     - флаг завершения ремонта
// ---------------------------------------------------------------------------------
module memory #(
    parameter DEPTH         = `DEPTH,
    parameter WIDTH         = `WIDTH,
    parameter DEFECT_TYPE   = `_MEMORY_DEFECT_NONE
)(
    input clock,
    input ce,
    input we,


    input      [`DATA_W:0] DefectColumn,
    input      [`ADDR_W - 1:0] addr,         
    input      [WIDTH   - 1:0] data_in,
    output reg [WIDTH   - 1:0] data_out
);
    real cur_time = 0;

    reg [WIDTH   - 1:0] ram [0:DEPTH - 1];
    reg [DEPTH   - 1:0] SpareColumn;
    
    generate
        for (genvar i = 0; i < DEPTH; i = i+1) begin
            for (genvar j = 0; j < WIDTH; j = j+1) begin
                always @(posedge clock) begin
                    if (ce & we & addr == i) begin
                        if (DefectColumn != 0 && j == DefectColumn - 1) begin
                            SpareColumn[i] <= data_in[j];
                        end else begin
                            if (i == `DEFECT_ROW & j == `DEFECT_COLUMN) begin
                                ram[i][j] <= (DEFECT_TYPE == `_MEMORY_DEFECT_SAF_1)                                             ? 1 :               // stuck at 1
                                             (DEFECT_TYPE == `_MEMORY_DEFECT_SAF_0)                                             ? 0 :               // stuck at 0
                                             (DEFECT_TYPE == `_MEMORY_DEFECT_TF_0    & data_in[j] === 0 & ram[i][j] === 1)        ? 1 :               // failed to traisition from 1 to 0
                                             (DEFECT_TYPE == `_MEMORY_DEFECT_TF_1    & data_in[j] === 1 & ram[i][j] === 0)        ? 0 :               // failed to traisition from 0 to 1
                                             (DEFECT_TYPE == `_MEMORY_DEFECT_DRF_0   & $realtime - cur_time >= `_DRF_MAX_DELAY) ? 0 :               // dropped to 0 after long time with no action
                                             (DEFECT_TYPE == `_MEMORY_DEFECT_DRF_1   & $realtime - cur_time >= `_DRF_MAX_DELAY) ? 1 : data_in[j];   // dropped to 1 after long time with no action
                                cur_time <= $realtime;
                            end else begin
                                ram[i][j] <= data_in[j];
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    // далее не нужно волноваться о записи, она запишется автоматически
    // в одном из многих блоков сверху
    generate
        for (genvar j = 0; j < WIDTH; j = j+1) begin
            always @(posedge clock) begin
                if (ce & ~we) begin // только чтение
                    if (DefectColumn != 0 & j == DefectColumn - 1)
                        data_out[j] <= SpareColumn[addr];
                    else begin
                        if (addr == `DEFECT_ROW & j == `DEFECT_COLUMN)
                            cur_time <= $realtime;
                        data_out[j] <= ram[addr][j];
                    end
                end
            end
        end
    endgenerate
endmodule

`endif // _BIST_MEMORY