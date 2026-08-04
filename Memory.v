`ifndef _BIST_MEMORY
`define _BIST_MEMORY

// ==============Однопортовая память============================
// PARAMETERS:  DEPTH       - кол-во строк памяти
//              .WIDTH      - ширина строки памяти
// IN:          clock       - тактовый сигнал
//              we          - флаг включения записи(write enable)
//              ce          - флаг включения чипа(chip enable)
//              addr        - адрес куда нужно записать data_in
//              data_in     - входные данные
// OUT:         data_out    - выходная строка памяти
// ===============================================================
module memory #(
    parameter DEPTH     = `DEPTH,
    parameter WIDTH     = `WIDTH,
    parameter ADDR_W    = $clog2(DEPTH)
)(
    input                     clock,
    input                     ce,
    input                     we,
    input      [ADDR_W - 1:0] addr,         
    input      [WIDTH  - 1:0] data_in,
    output reg [WIDTH  - 1:0] data_out
);
    // ram - внутренняя память модуля
    reg [WIDTH - 1:0] ram [0:DEPTH - 1];

    // много always блоков каждый проверяет что адрес совпадает 
    // со своим номером. Если это так, то data_in записывается
    // именно по этому номеру в память
    generate
        for (genvar i = 0; i < DEPTH; i = i+1) begin
            always @(posedge clock) begin
                if (ce & we & addr == i) begin
                    ram[i] <= data_in;
                end
            end
        end
    endgenerate

    // далее не нужно волноваться о записи, она запишется автоматически
    // в одном из многих блоков сверху
    always @(posedge clock) begin
        if (ce & ~we) begin // только чтение
            data_out <= ram[addr];
        end
    end
endmodule

`endif // _BIST_MEMORY