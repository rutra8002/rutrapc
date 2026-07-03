// ============================================================
// tmds_encoder.v
// Standard TMDS 8b/10b encoder (per the DVI 1.0 spec algorithm).
// Converts one 8-bit color channel + 2 control bits into a
// 10-bit, DC-balanced, transition-minimized symbol every pixel clock.
// ============================================================
module tmds_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] pixel_data,     // 8-bit color value for this channel (R, G, or B)
    input  wire [1:0] control_bits,   // control bits, only used during blanking
    input  wire       data_enable,    // 1 = active video, 0 = blanking period
    output reg  [9:0] tmds_out        // the 10-bit encoded symbol sent to the serializer
);

    // ---- Stage 1: transition-minimized encoding, 8 bits -> 9 bits ----
    // Counts how many bits in pixel_data are '1'
    wire [3:0] ones_count = pixel_data[0]+pixel_data[1]+pixel_data[2]+pixel_data[3]
                           +pixel_data[4]+pixel_data[5]+pixel_data[6]+pixel_data[7];

    // Decide whether XOR or XNOR chaining causes fewer bit transitions
    wire minimize_with_xnor = (ones_count > 4'd4) || ((ones_count == 4'd4) && (pixel_data[0] == 1'b0));

    // 9-bit intermediate result: 8 data bits (transformed) + 1 "which method was used" flag
    wire [8:0] stage1_bits;
    assign stage1_bits[0] = pixel_data[0];
    assign stage1_bits[1] = minimize_with_xnor ? ~(stage1_bits[0]^pixel_data[1]) : (stage1_bits[0]^pixel_data[1]);
    assign stage1_bits[2] = minimize_with_xnor ? ~(stage1_bits[1]^pixel_data[2]) : (stage1_bits[1]^pixel_data[2]);
    assign stage1_bits[3] = minimize_with_xnor ? ~(stage1_bits[2]^pixel_data[3]) : (stage1_bits[2]^pixel_data[3]);
    assign stage1_bits[4] = minimize_with_xnor ? ~(stage1_bits[3]^pixel_data[4]) : (stage1_bits[3]^pixel_data[4]);
    assign stage1_bits[5] = minimize_with_xnor ? ~(stage1_bits[4]^pixel_data[5]) : (stage1_bits[4]^pixel_data[5]);
    assign stage1_bits[6] = minimize_with_xnor ? ~(stage1_bits[5]^pixel_data[6]) : (stage1_bits[5]^pixel_data[6]);
    assign stage1_bits[7] = minimize_with_xnor ? ~(stage1_bits[6]^pixel_data[7]) : (stage1_bits[6]^pixel_data[7]);
    assign stage1_bits[8] = ~minimize_with_xnor;   // flag bit: 0 = XNOR was used, 1 = XOR was used

    // Count 1s/0s in the 8 transformed data bits (not counting the flag bit)
    wire [3:0] stage1_ones  = stage1_bits[0]+stage1_bits[1]+stage1_bits[2]+stage1_bits[3]
                              +stage1_bits[4]+stage1_bits[5]+stage1_bits[6]+stage1_bits[7];
    wire [3:0] stage1_zeros = 4'd8 - stage1_ones;
    wire signed [4:0] one_zero_balance = stage1_ones - stage1_zeros;

    // ---- Stage 2: DC balancing using running disparity, 9 bits -> 10 bits ----
    // running_disparity tracks the long-term 1s-vs-0s imbalance sent so far,
    // so we can keep nudging future symbols to cancel it back out
    reg signed [4:0] running_disparity = 0;

    // Fixed control-period symbols (from the DVI spec) — sent during blanking instead of color
    function [9:0] control_symbol(input [1:0] c);
        case (c)
            2'b00: control_symbol = 10'b1101010100;
            2'b01: control_symbol = 10'b0010101011;
            2'b10: control_symbol = 10'b0101010100;
            default: control_symbol = 10'b1010101011;
        endcase
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_disparity <= 0;
            tmds_out <= 10'b1101010100;
        end else if (!data_enable) begin
            tmds_out <= control_symbol(control_bits);
            running_disparity <= 0;
        end else begin
            if (running_disparity == 0 || stage1_ones == 4'd4) begin
                tmds_out[9]   <= ~stage1_bits[8];
                tmds_out[8]   <= stage1_bits[8];
                tmds_out[7:0] <= stage1_bits[8] ? stage1_bits[7:0] : ~stage1_bits[7:0];
                running_disparity <= stage1_bits[8] ? (running_disparity + one_zero_balance)
                                                     : (running_disparity - one_zero_balance);
            end else if ((running_disparity > 0 && stage1_ones > 4'd4) ||
                         (running_disparity < 0 && stage1_ones < 4'd4)) begin
                tmds_out[9]   <= 1'b1;
                tmds_out[8]   <= stage1_bits[8];
                tmds_out[7:0] <= ~stage1_bits[7:0];
                running_disparity <= running_disparity + {3'b0, stage1_bits[8], 1'b0} - one_zero_balance;
            end else begin
                tmds_out[9]   <= 1'b0;
                tmds_out[8]   <= stage1_bits[8];
                tmds_out[7:0] <= stage1_bits[7:0];
                running_disparity <= running_disparity - {3'b0, ~stage1_bits[8], 1'b0} + one_zero_balance;
            end
        end
    end

endmodule