// Streaming 3x3 Sobel edge detector.
//
// Input:  one RGB pixel per clock (24-bit RGB,row-major) while valid_in is high.
// Output: gradient magnitude |gx| + |gy|, clamped to 255.
//
// Timing: the result for the window centred on input pixel n appears with
// valid_out high on the clock edge n + image_width + 2, where the edge that
// accepts input pixel 0 is edge 0. The one-pixel border has no full window,
// so no output is produced for it.
module sobel #(
    parameter int WIDTH = 4096   // maximum image width (line buffer depth)
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] image_width,   // actual image width
    input  logic        valid_in,
    input  logic [23:0]  pixel_in,
    output logic        valid_out,
    output logic [7:0]  pixel_out      //As output pixel is clamped to 8 bits 
);

    
    //for whole RGB image
    localparam int COL_W = $clog2(WIDTH);

    //Splitting RGB image to R , G , B pixels
    logic [7:0] R,G,B;
    assign R = pixel_in[23:16];
    assign G = pixel_in[15:8];
    assign B = pixel_in[7:0];

    // position of the pixel currently being accepted (This is for whole RGB image)
    logic [COL_W-1:0] col;
    logic [15:0]      row;

    // line buffers: line_buffer1 holds the previous row, line_buffer2 the one before

    //Made separate line buffers for R , G , B
    // for R
    logic [7:0] R_line_buffer1 [WIDTH];
    logic [7:0] R_line_buffer2 [WIDTH];

    // for G
    logic [7:0] G_line_buffer1 [WIDTH];
    logic [7:0] G_line_buffer2 [WIDTH];

    // for B
    logic [7:0] B_line_buffer1 [WIDTH];
    logic [7:0] B_line_buffer2 [WIDTH];   

    // 3x3 window shift registers (r0 = newest row, r2 = oldest row)
   
    //Made separate shift registers for R , G , B   
    //for R    
    logic [7:0] R_r0_0, R_r0_1, R_r0_2;
    logic [7:0] R_r1_0, R_r1_1, R_r1_2;
    logic [7:0] R_r2_0, R_r2_1, R_r2_2;

    //for G
    logic [7:0] G_r0_0, G_r0_1, G_r0_2;
    logic [7:0] G_r1_0, G_r1_1, G_r1_2;
    logic [7:0] G_r2_0, G_r2_1, G_r2_2;

    //for B
    logic [7:0] B_r0_0, B_r0_1, B_r0_2;
    logic [7:0] B_r1_0, B_r1_1, B_r1_2;
    logic [7:0] B_r2_0, B_r2_1, B_r2_2;   

    // high when the window registers hold a complete 3x3 window  
    logic win_valid;      
    // sobel combinational maths

    // Made separately for R , G , B.    

    //for R     
    logic signed [11:0] R_gx_wire;
    logic signed [11:0] R_gy_wire;
    logic signed [11:0] R_abs_gx_wire;
    logic signed [11:0] R_abs_gy_wire;
    logic        [11:0] R_grad_wire;

    //for G    
    logic signed [11:0] G_gx_wire;
    logic signed [11:0] G_gy_wire;
    logic signed [11:0] G_abs_gx_wire;
    logic signed [11:0] G_abs_gy_wire;
    logic        [11:0] G_grad_wire;

    //for B
    logic signed [11:0] B_gx_wire;
    logic signed [11:0] B_gy_wire;
    logic signed [11:0] B_abs_gx_wire;
    logic signed [11:0] B_abs_gy_wire;
    logic        [11:0] B_grad_wire;

    //for R    
    assign R_gx_wire =
        -$signed({4'b0000, R_r2_2}) + $signed({4'b0000, R_r2_0})
        - ($signed({4'b0000, R_r1_2}) <<< 1) + ($signed({4'b0000, R_r1_0}) <<< 1)
        - $signed({4'b0000, R_r0_2}) + $signed({4'b0000, R_r0_0});

    assign R_gy_wire =
        $signed({4'b0000, R_r2_2}) + ($signed({4'b0000, R_r2_1}) <<< 1)
        + $signed({4'b0000, R_r2_0}) - $signed({4'b0000, R_r0_2})
        - ($signed({4'b0000, R_r0_1}) <<< 1) - $signed({4'b0000, R_r0_0});

    assign R_abs_gx_wire = (R_gx_wire < 0) ? -R_gx_wire : R_gx_wire;
    assign R_abs_gy_wire = (R_gy_wire < 0) ? -R_gy_wire : R_gy_wire;

    assign R_grad_wire = R_abs_gx_wire + R_abs_gy_wire;

    //for G    
    assign G_gx_wire =
        -$signed({4'b0000, G_r2_2}) + $signed({4'b0000, G_r2_0})
        - ($signed({4'b0000, G_r1_2}) <<< 1) + ($signed({4'b0000, G_r1_0}) <<< 1)
        - $signed({4'b0000, G_r0_2}) + $signed({4'b0000, G_r0_0});

    assign G_gy_wire =
        $signed({4'b0000, G_r2_2}) + ($signed({4'b0000, G_r2_1}) <<< 1)
        + $signed({4'b0000, G_r2_0}) - $signed({4'b0000, G_r0_2})
        - ($signed({4'b0000, G_r0_1}) <<< 1) - $signed({4'b0000, G_r0_0});

    assign G_abs_gx_wire = (G_gx_wire < 0) ? -G_gx_wire : G_gx_wire;
    assign G_abs_gy_wire = (G_gy_wire < 0) ? -G_gy_wire : G_gy_wire;

    assign G_grad_wire = G_abs_gx_wire + G_abs_gy_wire;        

    //for B   
    assign B_gx_wire =
        -$signed({4'b0000, B_r2_2}) + $signed({4'b0000, B_r2_0})
        - ($signed({4'b0000, B_r1_2}) <<< 1) + ($signed({4'b0000, B_r1_0}) <<< 1)
        - $signed({4'b0000, B_r0_2}) + $signed({4'b0000, B_r0_0});

    assign B_gy_wire =
        $signed({4'b0000, B_r2_2}) + ($signed({4'b0000, B_r2_1}) <<< 1)
        + $signed({4'b0000, B_r2_0}) - $signed({4'b0000, B_r0_2})
        - ($signed({4'b0000, B_r0_1}) <<< 1) - $signed({4'b0000, B_r0_0});

    assign B_abs_gx_wire = (B_gx_wire < 0) ? -B_gx_wire : B_gx_wire;
    assign B_abs_gy_wire = (B_gy_wire < 0) ? -B_gy_wire : B_gy_wire;

    assign B_grad_wire = B_abs_gx_wire + B_abs_gy_wire;    

    // Take the maximum of grad_wire of R,G,B and also this maximum should be of 12 bits.We get 8 bits after clamping.
    logic [11:0] x; 
    logic [11:0] max_grad_wire;
    logic [7:0]  out_grad_wire;
    
    assign x = (R_grad_wire > G_grad_wire) ? R_grad_wire : G_grad_wire;
    assign max_grad_wire = (x > B_grad_wire) ? x : B_grad_wire;
    assign out_grad_wire =  (max_grad_wire > 12'd255) ? 8'd255 : max_grad_wire[7:0];
           
    always_ff @(posedge clk) begin
        if (rst) begin
            col       <= '0;
            row       <= '0;
            win_valid <= 1'b0;
            valid_out <= 1'b0;
            pixel_out <= '0;

            //for R
            R_r0_0 <= '0; R_r0_1 <= '0; R_r0_2 <= '0;
            R_r1_0 <= '0; R_r1_1 <= '0; R_r1_2 <= '0;
            R_r2_0 <= '0; R_r2_1 <= '0; R_r2_2 <= '0;

            //for G
            G_r0_0 <= '0; G_r0_1 <= '0; G_r0_2 <= '0;
            G_r1_0 <= '0; G_r1_1 <= '0; G_r1_2 <= '0;
            G_r2_0 <= '0; G_r2_1 <= '0; G_r2_2 <= '0;

            //for B
            B_r0_0 <= '0; B_r0_1 <= '0; B_r0_2 <= '0;
            B_r1_0 <= '0; B_r1_1 <= '0; B_r1_2 <= '0;
            B_r2_0 <= '0; B_r2_1 <= '0; B_r2_2 <= '0;

        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                // line buffers: read the old value at this column, then overwrite it.
                // Reading and shifting in the same cycle keeps all three rows
                // in the same column.

                //for R
                R_line_buffer1[col] <= R;
                R_line_buffer2[col] <= R_line_buffer1[col];

                //for G
                G_line_buffer1[col] <= G;
                G_line_buffer2[col] <= G_line_buffer1[col];

                //for B
                B_line_buffer1[col] <= B;
                B_line_buffer2[col] <= B_line_buffer1[col];
                
                // shift sliding window

                //for R
                R_r0_2 <= R_r0_1;
                R_r0_1 <= R_r0_0;
                R_r0_0 <= R;

                R_r1_2 <= R_r1_1;
                R_r1_1 <= R_r1_0;
                R_r1_0 <= R_line_buffer1[col];

                R_r2_2 <= R_r2_1;
                R_r2_1 <= R_r2_0;
                R_r2_0 <= R_line_buffer2[col];

                //for G
                G_r0_2 <= G_r0_1;
                G_r0_1 <= G_r0_0;
                G_r0_0 <= G;

                G_r1_2 <= G_r1_1;
                G_r1_1 <= G_r1_0;
                G_r1_0 <= G_line_buffer1[col];

                G_r2_2 <= G_r2_1;
                G_r2_1 <= G_r2_0;
                G_r2_0 <= G_line_buffer2[col];

                //for B
                B_r0_2 <= B_r0_1;
                B_r0_1 <= B_r0_0;
                B_r0_0 <= B;

                B_r1_2 <= B_r1_1;
                B_r1_1 <= B_r1_0;
                B_r1_0 <= B_line_buffer1[col];

                B_r2_2 <= B_r2_1;
                B_r2_1 <= B_r2_0;
                B_r2_0 <= B_line_buffer2[col];

                // The window being loaded this cycle is complete once two full
                // rows and two columns have gone in. Flag it alongside the window.
                win_valid <= (row >= 2) && (col >= 2);

                // Output stage: the window registers (and win_valid) hold the
                valid_out <= win_valid;
                // window loaded on the previous valid cycle.
               //RGB after combining. It is already clamped to 8 bits above.
                if (win_valid) begin
                    pixel_out <= out_grad_wire;
                end

                // update counters
                if (col == image_width - 16'd1) begin
                    col <= '0;
                    row <= row + 1'b1;
                end else begin
                    col <= col + 1'b1;
                end
                
            end
        end
    end
endmodule
