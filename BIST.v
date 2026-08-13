`ifndef _BIST_MAIN
`define _BIST_MAIN

`include "BIST_h.v"
`include "Memory.v"

// ----------------------BIST для однопортовой памяти-------------------------
// Проверяемые ошибки: DRF, TF, SAF
// Синтезируемый модуль, прогоняющий march-тест по всем адресам памяти:
// пишет 1 -> ждет DELAY_TICKS тактов -> читает и сверяет с 1 ->
// пишет 0 -> ждет DELAY_TICKS тактов -> читает и сверяет с 0.
// При несовпадении определяет через GetBitPos позицию сбойного бита
// Если ошибка в несокльких битах, выставляет was_fatal_err
// PARAMS:      DEPTH         - кол-во строк памяти
//              WIDTH         - ширина строки памяти
//              DELAY_TICKS   - задержка в тактах перед чтением(для DRF)
// INPUTS:      clock         - тактовый сигнал
//              Enable        - запуск теста
//              reset         - синхронный сброс в IDLE
//              data_out      - считанные из памяти данные
// OUTPUTS:     Finish        - тест завершен
//              was_err       - было хотя бы одно несовпадение при чтении
//              was_fatal_err - ошибка в нескольких битах
//              new_err       - ошибка только что произошла(флаг валидности DefectRow/DefectColumn)
//              DefectRow     - адрес строки со сбоем
//              DefectColumn  - позиция сбойного бита в строке
//              ce, we        - управление памятью
//              AddrCounter   - текущий адрес обращения к памяти
//              data_in       - данные, записываемые в память
// -----------------------------------------------------------------------------
module BIST #( 
    parameter DEPTH       = `DEPTH,
    parameter WIDTH       = `WIDTH,
    parameter DELAY_TICKS = 4
)(
    input clock,
    input Enable,
    input reset,

    // to controller
    output Finish,
    output reg was_err,
    output reg was_fatal_err,
    output reg new_err,
    output reg [`ADDR_W - 1:0] DefectRow,
    output reg [`DATA_W:0] DefectColumn,

    // to memory
    output reg ce,
    output reg we,
    output reg [`ADDR_W - 1:0] AddrCounter,
    output reg [WIDTH   - 1:0] data_in,
    input      [WIDTH   - 1:0] data_out

);
// -------------localparams for FSM state----------------
    localparam [3:0] IDLE        = 'h0; // state after reset, Enable -> INIT0
    localparam [3:0] INIT0       = 'h1;
    localparam [3:0] WRITE1      = 'h2;
    localparam [3:0] DELAY_1     = 'h3;
    localparam [3:0] READ1       = 'h4;
    localparam [3:0] WRITE0      = 'h5;
    localparam [3:0] DELAY_2     = 'h6;
    localparam [3:0] READ0       = 'h7;
    localparam [3:0] FINISH      = 'h8; // state after finishing testing, Enable -> INIT0
// ------------------------------------------------------

    reg  [WIDTH                 - 1:0]  ExpValue;
    reg  [$clog2(DELAY_TICKS)   - 1:0]  DelayCounter;
    reg  [$clog2(FINISH + 1)    - 1:0]  state;
    wire [$clog2(FINISH + 1)    - 1:0]  next_state;
    reg restart;

    wire is_DELAY           = (state == DELAY_1 | state == DELAY_2);
    wire is_IDLE            = (state == IDLE    | state == FINISH);
    wire is_DelayC_done     = (DelayCounter == DELAY_TICKS - 1);
    wire is_AddrC_done      = (AddrCounter  == DEPTH       - 1);
    assign Finish           = (state == FINISH);

// ---------------------------state------------------------------
    assign next_state = (is_IDLE  & Enable)                         ? INIT0     :
                        (is_IDLE  & ~Enable)                        ? state     :
                        (is_DELAY & is_DelayC_done | is_AddrC_done) ? state + 1 : state;
    
    always @(posedge clock)
        if (reset)
            state <= IDLE;
        else
            state <= (restart) ? INIT0 : next_state;
// --------------------------------------------------------------

// ----------------------ColumnCounter---------------------------
    // Isolated Bit Pos module instantiation
    wire [WIDTH   - 1:0] Vec;
    wire [`DATA_W - 1:0] Column;
    wire is_onehot;
    GetBitPos #(
        .BIT_WIDTH(WIDTH)
    ) GetColumn (
        .Vec(Vec),
        .BitPos(Column),
        .is_onehot(is_onehot)
    );

    assign Vec = (ExpValue ^ data_out);
// --------------------------------------------------------------

// ---------------------------ERR--------------------------------
    reg was_READ;
    wire is_READ = (state == READ1 | state == READ0);
    always @(posedge clock)
        was_READ <= is_READ;

    wire err = was_READ & (ExpValue     != data_out);
    always @(posedge clock) begin
        DefectColumn <= (err) ? Column      + 1 : DefectColumn;
        DefectRow    <= (err) ? AddrCounter - 1 : DefectRow;
    end

    wire is_fatal_err = new_err & (DefectColumn != Column + 1 | ~is_onehot);
    always @(posedge clock)
        if (reset | restart) begin
            was_err         <= 0;
            new_err         <= 0;
            was_fatal_err   <= 0;
        end else begin
            new_err         <= err;
            was_err         <= was_err | err;
            was_fatal_err   <= was_fatal_err | is_fatal_err;
        end
// --------------------------------------------------------------

// -----------------------AddrCounter----------------------------
    always @(posedge clock)
        if (reset | restart)
            AddrCounter <= 0;
        else
            AddrCounter <=  (is_IDLE | is_DELAY) ? AddrCounter     :
                            (~is_AddrC_done)     ? AddrCounter + 1 : 0;
// --------------------------------------------------------------

// -------------------------Restart------------------------------
    always @(posedge clock)
        restart <= (state == FINISH) & Enable;
// --------------------------------------------------------------

// ----------------------Delay Counter---------------------------
    always @(posedge clock)
        if (reset | restart)
            DelayCounter <= 0;
        else
            DelayCounter <= (~is_DELAY)       ? DelayCounter     :
                            (~is_DelayC_done) ? DelayCounter + 1 : 0;
// --------------------------------------------------------------

// ------------------What all those states do--------------------
    always @(posedge clock) begin
        case (next_state)
            FINISH, IDLE, DELAY_1, DELAY_2:   ce <= 0;
            INIT0, WRITE0:              begin ce <= 1;   we <= 1; data_in  <= {WIDTH{1'b0}}; end
            WRITE1:                     begin ce <= 1;   we <= 1; data_in  <= {WIDTH{1'b1}}; end
            READ1:                      begin ce <= 1;   we <= 0; ExpValue <= {WIDTH{1'b1}}; end
            READ0:                      begin ce <= 1;   we <= 0; ExpValue <= {WIDTH{1'b0}}; end
            default:                    begin ce <= 'bx; we <= 'bx; end
        endcase
    end
// --------------------------------------------------------------
endmodule



`endif