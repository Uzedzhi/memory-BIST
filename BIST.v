`ifndef _BIST_MAIN
`define _BIST_MAIN

`include "BIST_h.v"
`include "Memory.v"

module BIST #(
    parameter DELAY_TICKS = 4
)(
    input clock,
    input Enable,
    input reset,

    output AllCorrect,
    output Finish,
    output reg err
);
// -------------localparams for FSM state----------------
    localparam [3:0] IDLE        = 4'b0000; // state after reset, Enable -> INIT0
    localparam [3:0] INIT0       = 4'b0001;
    localparam [3:0] WRITE1      = 4'b0010;
    localparam [3:0] DELAY_1     = 4'b0011;
    localparam [3:0] READ1       = 4'b0100;
    localparam [3:0] WRITE0      = 4'b0101;
    localparam [3:0] DELAY_2     = 4'b0110;
    localparam [3:0] READ0       = 4'b0111;
    localparam [3:0] FINISH      = 4'b1000; // state after finishing testing, Enable -> INIT0
    localparam ADDR_W      = $clog2(`WIDTH);
// ------------------------------------------------------

    reg ce, we;
    reg  [`WIDTH - 1:0]                 data_in;
    wire [`WIDTH - 1:0]                 data_out;
    reg  [`WIDTH - 1:0]                 ExpValue;
    reg  [$clog2(`DEPTH)        - 1:0]  AddrCounter;
    reg  [$clog2(DELAY_TICKS)   - 1:0]  DelayCounter;
    reg  [$clog2(`NUM_MARCH)    - 1:0]  state;
    wire [$clog2(`NUM_MARCH)    - 1:0]  next_state;

// --------------RAM module instantiation----------------
    memory RAM (
        .clock(clock),
        .ce(ce),
        .we(we),
        .addr(AddrCounter),
        .data_in(data_in),
        .data_out(data_out)
    );
// ------------------------------------------------------


    assign Finish       = (state == FINISH);
    assign AllCorrect   = Finish & (err == 0);

    wire is_DELAY       = (state == DELAY_1 | state == DELAY_2);
    wire is_IDLE        = (state == IDLE    | state == FINISH);
    wire is_DelayC_done = (DelayCounter == DELAY_TICKS - 1);
    wire is_AddrC_done  = (AddrCounter  == `DEPTH      - 1);


// ---------------------------state------------------------------
    assign next_state = (is_IDLE  & Enable)                         ? INIT0     :
                        (is_IDLE  & ~Enable)                        ? state     :
                        (is_DELAY & is_DelayC_done | is_AddrC_done) ? state + 1 : state;
    
    always @(posedge clock)
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
// --------------------------------------------------------------

// ---------------------------ERR--------------------------------
    reg was_READ;
    wire is_READ = (state == READ1 | state == READ0);
    always @(posedge clock)
        was_READ <= is_READ;

    always @(posedge clock)
        if (reset)
            err <= 0;
        else
            err <= err | was_READ & (ExpValue != data_out);
// --------------------------------------------------------------

// -----------------------AddrCounter----------------------------
    always @(posedge clock)
        if (reset)
            AddrCounter <= 0;
        else
            AddrCounter <=  (is_IDLE    |
                             is_DELAY   |
                             is_AddrC_done) ? 0 : AddrCounter + 1;
// --------------------------------------------------------------

// ----------------------Delay Counter---------------------------
    always @(posedge clock)
        if (reset)
            DelayCounter <= 0;
        else
            DelayCounter <= (is_DELAY & ~is_DelayC_done) ? DelayCounter + 1  : 0;
// --------------------------------------------------------------

// ------------------What all those states do--------------------
    always @(posedge clock) begin
        case (next_state)
            FINISH, IDLE, DELAY_1, DELAY_2:   ce <= 0;
            INIT0, WRITE0:              begin ce <= 1;   we <= 1; data_in  <= {`WIDTH{1'b0}}; end
            WRITE1:                     begin ce <= 1;   we <= 1; data_in  <= {`WIDTH{1'b1}}; end
            READ1:                      begin ce <= 1;   we <= 0; ExpValue <= {`WIDTH{1'b1}}; end
            READ0:                      begin ce <= 1;   we <= 0; ExpValue <= {`WIDTH{1'b0}}; end
            default:                    begin ce <= 'bx; we <= 'bx; end
        endcase
    end
// --------------------------------------------------------------
endmodule



`endif