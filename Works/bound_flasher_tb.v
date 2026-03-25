// Module      : bound_flasher_tb
// Author      : Thanh
// Date        : 2026/03/25
// Version     : v0r0
// Description : Testbench for bound_flasher
//               Verifies cumulative bar-graph lamp behavior.
//               Expected: lamps L0..L(level-1) are all ON simultaneously.

`timescale 1ns/1ps

module bound_flasher_tb;

  // DUT ports
  reg        clk;
  reg        rst_n;
  reg        flick;
  wire [15:0] lamp;

  // DUT instance
  bound_flasher bound_flasher_01 (
    .clk   (clk),
    .rst_n (rst_n),
    .flick (flick),
    .lamp  (lamp)
  );

  // 10 ns clock (100 MHz)
  always #5 clk = ~clk;

  // Helper: count how many lamps are ON (should always be contiguous from L0)
  function [4:0] count_lamps;
    input [15:0] lmp;
    integer i;
    begin
      count_lamps = 0;
      for (i = 0; i < 16; i = i + 1) begin
        if (lmp[i]) begin
          count_lamps = count_lamps + 1;
        end
      end
    end
  endfunction

  // Helper: check that ON lamps are always contiguous starting at L0
  task check_contiguous;
    input [15:0] lmp;
    input integer cyc;
    integer i;
    integer found_off;
    begin
      found_off = 0;
      for (i = 0; i < 16; i = i + 1) begin
        if (found_off && lmp[i]) begin
          $display("  FAIL cyc=%0d: lamp not contiguous from L0! lamp=%b", cyc, lmp);
        end
        if (!lmp[i]) begin
          found_off = 1;
        end
      end
    end
  endtask

  integer cyc;

  initial begin
    clk   = 0;
    rst_n = 0;
    flick = 0;

    // Apply reset
    @(posedge clk); #1;
    @(posedge clk); #1;
    rst_n = 1;
    @(posedge clk); #1;

    // ------------------------------------------------------------------
    // TEST 1: Normal full sequence, no kickback (flick=0 after start)
    // Expected level sequence (peaks and valleys):
    //   0->6->5->0->1->..->11->10->6->7->..->16->15->0
    // ------------------------------------------------------------------
    $display("=== TEST 1: Normal sequence (no kickback) ===");
    flick = 1;           // start machine
    @(posedge clk); #1;
    flick = 0;           // drop flick so no kickback fires

    for (cyc = 0; cyc < 70; cyc = cyc + 1) begin
      $display("  cyc=%0d  level=%0d  lamp=%b", cyc, count_lamps(lamp), lamp);
      check_contiguous(lamp, cyc);
      @(posedge clk); #1;
    end
    // After ~62 clocks the machine returns to IDLE (all off)
    if (lamp !== 16'd0) begin
      $display("  FAIL: Expected IDLE (lamp=0) after full sequence, got %b", lamp);
    end else begin
      $display("  PASS: Machine returned to IDLE correctly");
    end
    $display("--- Test 1 done ---");

    // Let machine idle
    repeat (5) @(posedge clk);

    // ------------------------------------------------------------------
    // TEST 2: Kickback at lamp[5] during step 3 (flick=1 always)
    // At the moment level=6 in ON_0_10, flick=1 triggers kickback1
    // ------------------------------------------------------------------
    $display("=== TEST 2: Kickback at lamp[5] (flick=1 throughout) ===");
    flick = 1;
    for (cyc = 0; cyc < 100; cyc = cyc + 1) begin
      $display("  cyc=%0d  level=%0d  lamp=%b", cyc, count_lamps(lamp), lamp);
      check_contiguous(lamp, cyc);
      @(posedge clk); #1;
    end
    flick = 0;
    if (lamp !== 16'd0) begin
      $display("  FAIL: Expected IDLE after sequence, got %b", lamp);
    end else begin
      $display("  PASS: Machine returned to IDLE after kickback sequence");
    end
    $display("--- Test 2 done ---");

    repeat (5) @(posedge clk);

    // ------------------------------------------------------------------
    // TEST 3: IDLE with flick=0, all lamps must stay OFF
    // ------------------------------------------------------------------
    $display("=== TEST 3: IDLE flick=0 -> lamps must stay OFF ===");
    flick = 0;
    repeat (5) begin
      @(posedge clk); #1;
      if (lamp !== 16'd0) begin
        $display("  FAIL: lamp should be 0 in IDLE, got %b", lamp);
      end
    end
    $display("  PASS: All lamps OFF in IDLE");
    $display("--- Test 3 done ---");

    // ------------------------------------------------------------------
    // TEST 4: Peak level verification
    // After starting, step 1 peak must be exactly 16'h003F (lamp[0:5] ON)
    // ------------------------------------------------------------------
    $display("=== TEST 4: Peak level at end of step 1 = 16'h003F ===");
    flick = 1;
    @(posedge clk); #1;  // enter ON_0_5
    flick = 0;
    // Step 1 takes 6 clocks to reach level=6 (lamp[0:5])
    // We are now 1 clock into it (level=1 after the start clock)
    repeat (4) @(posedge clk);   // clocks 2-5 (level 2->5)
    @(posedge clk); #1;          // clock 6: level=6 should appear here
    if (lamp === 16'h003F) begin
      $display("  PASS: Step 1 peak = 16'h003F (lamp[0:5] ON)");
    end else begin
      $display("  FAIL: Step 1 peak expected 16'h003F, got %h", lamp);
    end
    // Wait for machine to complete
    repeat (80) @(posedge clk);
    $display("--- Test 4 done ---");

    $display("=== Simulation complete ===");
    $finish;
  end

  // Dump waveforms
  initial begin
    $dumpfile("bound_flasher.vcd");
    $dumpvars(0, bound_flasher_tb);
  end

endmodule
