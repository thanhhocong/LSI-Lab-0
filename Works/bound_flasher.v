// Module      : bound_flasher
// Author      : Thanh
// Date        : 2026/03/25
// Version     : v0r0
// Description : RTL Exercise 1 - Bound Flasher with 16 lamps (cumulative bar display)
//               All lamps from lamp[0] up to the current level are ON simultaneously.
//               "ON gradually from A to B" = level rises, adding one lamp per clock.
//               "OFF gradually from A to B" = level falls, removing one lamp per clock.

module bound_flasher (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        flick,
  output reg  [15:0] lamp
);

  // State encoding parameters
  parameter IDLE     = 4'd0;   // All lamps OFF, wait for flick=1
  parameter ON_0_5   = 4'd1;   // ON: level 1->6  (lamp[0] to lamp[5], first state, no kickback)
  parameter OFF_5_0  = 4'd2;   // OFF: level 5->0 (lamp[5] down to all OFF)
  parameter ON_0_10  = 4'd3;   // ON: level 1->11 (lamp[0] to lamp[10], kickback check at level=6)
  parameter KB1_OFF  = 4'd4;   // Kickback1 OFF: level 5->0 (lamp[5] back to all OFF)
  parameter KB1_ON   = 4'd5;   // Kickback1 resume ON: level 1->11 (lamp[0] to lamp[10])
  parameter OFF_10_5 = 4'd6;   // OFF: level 10->6 (lamp[10] down to lamp[5] remaining)
  parameter ON_5_15  = 4'd7;   // ON: level 7->16 (lamp[6] to lamp[15], kickback check at level=11)
  parameter KB2_OFF  = 4'd8;   // Kickback2 OFF: level 10->6 (lamp[10] back to lamp[5] remaining)
  parameter KB2_ON   = 4'd9;   // Kickback2 resume ON: level 7->16 (lamp[6] to lamp[15])
  parameter OFF_15_0 = 4'd10;  // OFF: level 15->0 (lamp[15] down to all OFF, return to IDLE)

  // Level constants
  // level = number of lamps currently ON (lamp[0] through lamp[level-1] are ON)
  parameter LVL_0    = 5'd0;   // all lamps OFF
  parameter LVL_5    = 5'd6;   // lamp[0] to lamp[5] ON  (6 lamps)
  parameter LVL_10   = 5'd11;  // lamp[0] to lamp[10] ON (11 lamps)
  parameter LVL_15   = 5'd16;  // lamp[0] to lamp[15] ON (16 lamps = all ON)

  // FF registers (state and lamp level)
  reg [3:0] state;
  reg [4:0] level;

  // Non-FF registers (combinational next values)
  reg [3:0] next_state;
  reg [4:0] next_level;

  // Sequential: update state and level on clock edge
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      level <= LVL_0;
    end else begin
      state <= next_state;
      level <= next_level;
    end
  end

  // Combinational: next-state and next-level logic
  always @(state or level or flick) begin
    next_state = state;
    next_level = level;

    case (state)
      IDLE: begin
        next_level = LVL_0;
        if (flick) begin
          next_state = ON_0_5;
          next_level = 5'd1;   // lamp[0] turns ON immediately
        end
      end

      // Step 1: ON lamp[0] to lamp[5], no kickback (first state)
      // level rises from 1 to 6; at level=6 (lamp[5] reached), transition to OFF
      ON_0_5: begin
        if (level == LVL_5) begin
          next_state = OFF_5_0;
          next_level = LVL_5 - 5'd1;  // lamp[5] starts turning OFF
        end else begin
          next_level = level + 5'd1;
        end
      end

      // Step 2: OFF lamp[5] to lamp[0], then all OFF
      // level falls from 5 to 0; at level=0 (all OFF), transition to ON
      OFF_5_0: begin
        if (level == LVL_0) begin
          next_state = ON_0_10;
          next_level = 5'd1;   // lamp[0] turns ON immediately
        end else begin
          next_level = level - 5'd1;
        end
      end

      // Step 3: ON lamp[0] to lamp[10], kickback check when lamp[5] is the top (level=6)
      ON_0_10: begin
        if (level == LVL_10) begin
          next_state = OFF_10_5;
          next_level = LVL_10 - 5'd1; // lamp[10] starts turning OFF
        end else if ((level == LVL_5) && flick) begin
          next_state = KB1_OFF;
          next_level = LVL_5 - 5'd1;  // kickback: lamp[5] starts turning OFF
        end else begin
          next_level = level + 5'd1;
        end
      end

      // Kickback1: OFF from lamp[5] all the way to lamp[0] (all OFF)
      KB1_OFF: begin
        if (level == LVL_0) begin
          next_state = KB1_ON;
          next_level = 5'd1;
        end else begin
          next_level = level - 5'd1;
        end
      end

      // Kickback1 resume: ON lamp[0] to lamp[10], no second kickback
      KB1_ON: begin
        if (level == LVL_10) begin
          next_state = OFF_10_5;
          next_level = LVL_10 - 5'd1;
        end else begin
          next_level = level + 5'd1;
        end
      end

      // Step 4: OFF lamp[10] down to lamp[5] (lamp[0] to lamp[5] remain ON)
      OFF_10_5: begin
        if (level == LVL_5) begin
          next_state = ON_5_15;
          next_level = LVL_5 + 5'd1;  // lamp[6] starts turning ON
        end else begin
          next_level = level - 5'd1;
        end
      end

      // Step 5: ON lamp[6] to lamp[15], kickback check when lamp[10] is the top (level=11)
      ON_5_15: begin
        if (level == LVL_15) begin
          next_state = OFF_15_0;
          next_level = LVL_15 - 5'd1; // lamp[15] starts turning OFF
        end else if ((level == LVL_10) && flick) begin
          next_state = KB2_OFF;
          next_level = LVL_10 - 5'd1; // kickback: lamp[10] starts turning OFF
        end else begin
          next_level = level + 5'd1;
        end
      end

      // Kickback2: OFF from lamp[10] down to lamp[5] (lamp[0] to lamp[5] remain ON)
      KB2_OFF: begin
        if (level == LVL_5) begin
          next_state = KB2_ON;
          next_level = LVL_5 + 5'd1;  // lamp[6] starts turning ON again
        end else begin
          next_level = level - 5'd1;
        end
      end

      // Kickback2 resume: ON lamp[6] to lamp[15], no second kickback
      KB2_ON: begin
        if (level == LVL_15) begin
          next_state = OFF_15_0;
          next_level = LVL_15 - 5'd1;
        end else begin
          next_level = level + 5'd1;
        end
      end

      // Step 6: OFF lamp[15] down to lamp[0], then all OFF, return to IDLE
      OFF_15_0: begin
        if (level == LVL_0) begin
          next_state = IDLE;
          next_level = LVL_0;
        end else begin
          next_level = level - 5'd1;
        end
      end

      // Non-reachable states: safe return to IDLE
      default: begin
        next_state = IDLE;
        next_level = LVL_0;
      end
    endcase
  end

  // Combinational: output logic (Moore)
  // lamp[i] = 1 if i < level, else 0  -->  lamp = (1 << level) - 1
  // Special case: level=16 uses 16'hFFFF (all ON) to avoid 16-bit overflow
  always @(state or level) begin
    if (state == IDLE) begin
      lamp = 16'd0;
    end else begin
      // (16'd1 << level) - 16'd1 works for level 0-16:
      // level=0  -> 0          level=6  -> 16'h003F  level=11 -> 16'h07FF
      // level=16 -> 16'hFFFF   (1<<16 overflows 16-bit to 0, 0-1 wraps to 16'hFFFF)
      lamp = (16'd1 << level) - 16'd1;
    end
  end

endmodule
