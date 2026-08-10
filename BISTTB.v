`include "controller.v"

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
    reg  en;
    wire TestFinish;
    wire ErrOnFirstCheck;
    wire ErrOnSecondCheck;

    controller #(
        .DEPTH(`DEPTH),
        .WIDTH(`WIDTH),
        .DELAY_TICKS(`DELAY_TICKS)
    ) TB_controller (
        .clock(clock),
        .reset(reset),
        .en(en),
        .TestFinish(TestFinish),
        .ErrOnFirstCheck(ErrOnFirstCheck),
        .ErrOnSecondCheck(ErrOnSecondCheck)
    );
// ---------------------------------------------------------------------------

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