// RGB image pipeline testbench for sobel.sv. Pure SystemVerilog.
//
//   ./Vsobel_image_tb +in=image.ppm +out=result.pgm
//
// Reads an ASCII (P3) RGB PPM, streams it through the DUT, checks the
// result against a software RGB Sobel model computed here, and writes
// the resulting edge image as an ASCII (P2) grayscale PGM.
//
// RGB processing:
//
//      R channel -> Sobel -> ER
//      G channel -> Sobel -> EG
//      B channel -> Sobel -> EB
//
//      output = min(255, max(ER, EG, EB))
//
// Converting a normal image (PNG/JPG) to P3 PPM and the final PGM
// to PNG is done outside the simulation, see the process_sv target
// in the Makefile.

module sobel_image_tb;

    // DUT and clock

    logic        clk = 1'b0;
    logic        rst;
    logic [15:0] image_width;

    logic        valid_in;
    logic [23:0] pixel_in;

    logic        valid_out;
    logic [7:0]  pixel_out;

    sobel dut (.*);

    always #5 clk = ~clk;


    // Image storage
    //
    // One 24-bit word per pixel:
    //
    //     [23:16] = R
    //     [15:8]  = G
    //     [7:0]   = B
    
    int W, H;

    logic [23:0] img [];
    logic [7:0]  got [];
    bit          seen [];

    int n_valid;
    int n_bad_index;


    // P3 PPM parser
    //
    // Reads the next unsigned integer from an ASCII PPM file.
    //
    // Comments beginning with '#' are skipped.
    //
    // Returns -1 at EOF.

    task automatic next_int(input int fd, output int value);

        int c;

        value = -1;

        c = $fgetc(fd);

        while (c != -1) begin

            // Skip comment
            if (c == "#") begin

                while (c != -1 && c != "\n")
                    c = $fgetc(fd);

            end

            // Skip whitespace
            else if (c == " " ||
                     c == "\n" ||
                     c == "\r" ||
                     c == "\t") begin

                c = $fgetc(fd);

            end

            else begin
                break;
            end

        end

        // Read integer
        if (c >= "0" && c <= "9") begin

            value = 0;

            while (c >= "0" && c <= "9") begin

                value = value * 10 + (c - "0");
                c = $fgetc(fd);

            end

        end

    endtask


    // Read ASCII P3 RGB PPM

    task automatic read_ppm(input string path);

        int fd;
        int c1, c2;

        int w, h, maxv;
        int r, g, b;

        fd = $fopen(path, "r");

        if (fd == 0)
            $fatal(1, "Cannot open input file %s", path);


        // Check P3 header

        c1 = $fgetc(fd);
        c2 = $fgetc(fd);

        if (c1 != "P" || c2 != "3")
            $fatal(1,
                   "%s is not an ASCII RGB PPM (expected P3 header)",
                   path);


        // Read image dimensions

        next_int(fd, w);
        next_int(fd, h);
        next_int(fd, maxv);


        if (w < 3 || h < 3 || maxv < 1)

        $fatal(1,
            "Bad PPM header in %s (width %0d, height %0d, maxval %0d)",
            path, w, h, maxv);


        // Check WIDTH parameter in DUT

        if (w > dut.WIDTH)

            $fatal(1,
                    "Image is %0d pixels wide but the module's line buffers hold only %0d pixels. Raise the WIDTH parameter.",
                    w, dut.WIDTH);


        W = w;
        H = h;


        // Allocate image
        
        img = new[w * h];


        // Read RGB pixels

        for (int i = 0; i < w * h; i++) begin

            next_int(fd, r);
            next_int(fd, g);
            next_int(fd, b);


            if (r < 0 || g < 0 || b < 0)

                $fatal(1,
                        "%s ended early: expected %0d RGB pixels, found only %0d",
                        path, w * h, i);


            // PPM values may use a maxval other than 255.
            // Scale to 8-bit.
            r = (r * 255) / maxv;
            g = (g * 255) / maxv;
            b = (b * 255) / maxv;


            if (r > 255) r = 255;
            if (g > 255) g = 255;
            if (b > 255) b = 255;


            // Pack RGB:
            //
            // [23:16] = R
            // [15:8]  = G
            // [7:0]   = B

            img[i] = {
                r[7:0],
                g[7:0],
                b[7:0]
            };

        end


        $fclose(fd);

    endtask


    // Write grayscale P2 PGM
    //
    // The DUT produces one 8-bit edge magnitude.
    //
    // Therefore the output is grayscale.

    task automatic write_pgm(input string path);

        int fd;

        fd = $fopen(path, "w");

        if (fd == 0)
            $fatal(1, "Cannot open output file %s", path);


        $fwrite(fd,
                "P2\n%0d %0d\n255\n",
                W,
                H);


        for (int y = 0; y < H; y++) begin

            for (int x = 0; x < W; x++) begin

                $fwrite(fd,
                        "%0d ",
                        got[y * W + x]);

            end

            $fwrite(fd, "\n");

        end


        $fclose(fd);

    endtask


    // Extract one RGB channel
    //
    // channel:
    //     0 = R
    //     1 = G
    //     2 = B

    function automatic int px(
        input int y,
        input int x,
        input int channel
    );

        logic [23:0] p;

        p = img[y * W + x];

        case (channel)

            0: return int'(p[23:16]); // R
            1: return int'(p[15:8]);  // G
            2: return int'(p[7:0]);   // B

            default: return 0;

        endcase

    endfunction


    // Absolute value

    function automatic int iabs(input int v);

        return (v < 0) ? -v : v;

    endfunction


    // Software Sobel for ONE channel

    function automatic int sobel_ref_channel(
        input int y,
        input int x,
        input int channel
    );

        int gx;
        int gy;
        int mag;


        // Sobel X

        gx =
              px(y-1, x+1, channel)
            + 2 * px(y,   x+1, channel)
            + px(y+1, x+1, channel)

            - px(y-1, x-1, channel)
            - 2 * px(y,   x-1, channel)
            - px(y+1, x-1, channel);


        // Sobel Y

        gy =
              px(y+1, x-1, channel)
            + 2 * px(y+1, x,   channel)
            + px(y+1, x+1, channel)

            - px(y-1, x-1, channel)
            - 2 * px(y-1, x,   channel)
            - px(y-1, x+1, channel);


        // Magnitude

        mag = iabs(gx) + iabs(gy);


        // Clamp to 8-bit

        if (mag > 255)
            return 255;
        else
            return mag;

    endfunction


    // RGB Sobel reference
    //
    // ER = Sobel(R)
    // EG = Sobel(G)
    // EB = Sobel(B)
    //
    // Output = max(ER, EG, EB)

    function automatic int sobel_ref(
        input int y,
        input int x
    );

        int er;
        int eg;
        int eb;
        int mag;


        er = sobel_ref_channel(y, x, 0);
        eg = sobel_ref_channel(y, x, 1);
        eb = sobel_ref_channel(y, x, 2);


        // Maximum channel magnitude

        mag = er;

        if (eg > mag)
            mag = eg;

        if (eb > mag)
            mag = eb;


        // Final clamp

        if (mag > 255)
            return 255;
        else
            return mag;

    endfunction


    // Reset DUT

    task automatic reset_dut();

        rst      = 1'b1;
        valid_in = 1'b0;
        pixel_in = 24'd0;

        repeat (3)
            @(posedge clk);

        #1;

        rst = 1'b0;

    endtask


    // Stream image through DUT
    //
    // Current RTL timing:
    //
    // Input accepted at index a
    //          |
    //          | W + 2 clocks
    //          v
    // Output corresponds to centre:
    //
    //     centre = a - (W + 2)
    //
    // Only interior pixels generate valid output:
    //
    //     x = 1 ... W-2
    //     y = 1 ... H-2
    //
    // One additional accepted dummy pixel is required after the final
    // real image pixel to flush the last output.

    task automatic stream_image();

        int total;
        int centre;


        // One dummy pixel after the final real pixel

        total = W * H + 1;


        // Allocate output arrays

        got  = new[W * H];
        seen = new[W * H];


        for (int i = 0; i < W * H; i++) begin

            got[i]  = 8'd0;
            seen[i] = 1'b0;

        end


        n_valid      = 0;
        n_bad_index  = 0;


        // Tell DUT image width

        image_width = 16'(W);


        // Reset
        reset_dut();


        // Stream pixels

        for (int a = 0; a < total; a++) begin

            valid_in = 1'b1;


            if (a < W * H)

                pixel_in = img[a];

            else

                // Flush pixel
                pixel_in = 24'd0;


            @(posedge clk);

            #1;


            // Capture DUT output

            if (valid_out) begin

                centre = a - (W + 2);


                if (centre < 0 || centre >= W * H) begin

                    n_bad_index++;

                end

                else begin

                    got[centre]  = pixel_out;
                    seen[centre] = 1'b1;

                    n_valid++;

                end

            end

        end


        valid_in = 1'b0;
        pixel_in = 24'd0;

    endtask


    // Compare RTL result with software reference

    function automatic int check_image();

        int errs;
        int e;


        errs = 0;


        for (int y = 0; y < H; y++) begin

            for (int x = 0; x < W; x++) begin


                // Interior pixels

                if (y >= 1 &&
                    y <= H - 2 &&
                    x >= 1 &&
                    x <= W - 2) begin


                    e = sobel_ref(y, x);


                    if (!seen[y * W + x] ||
                        int'(got[y * W + x]) != e) begin

                        errs++;


                        if (errs <= 10)

                            $display(
                                "  MISMATCH (y=%0d,x=%0d): expected %0d, got %0d",
                                y,
                                x,
                                e,
                                got[y * W + x]
                            );

                    end

                end


                // Border pixels must not generate output

                else if (seen[y * W + x]) begin

                    errs++;


                    if (errs <= 10)

                        $display(
                            "  UNEXPECTED output on border (y=%0d,x=%0d)",
                            y,
                            x
                        );

                end

            end

        end


        // Check number of valid outputs

        if (n_valid != (W - 2) * (H - 2)) begin

            errs++;

            $display(
                "  Expected %0d valid outputs, saw %0d",
                (W - 2) * (H - 2),
                n_valid
            );

        end


        // Check invalid output indices

        if (n_bad_index != 0) begin

            errs += n_bad_index;

            $display(
                "  Saw %0d outputs with invalid centre indices",
                n_bad_index
            );

        end


        return errs;

    endfunction


    // Main

    string in_path;
    string out_path;

    int errs;


    initial begin

        rst      = 1'b1;
        valid_in = 1'b0;
        pixel_in = 24'd0;


        // Command-line arguments

        if (!$value$plusargs("in=%s", in_path))

            $fatal(
                1,
                "Usage: ./Vsobel_image_tb +in=input.ppm [+out=output.pgm]"
            );

        if (!$value$plusargs("out=%s", out_path))

            out_path = "sobel_out.pgm";


        // Read RGB image

        read_ppm(in_path);


        $display(
            "Loaded RGB image: %0dx%0d",
            W,
            H
        );


        // Run DUT

        stream_image();


        // Compare against software model

        errs = check_image();


        // Write output

        write_pgm(out_path);


        $display(
            "Output written to %s",
            out_path
        );


        // Final result

        if (errs == 0) begin

            $display(
                "PASS: RTL RGB Sobel matches the software reference."
            );

        end

        else begin

            $fatal(
                1,
                "FAIL: RGB Sobel output differs from the software model (%0d problems)",
                errs
            );

        end


        $finish;

    end

endmodule
