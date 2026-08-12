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
    parameter DEPTH     = `DEPTH,
    parameter WIDTH     = `WIDTH
)(
    input clock,
    input reset,
    input ce,
    input we,
    input red_en,


    input      [`DATA_W  - 1:0] DefectColumn,
    input      [`ADDR_W  - 1:0] addr,         
    input      [WIDTH   - 1:0] data_in,
    output reg [WIDTH   - 1:0] data_out,
    output reg red_done
);
    // ram - внутренняя память модуля
    reg [WIDTH   - 1:0] ram [0:DEPTH - 1];

    reg [`DATA_W - 1:0] DefectColumnInner;
    reg [DEPTH   - 1:0] SpareColumn;
    
    reg was_red_en;
    always @(posedge clock) 
        if (reset)
            was_red_en <= 0;
        else
            was_red_en <= was_red_en | red_en;

    // много always блоков каждый проверяет что адрес совпадает 
    // со своим номером. Если это так, то data_in записывается
    // именно по этому номеру в память
    generate
        for (genvar i = 0; i < DEPTH; i = i+1) begin
            for (genvar j = 0; j < WIDTH; j = j+1) begin
                always @(posedge clock) begin
                    if (ce & we & addr == i) begin
                        if (was_red_en & j == DefectColumnInner) begin
                            SpareColumn[i] <= data_in[j];
                        end else begin
                            if (i == `DEFECT_ROW & j == `DEFECT_COLUMN)
                                ram[i][j] <= ~data_in[j];
                            else
                                ram[i][j] <=  data_in[j];
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
                    if (was_red_en & j == DefectColumnInner) begin
                        data_out[j] <= SpareColumn[addr];
                    end else
                        data_out[j] <= ram[addr][j];
                end
            end
        end
    endgenerate

    always @(posedge clock)
        if (reset) red_done <= 0;
        else       red_done <= red_en;

    always @(posedge clock) begin
        DefectColumnInner <= (red_en) ? DefectColumn : DefectColumnInner;
    end
endmodule

`endif // _BIST_MEMORY