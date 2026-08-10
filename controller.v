`include "BIST.v"
`include "Memory.v"
`include "GetBitPos.v"

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
    output reg ErrOnFirstCheck,
    output reg ErrOnSecondCheck
);


// -----------------------Testing module instantiation-----------------------
    wire ce, we;
    wire was_err, Finish;
    wire  [`ADDR_W - 1:0]  addr;
    wire  [`ADDR_W - 1:0]  DefectAddr;
    wire  [`DATA_W - 1:0]  DefectColumn;
    wire  [WIDTH   - 1:0]  data_in;
    wire  [WIDTH   - 1:0]  data_out;
    reg Enable;

    BIST #(
        .DELAY_TICKS(DELAY_TICKS)
    ) CNT_BIST (
        .clock(clock),
        .Enable(Enable),
        .reset(reset),

        .Finish(Finish),
        .DefectAddr(DefectAddr),
        .DefectColumn(DefectColumn),
        .was_err(was_err),

        .ce(ce),
        .we(we),
        .AddrCounter(addr),
        .data_in(data_in),
        .data_out(data_out)
    );
// ---------------------------------------------------------------------------

// --------------RAM module instantiation----------------
    reg red_en;
    memory RAM (
        .clock(clock),
        .reset(reset),
        .ce(ce),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .red_en(red_en),
        .DefectColumn(DefectColumn),

        .data_out(data_out),
        .red_done(red_done)
    );
// ------------------------------------------------------

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

// ----------------------------------Errors--------------------------------------------
    always @(posedge clock)
    if (reset) begin
        ErrOnFirstCheck  <= 0;
        ErrOnSecondCheck <= 0;
    end else begin
        ErrOnFirstCheck  <= ErrOnFirstCheck  | (state == CHECK_1 & Finish & was_err);
        ErrOnSecondCheck <= ErrOnSecondCheck | (state == CHECK_2 & Finish & was_err);
    end
// ------------------------------------------------------------------------------------


// ---------------------Enable and redundancy enable signals---------------------------
    always @(posedge clock) begin
        if (reset) begin
            Enable <= 0;
            red_en <= 0;
        end else begin
            case (state)
                IDLE:       Enable <= en;
                CHECK_1:    Enable <= 0;
                SEND_RED_1: red_en <= 1;
                
                SEND_RED_2: begin
                    red_en <= 0;
                    Enable <= 1;
                end

                WAIT, CHECK_2: Enable <= 0;
                FINISH:  Enable <= en;

                default: begin
                    red_en <= 'bx;
                    Enable <= 'bx;
                end
            endcase
        end
    end
// ------------------------------------------------------------------------------------
    
endmodule