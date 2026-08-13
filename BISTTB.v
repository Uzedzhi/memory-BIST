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
        #`CLOCK_TICK; clock = ~clock;
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

    wire ce, we;
    wire [`DATA_W:0] DefectColumn;
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
        .DefectColumnInner(DefectColumn),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out)
    );
// ---------------------------------------------------------------------------

    memory #(
        .DEPTH(`DEPTH),
        .WIDTH(`WIDTH),
        .DEFECT_TYPE(`_MEMORY_DEFECT_DRF_0)
    ) TB_memory (
        .clock(clock),

        .ce(ce),
        .we(we),

        .DefectColumn(DefectColumn),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out)
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