`include "BIST.v"
`include "Memory.v"
`include "GetBitPos.v"

module dontuse_memory #(
    parameter DEPTH = `DEPTH,
    parameter WIDTH = `WIDTH
)(
    input clock,
    input reset,

    input ce,
    input err_en,
    input [`ADDR_W - 1:0] DefectRow
);
endmodule

// ---------------------------Управляющий модуль для BIST и памяти-------------------------------
// организует последовательность проверок:
// Первый запуск BIST -> проверка результата -> если ошибок нет, заканчиваем;
// если есть - передаем памяти номер битой колонки, включаем redundancy ->
// запускаем BIST второй раз -> проверяем результат снова -> показываем итог
// PARAMS:      DEPTH             - кол-во строк памяти
//              WIDTH             - ширина строки памяти
//              DELAY_TICKS       - задержка в тактах для проверки DRF
// INPUTS:      clock             - тактовый сигнал
//              en                - запуск всей проверки
//              reset             - синхронный сброс в IDLE
// MERMORY_IN:  data_out          - считанные данные
//              red_done          - флаг завершения ремонта
// MEMORY_OUT:  ce                - флаг включения чипа (chip enable)
//              we                - флаг включения записи (write enable)
//              red_en            - импульс включения ремонта
//              DefectColumn      - номер дефектной колонки, которую нужно чинить
//              addr              - адрес обращения
//              data_in           - входные данные для записи
// OUTPUTS:     TestFinish        - вся последовательность(обе проверки) завершена
//              ErrOnFirstCheck   - была ошибка при первом прогоне(до ремонта)
//              ErrOnSecondCheck  - ошибка осталась и после ремонта
// ------------------------------------------------------------------------------------------------
module controller #(
    parameter DEPTH         = `DEPTH,
    parameter WIDTH         = `WIDTH,
    parameter DELAY_TICKS   = `DELAY_TICKS
)(
    input clock,
    input en,
    input reset,

    output TestFinish,

// for memory interface
    output ce,
    output we,
    output red_en,
    output [`DATA_W - 1:0] DefectColumn,
    output [`ADDR_W - 1:0] addr,
    output [WIDTH   - 1:0] data_in,

    input  [WIDTH   - 1:0] data_out,
    input red_done
);


// -----------------------Testing module instantiation-----------------------
    wire was_err, Finish;
    wire  [`ADDR_W - 1:0]  DefectRow;
    wire Enable;

    BIST #(
        .DELAY_TICKS(DELAY_TICKS)
    ) CNT_BIST (
        .clock(clock),
        .Enable(Enable),
        .reset(reset),

        .Finish(Finish),
        .DefectRow(DefectRow),
        .DefectColumn(DefectColumn),
        .was_err(was_err),
        .new_err(new_err),

        .ce(ce),
        .we(we),
        .AddrCounter(addr),
        .data_in(data_in),
        .data_out(data_out)
    );
// ---------------------------------------------------------------------------


// ---------------------DONTUSE interface------------------------
    reg dontuse_rows_en;
    dontuse_memory DontUse (
        .clock(clock),
        .reset(reset),

        .ce(dontuse_rows_en),
        .err_en(new_err),
        .DefectRow(DefectRow)
    );
// --------------------------------------------------------------


    localparam IDLE         = 'h0;
    localparam CHECK_1      = 'h1;
    localparam SEND_RED_1   = 'h2;
    localparam SEND_RED_2   = 'h3;
    localparam WAIT         = 'h4;
    localparam CHECK_2      = 'h5;
    localparam FINISH       = 'h6;


// ---------------------------------------State---------------------------------------------
    reg  [2:0] state;
    wire [2:0] next_state;
    always @(posedge clock)
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
// -----------------------------------------------------------------------------------------

// ------------------------------------Next State------------------------------------------
    wire is_IDLE = (state == IDLE) | (state == FINISH);
    assign next_state = (is_IDLE             & en)                  ? CHECK_1     :
                        (state == CHECK_1    & Finish & ~was_err)   ? FINISH      :
                        (state == CHECK_1    & Finish &  was_err)   ? SEND_RED_1  :
                        (state == SEND_RED_1)                       ? SEND_RED_2  :
                        (state == SEND_RED_2 & red_done)            ? WAIT        :
                        (state == WAIT       & Finish == 0)         ? CHECK_2     :
                        (state == CHECK_2    & Finish)              ? FINISH      : state;
// -----------------------------------------------------------------------------------------

    assign TestFinish = (state == FINISH);
    assign red_en     = (state == SEND_RED_1);
    assign Enable     = (is_IDLE) ? en : (state == SEND_RED_2);

    always @(posedge clock) begin
        if (reset)
            dontuse_rows_en <= 0;
        else
            dontuse_rows_en <= (state == CHECK_2 & state != FINISH);
    end
    
endmodule