// Self-checking RGB testbench for sobel.sv.
//
// Regression mode (default):
//   Generates RGB test patterns at several sizes, streams each through
//   the DUT, and compares every output pixel with a software RGB Sobel
//   reference model.
//
// RGB processing:
//
//   R -> Sobel -> ER
//   G -> Sobel -> EG
//   B -> Sobel -> EB
//
//   expected = max(ER, EG, EB)
//   expected = clamp(expected, 255)
//
// Also runs a noise image with random stalls on valid_in.
//
// File mode:
//   ./Vsobel_tb +in=image.ppm +out=result.pgm
//
// Input file:
//   ASCII RGB PPM (P3)
//
// Output file:
//   ASCII grayscale PGM (P2)


module sobel_tb;

    
    // DUT and clock
    

    logic        clk = 1'b0;
    logic        rst;

    logic [15:0] image_width;

    logic        valid_in;

    // RGB input:
    // [23:16] = R
    // [15:8]  = G
    // [7:0]   = B
    logic [23:0] pixel_in;

    logic        valid_out;
    logic [7:0]  pixel_out;

    sobel dut (.*);

    always #5 clk = ~clk;



    // Image storage
    
    int W, H;

    // One 24-bit RGB pixel per location.
    logic [23:0] img [];

    // DUT output, placed at the centre pixel.
    logic [7:0] got [];

    // Which output pixels were produced.
    bit seen [];


    // Statistics
   

    int n_valid;
    int n_bad_index;
    int n_idle_violations;


    
    // RGB test patterns
    //
    // Each channel gets a different pattern so that the testbench
    // actually exercises independent R/G/B processing.
   

    localparam int N_KINDS = 5;


    function automatic string pattern_name(input int kind);

        case (kind)

            0: return "vertical_rgb";
            1: return "horizontal_rgb";
            2: return "checker_rgb";
            3: return "diagonal_rgb";
            default: return "noise_rgb";

        endcase

    endfunction


    
    // Generate one channel of a test pattern.
   
    function automatic logic [7:0] pattern_value(
        input int kind,
        input int x,
        input int y,
        input int w,
        input int h,
        input int channel
    );

        case (kind)

            // Pattern 0
            //
            // R = vertical
            // G = horizontal
            // B = diagonal
     

            0: begin

                case (channel)

                    0:
                        return (x >= w / 2)
                             ? 8'd255
                             : 8'd0;

                    1:
                        return (y >= h / 2)
                             ? 8'd255
                             : 8'd0;

                    default:
                        return (x == y)
                             ? 8'd255
                             : 8'd0;

                endcase

            end


           
            // Pattern 1
            //
            // R = horizontal
            // G = checker
            // B = vertical
            

            1: begin

                case (channel)

                    0:
                        return (y >= h / 2)
                             ? 8'd255
                             : 8'd0;

                    1:
                        return ((((x / 8) + (y / 8)) % 2) == 0)
                             ? 8'd0
                             : 8'd255;

                    default:
                        return (x >= w / 2)
                             ? 8'd255
                             : 8'd0;

                endcase

            end


            
            // Pattern 2
            //
            // R = checker
            // G = diagonal
            // B = horizontal
           
            2: begin

                case (channel)

                    0:
                        return ((((x / 8) + (y / 8)) % 2) == 0)
                             ? 8'd0
                             : 8'd255;

                    1:
                        return (x == y)
                             ? 8'd255
                             : 8'd0;

                    default:
                        return (y >= h / 2)
                             ? 8'd255
                             : 8'd0;

                endcase

            end


            // Pattern 3
            //
            // R = diagonal
            // G = vertical
            // B = checker
            

            3: begin

                case (channel)

                    0:
                        return (x == y)
                             ? 8'd255
                             : 8'd0;

                    1:
                        return (x >= w / 2)
                             ? 8'd255
                             : 8'd0;

                    default:
                        return ((((x / 8) + (y / 8)) % 2) == 0)
                             ? 8'd0
                             : 8'd255;

                endcase

            end


            // Pattern 4
            //
            // Independent random R/G/B values.
           

            default: begin

                return 8'($urandom_range(255, 0));

            end

        endcase

    endfunction


    // Generate complete RGB image.
    

    task automatic make_pattern(
        input int kind,
        input int w,
        input int h
    );

        W = w;
        H = h;

        img = new[w * h];

        for (int y = 0; y < h; y++) begin

            for (int x = 0; x < w; x++) begin

                logic [7:0] r;
                logic [7:0] g;
                logic [7:0] b;

                r = pattern_value(kind, x, y, w, h, 0);
                g = pattern_value(kind, x, y, w, h, 1);
                b = pattern_value(kind, x, y, w, h, 2);

                img[y * w + x] = {
                    r,
                    g,
                    b
                };

            end

        end

    endtask


    // Extract one RGB channel from the stored image.
    //
    // channel = 0 -> R
    // channel = 1 -> G
    // channel = 2 -> B
    

    function automatic int px(
        input int y,
        input int x,
        input int channel
    );

        logic [23:0] p;

        p = img[y * W + x];

        case (channel)

            0: return p[23:16];
            1: return p[15:8];
            default: return p[7:0];

        endcase

    endfunction


    // Absolute value

    function automatic int iabs(input int v);

        return (v < 0) ? -v : v;

    endfunction


    // Software reference Sobel for ONE RGB channel.
    //
    // This matches the Sobel operation performed by the RTL.
    //
    // Gx:
    //
    // -1  0 +1
    // -2  0 +2
    // -1  0 +1
    //
    // Gy:
    //
    // +1 +2 +1
    //  0  0  0
    // -1 -2 -1

    function automatic int sobel_ref_channel(
        input int y,
        input int x,
        input int channel
    );

        int gx;
        int gy;
        int mag;

        gx =
              -px(y-1, x-1, channel)
              +px(y-1, x+1, channel)

              -2*px(y, x-1, channel)
              +2*px(y, x+1, channel)

              -px(y+1, x-1, channel)
              +px(y+1, x+1, channel);


        gy =
               px(y-1, x-1, channel)
              +2*px(y-1, x,   channel)
              +px(y-1, x+1, channel)

              -px(y+1, x-1, channel)
              -2*px(y+1, x,   channel)
              -px(y+1, x+1, channel);


        mag = iabs(gx) + iabs(gy);

        return (mag > 255) ? 255 : mag;

    endfunction


    // Complete RGB reference model.
    //
    // ER = Sobel(R)
    // EG = Sobel(G)
    // EB = Sobel(B)
    //
    // output = max(ER, EG, EB)
    

    function automatic int sobel_ref(
        input int y,
        input int x
    );

        int er;
        int eg;
        int eb;
        int max_grad;

        er = sobel_ref_channel(y, x, 0);
        eg = sobel_ref_channel(y, x, 1);
        eb = sobel_ref_channel(y, x, 2);


        // max(R,G)

        if (er > eg)
            max_grad = er;
        else
            max_grad = eg;


        // max(previous,B)

        if (eb > max_grad)
            max_grad = eb;


        return (max_grad > 255)
             ? 255
             : max_grad;

    endfunction


    // Reset DUT

    task automatic reset_dut();

        rst      = 1'b1;
        valid_in = 1'b0;
        pixel_in = 24'd0;

        repeat (3)
            @(posedge clk);

        #1 rst = 1'b0;

    endtask

    // Stream image through DUT.
    //
    // Important timing:
    //
    // The complete 3x3 window centred at pixel n becomes available
    // after W+2 accepted input clocks.
    //
    // Therefore:
    //
    //     centre = accepted_pixel_index - (W + 2)
    //
    // One extra accepted dummy pixel is needed after the final real
    // image pixel to obtain the final interior output.
    
    task automatic stream_image(input bit stalls);

        int total;
        int centre;

        // One extra accepted dummy pixel after the image.
        total = W * H + 1;

        got  = new[W * H];
        seen = new[W * H];


        for (int i = 0; i < W * H; i++) begin

            got[i]  = 8'd0;
            seen[i] = 1'b0;

        end


        n_valid           = 0;
        n_bad_index       = 0;
        n_idle_violations = 0;


        image_width = 16'(W);

        reset_dut();


        for (int a = 0; a < total; a++) begin

            // Optional random stalls.

            if (stalls) begin

                while ($urandom_range(3, 0) == 0) begin

                    valid_in = 1'b0;

                    // Garbage should be ignored when valid_in = 0.
                    pixel_in = $urandom;

                    @(posedge clk);
                    #1;

                    if (valid_out)
                        n_idle_violations++;

                end

            end


            // Send one accepted RGB pixel.
            
            valid_in = 1'b1;

            if (a < W * H)
                pixel_in = img[a];
            else
                pixel_in = 24'd0;


            @(posedge clk);
            #1;


            // Capture DUT output.
            
            
            if (valid_out) begin

                centre = a - (W + 2);


                if (centre < 0 || centre >= W * H) begin

                    n_bad_index++;

                end else begin

                    got[centre]  = pixel_out;
                    seen[centre] = 1'b1;

                    n_valid++;

                end

            end

        end


        valid_in = 1'b0;
        pixel_in = 24'd0;

    endtask


    // Compare DUT output against RGB software reference.
    
    function automatic int check_image(
        input string name
    );

        int errs;
        int expected_valid;
        int e;


        errs = 0;


        expected_valid =
            (W >= 3 && H >= 3)
            ? (W - 2) * (H - 2)
            : 0;


        // Check every pixel.
        
        
        for (int y = 0; y < H; y++) begin

            for (int x = 0; x < W; x++) begin

                // Interior pixel.
                if (
                    y >= 1 &&
                    y <= H - 2 &&
                    x >= 1 &&
                    x <= W - 2
                ) begin

                    e = sobel_ref(y, x);


                    if (
                        !seen[y * W + x] ||
                        int'(got[y * W + x]) != e
                    ) begin

                        errs++;


                        if (errs <= 5) begin

                            $display(
                                "  MISMATCH %s (y=%0d,x=%0d): expected %0d, got %0d%s",
                                name,
                                y,
                                x,
                                e,
                                got[y * W + x],
                                seen[y * W + x]
                                    ? ""
                                    : " (no output)"
                            );

                        end

                    end

                end


                // Border must not have an output.
                

                else if (seen[y * W + x]) begin

                    errs++;


                    if (errs <= 5) begin

                        $display(
                            "  UNEXPECTED output on border %s (y=%0d,x=%0d)",
                            name,
                            y,
                            x
                        );

                    end

                end

            end

        end


        // Check number of valid outputs.
        
        if (n_valid != expected_valid) begin

            errs++;

            $display(
                "  %s: expected %0d valid outputs, saw %0d",
                name,
                expected_valid,
                n_valid
            );

        end


        // Check invalid output indices.
        

        if (n_bad_index != 0) begin

            errs += n_bad_index;

            $display(
                "  %s: %0d outputs landed outside the image",
                name,
                n_bad_index
            );

        end


        // Check valid_out during stalls.
        

        if (n_idle_violations != 0) begin

            errs += n_idle_violations;

            $display(
                "  %s: valid_out was high %0d times while valid_in was low",
                name,
                n_idle_violations
            );

        end


        return errs;

    endfunction


    // ASCII PPM (P3) input parser
    

    task automatic next_int(
        input int fd,
        output int value
    );

        int c;

        value = -1;

        c = $fgetc(fd);


        while (c != -1) begin

            // Skip comments.
            if (c == "#") begin

                while (c != -1 && c != "\n")
                    c = $fgetc(fd);

            end

            // Skip whitespace.
            else if (
                c == " "  ||
                c == "\n" ||
                c == "\r" ||
                c == "\t"
            ) begin

                c = $fgetc(fd);

            end

            else begin

                break;

            end

        end


        // Read integer.
        if (c >= "0" && c <= "9") begin

            value = 0;

            while (c >= "0" && c <= "9") begin

                value = value * 10 + (c - "0");

                c = $fgetc(fd);

            end

        end

    endtask


    // Read ASCII RGB PPM (P3)

    task automatic read_ppm(
        input string path
    );

        int fd;
        int c1;
        int c2;

        int w;
        int h;
        int maxv;

        int r;
        int g;
        int b;


        fd = $fopen(path, "r");

        if (fd == 0)
            $fatal(1, "Cannot open input file %s", path);


        // Check P3 header.

        c1 = $fgetc(fd);
        c2 = $fgetc(fd);


        if (c1 != "P" || c2 != "3")
            $fatal(
                1,
                "%s is not an ASCII RGB PPM (expected P3 header)",
                path
            );


        // Read dimensions.

        next_int(fd, w);
        next_int(fd, h);
        next_int(fd, maxv);


        if (
            w < 3 ||
            h < 3 ||
            maxv < 1
        ) begin

            $fatal(
                1,
                "Bad PPM header in %s (width %0d, height %0d, maxval %0d)",
                path,
                w,
                h,
                maxv
            );

        end


        if (w > dut.WIDTH) begin

            $fatal(
                1,
                "Image is %0d wide but line buffers hold %0d pixels",
                w,
                dut.WIDTH
            );

        end


        W = w;
        H = h;


        img = new[w * h];


        // Read R/G/B values.

        for (int i = 0; i < w * h; i++) begin

            next_int(fd, r);
            next_int(fd, g);
            next_int(fd, b);


            if (
                r < 0 ||
                g < 0 ||
                b < 0
            ) begin

                $fatal(
                    1,
                    "%s ended early while reading RGB pixel %0d",
                    path,
                    i
                );

            end


            // Scale to 8-bit if maxv is not 255.

            r = (r * 255) / maxv;
            g = (g * 255) / maxv;
            b = (b * 255) / maxv;


            img[i] = {
                8'(r),
                8'(g),
                8'(b)
            };

        end


        $fclose(fd);

    endtask


    // Write grayscale PGM output.
    
    task automatic write_pgm(
        input string path
    );

        int fd;


        fd = $fopen(path, "w");

        if (fd == 0)
            $fatal(1, "Cannot open output file %s", path);


        $fwrite(
            fd,
            "P2\n%0d %0d\n255\n",
            W,
            H
        );


        for (int y = 0; y < H; y++) begin

            for (int x = 0; x < W; x++) begin

                $fwrite(
                    fd,
                    "%0d ",
                    got[y * W + x]
                );

            end

            $fwrite(fd, "\n");

        end


        $fclose(fd);

    endtask


    // Test sequence

    localparam int N_SIZES = 6;

    localparam int SIZE_W [N_SIZES] =
        '{128, 37, 8, 5, 3, 100};

    localparam int SIZE_H [N_SIZES] =
        '{64,  23, 8, 5, 3, 60};


    int total_errors;
    int n_tests;
    int errs;

    string in_path;
    string out_path;
    string name;


    initial begin

        total_errors = 0;
        n_tests      = 0;

        valid_in = 1'b0;
        rst      = 1'b1;


        // FILE MODE

        if ($value$plusargs("in=%s", in_path)) begin

            if (
                !$value$plusargs(
                    "out=%s",
                    out_path
                )
            )
                out_path = "sobel_out.pgm";


            read_ppm(in_path);


            $display(
                "Loaded RGB image: %0dx%0d",
                W,
                H
            );


            stream_image(1'b0);


            errs = check_image(in_path);


            write_pgm(out_path);


            $display(
                "Output written to %s",
                out_path
            );


            if (errs == 0) begin

                $display(
                    "PASS: RGB RTL matches the software RGB Sobel model."
                );

            end else begin

                $fatal(
                    1,
                    "FAIL: RGB output differs from software model (%0d problems)",
                    errs
                );

            end


        end


        // REGRESSION MODE

        else begin

            for (int k = 0; k < N_KINDS; k++) begin

                for (int s = 0; s < N_SIZES; s++) begin

                    make_pattern(
                        k,
                        SIZE_W[s],
                        SIZE_H[s]
                    );


                    stream_image(1'b0);


                    name = $sformatf(
                        "%s_%0dx%0d",
                        pattern_name(k),
                        W,
                        H
                    );


                    errs = check_image(name);


                    n_tests++;

                    total_errors += errs;


                    $display(
                        "%s %s",
                        (errs == 0)
                            ? "PASS"
                            : "FAIL",
                        name
                    );

                end

            end


            // Noise test with random valid_in stalls.

            make_pattern(
                4,
                37,
                23
            );


            stream_image(1'b1);


            name = "noise_rgb_37x23_with_stalls";


            errs = check_image(name);


            n_tests++;

            total_errors += errs;


            $display(
                "%s %s",
                (errs == 0)
                    ? "PASS"
                    : "FAIL",
                name
            );


            // Final result.

            if (total_errors == 0) begin

                $display(
                    "ALL %0d RGB TESTS PASSED",
                    n_tests
                );

            end else begin

                $fatal(
                    1,
                    "%0d problems across %0d RGB tests",
                    total_errors,
                    n_tests
                );

            end

        end


        $finish;

    end

endmodule
