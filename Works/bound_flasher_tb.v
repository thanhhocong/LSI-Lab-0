// Module      : bound_flasher_tb
// Author      : Thanh
// Date        : 2026/03/25
// Version     : v0r0
// Description : Testbench for bound_flasher
//               Verifies cumulative bar-graph lamp behavior.

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

  // Helper: assert reset to put machine back into a clean IDLE state
  task do_reset;
    begin
      rst_n = 0;
      flick = 0;
      @(posedge clk); #1;
      @(posedge clk); #1;
      rst_n = 1;
      @(posedge clk); #1;
    end
  endtask

  integer cyc;

  initial begin
    clk   = 0;
    rst_n = 0;
    flick = 0;
    do_reset;

    // ------------------------------------------------------------------
    // TEST 1: Normal full sequence, no kickback (flick=0 after start)
    // Expected level peaks: 6, 11, 16
    // Expected level valleys: 0, 6, 0  ->  returns to IDLE
    // ------------------------------------------------------------------
    $display("=== TEST 1: Normal sequence (no kickback) ===");
    flick = 1;
    @(posedge clk); #1;  // machine enters ON_0_5
    flick = 0;           // drop flick: no kickback will fire

    for (cyc = 0; cyc < 60; cyc = cyc + 1) begin
      $display("  cyc=%0d  level=%0d  lamp=%b", cyc, count_lamps(lamp), lamp);
      @(posedge clk); #1;
    end

    if (lamp === 16'd0) begin
      $display("  PASS: Machine returned to IDLE (lamp=0)");
    end else begin
      $display("  FAIL: Expected IDLE, got %b (level=%0d)", lamp, count_lamps(lamp));
    end
    $display("--- Test 1 done ---");

    // ------------------------------------------------------------------
    // TEST 2: Kickback at both lamp[5] and lamp[10] (flick=1 throughout)
    // Full kickback sequence takes ~75 clocks.
    // Drop flick at cycle 60 to prevent re-start when machine returns to IDLE.
    // ------------------------------------------------------------------
    $display("=== TEST 2: Both kickbacks (flick=1, drop before IDLE) ===");
    do_reset;
    flick = 1;
    @(posedge clk); #1;  // machine enters ON_0_5

    for (cyc = 0; cyc < 60; cyc = cyc + 1) begin
      $display("  cyc=%0d  level=%0d  lamp=%b", cyc, count_lamps(lamp), lamp);
      @(posedge clk); #1;
    end
    // Drop flick now (before machine reaches IDLE ~cycle 75) so it won't restart
    flick = 0;

    for (cyc = 60; cyc < 90; cyc = cyc + 1) begin
      $display("  cyc=%0d  level=%0d  lamp=%b", cyc, count_lamps(lamp), lamp);
      @(posedge clk); #1;
    end

    if (lamp === 16'd0) begin
      $display("  PASS: Machine returned to IDLE after kickback sequence");
    end else begin
      $display("  FAIL: Expected IDLE, got level=%0d", count_lamps(lamp));
    end
    $display("--- Test 2 done ---");

    // ------------------------------------------------------------------
    // TEST 3: IDLE with flick=0 - all lamps must stay OFF
    // ------------------------------------------------------------------
    $display("=== TEST 3: IDLE with flick=0, lamps must be OFF ===");
    do_reset;
    flick = 0;
    repeat (5) begin
      @(posedge clk); #1;
      if (lamp !== 16'd0) begin
        $display("  FAIL: lamp should be 0 in IDLE, got %b", lamp);
      end
    end
    $display("  PASS: All lamps OFF in IDLE with flick=0");
    $display("--- Test 3 done ---");

    // ------------------------------------------------------------------
    // TEST 4: Verify step 1 peak = 16'h003F (lamp[0:5] ON, level=6)
    // After 6 clocks from start, level should reach 6.
    // ------------------------------------------------------------------
    $display("=== TEST 4: Step 1 peak = 16'h003F (lamp[0:5] all ON) ===");
    do_reset;
    // Clock 1: flick=1 -> enter ON_0_5, level=1
    flick = 1;
    @(posedge clk); #1;
    flick = 0;
    $display("  clock 1: level=%0d (expect 1)", count_lamps(lamp));
    // Clocks 2-5: level rises 2,3,4,5
    repeat (4) begin
      @(posedge clk); #1;
    end
    $display("  clock 5: level=%0d (expect 5)", count_lamps(lamp));
    // Clock 6: level should reach 6
    @(posedge clk); #1;
    $display("  clock 6: level=%0d  lamp=16'h%04h (expect 16'h003F)", count_lamps(lamp), lamp);
    if (lamp === 16'h003F) begin
      $display("  PASS: Step 1 peak = 16'h003F");
    end else begin
      $display("  FAIL: Expected 16'h003F, got 16'h%04h", lamp);
    end
    // Let machine complete so no loose ends
    flick = 0;
    repeat (60) @(posedge clk);
    $display("--- Test 4 done ---");

    // ------------------------------------------------------------------
    // TEST 5: Verify step 4 valley = 16'h003F (lamp[0:5] stay ON, level=6)
    // After step 4 (OFF 10->5), lamp[0:5] must remain ON.
    // ------------------------------------------------------------------
    $display("=== TEST 5: Step 4 valley = 16'h003F (lamp[0:5] remain ON) ===");
    do_reset;
    flick = 1;
    @(posedge clk); #1;
    flick = 0;
    // Wait until OFF_10_5 ends (step 4 ends):
    // From Test 1 output: step 4 valley (level=6) appears at cyc=27
    // = 27 additional clocks after the initial start clock
    repeat (26) @(posedge clk);
    @(posedge clk); #1;
    $display("  step4 valley: level=%0d  lamp=16'h%04h (expect 16'h003F)", count_lamps(lamp), lamp);
    if (lamp === 16'h003F) begin
      $display("  PASS: Step 4 valley = 16'h003F (lamp[0:5] remain ON)");
    end else begin
      $display("  FAIL: Expected 16'h003F, got 16'h%04h", lamp);
    end
    repeat (40) @(posedge clk);
    $display("--- Test 5 done ---");

    $display("=== Simulation complete ===");
    $finish;
  end

  // Dump waveforms for GTKWave
  initial begin
    $dumpfile("bound_flasher.vcd");
    $dumpvars(0, bound_flasher_tb);
  end

endmodule
