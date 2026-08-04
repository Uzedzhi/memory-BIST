`include "BIST.v"

// ----------------Тестбенч для однопортовой памяти------------------
module TB();
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
    reg  ce, we;
    reg  [$clog2(`DEPTH) - 1:0]  addr;
    reg  [`WIDTH - 1:0]          data_in;
    wire [`WIDTH - 1:0]          data_out;
    reg dump;
    wire Finish, AllCorrect, err;
    reg Enable;

    BIST #(
        .DELAY_TICKS(`DELAY_TICKS)
    ) TB_BIST (
        .clock(clock),
        .Enable(Enable),
        .reset(reset),

        .AllCorrect(AllCorrect),
        .err(err),
        .Finish(Finish)
    );
// ---------------------------------------------------------------------------

// ----------------------------Main Testing-----------------------------------
    initial begin: running_tests
        Enable <= 0;
        
        reset  <= 0;
        repeat (2) @(posedge clock);        
        reset  <= 1;
        repeat (2) @(posedge clock);        
        reset  <= 0;

        Enable <= 1;
        @(posedge clock);
        Enable <= 0;

        #1000;     
        $finish;  
    end
endmodule