`timescale 1ns/1ps
module tb_apb_timer;
    reg PCLK=0, PRESETn=0, PSEL=0, PENABLE=0, PWRITE=0;
    reg [7:0] PADDR=0;
    reg [31:0] PWDATA=0;
    wire [31:0] PRDATA;
    wire PREADY, PSLVERR, irq, tick;
    integer ticks=0, checks=0;
    reg [31:0] rd;
    always #5 PCLK=~PCLK;
    apb_timer dut(.*);
    always @(negedge PCLK) if (PRESETn && tick) ticks = ticks + 1;
    task automatic write_reg(input [7:0] address, input [31:0] data);
      begin
        @(negedge PCLK); PSEL=1; PENABLE=0; PWRITE=1; PADDR=address; PWDATA=data;
        @(negedge PCLK); PENABLE=1;
        #1; if (!PREADY || PSLVERR) $fatal(1,"Write bus error @%h",address);
        @(negedge PCLK); PSEL=0; PENABLE=0; PWRITE=0;
      end
    endtask
    task automatic read_reg(input [7:0] address, output [31:0] data);
      begin
        @(negedge PCLK); PSEL=1; PENABLE=0; PWRITE=0; PADDR=address;
        @(negedge PCLK); PENABLE=1;
        #1; if (!PREADY || PSLVERR) $fatal(1,"Read bus error @%h",address);
        data=PRDATA;
        @(negedge PCLK); PSEL=0; PENABLE=0;
      end
    endtask
    task automatic expect_eq(input [31:0] actual, input [31:0] expected, input [255:0] tag);
      begin
        checks=checks+1;
        if (actual !== expected) $fatal(1,"%0s expected=%h actual=%h",tag,expected,actual);
      end
    endtask
    initial begin
       $dumpfile("apb_timer.vcd"); $dumpvars(0,tb_apb_timer);
       repeat(3) @(negedge PCLK); PRESETn=1;
       write_reg(8'h04,3); write_reg(8'h08,4); write_reg(8'h10,1);
       read_reg(8'h04,rd); expect_eq(rd,3,"PSC readback");
       read_reg(8'h08,rd); expect_eq(rd,4,"ARR readback");
       write_reg(8'h00,3); // periodic, 20-cycle interval
       repeat(65) @(negedge PCLK);
       if(ticks < 3) $fatal(1,"Insufficient ticks: %0d",ticks);
       read_reg(8'h14,rd); expect_eq(rd,1,"Pending IRQ");
       if(!irq) $fatal(1,"IRQ not asserted");
       write_reg(8'h00,4); // stop
       write_reg(8'h14,1); // clear pending
       read_reg(8'h14,rd); expect_eq(rd,0,"IRQ cleared");
       write_reg(8'h04,1); write_reg(8'h08,3);
       write_reg(8'h00,1); // one-shot, 8 clocks
       repeat(12) @(negedge PCLK);
       read_reg(8'h00,rd);
       if(!rd[4] || rd[3]) $fatal(1,"One-shot state incorrect");
       checks=checks+1;
       $display("PASS: %0d checks; %0d total ticks",checks,ticks);
       $finish;
    end
    initial begin #100000; $fatal(1,"Simulation timeout"); end
endmodule
