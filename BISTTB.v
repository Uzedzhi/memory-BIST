`include "controller.v"

// ----------------Тестбенч для однопортовой памяти------------------
module TB();
    localparam WIDTH = `WIDTH;
    localparam DEPTH = `DEPTH;
    reg reset;
// -----------clock initializing-----------
    reg clock;
    initial begin
        clock = 0;
    end
    always begin
        #10; clock = ~clock;
    end
// ----------------------------------------

// -------------waveform dump--------------
    initial begin
        $dumpfile("simulation.vcd");
        $dumpvars(0, TB);
    end
// ----------------------------------------

// -----------------------Testing module instantiation-----------------------
    reg  en;
    wire TestFinish;

    wire ce, we, red_en;
    wire [`DATA_W - 1:0] DefectColumn;
    wire [`ADDR_W - 1:0] addr;
    wire [WIDTH  - 1:0] data_in;
    wire [WIDTH  - 1:0] data_out;
    wire red_done;

    controller #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH),
        .DELAY_TICKS(`DELAY_TICKS)
    ) TB_controller (
        .clock(clock),
        .reset(reset),
        .en(en),
        .TestFinish(TestFinish),

        .ce(ce),
        .we(we),
        .red_en(red_en),
        .DefectColumn(DefectColumn),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .red_done(red_done)
    );
// ---------------------------------------------------------------------------

    memory #(
        .DEPTH(`DEPTH),
        .WIDTH(`WIDTH)
    ) TB_memory (
        .clock(clock),
        .reset(reset),

        .ce(ce),
        .we(we),
        .red_en(red_en),

        .DefectColumn(DefectColumn),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .red_done(red_done)
    );

// ----------------------------Main Testing-----------------------------------
    initial begin: running_tests
        en <= 0;
        
        reset  <= 0;
        repeat (2) @(posedge clock);        
        reset  <= 1;
        repeat (2) @(posedge clock);        
        reset  <= 0;

        en <= 1;
        @(posedge clock);
        en <= 0;

        #3000;     
        $finish;  
    end
endmodule