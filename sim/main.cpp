#include "Vsobel.h"
#include "verilated.h"

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#incude <cstdint>

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cout << "Usage: ./Vsobel input.pgm output.pgm\n";
        return 1;
    }

    std::string input_file = argv[1];
    std::string output_file = argv[2];

    //RGB PPM input
    std::ifstream infile(input_file);
    if (!infile) {
        std::cerr << "Failed to open input file: "
                  << input_file << "\n";
        return 1;
    }
    
    std::string magic;
    int width, height, maxval;
    infile >> magic;

    if (magic != "P3") {             //P3 is for ASCII RGB PPM
        std::cerr << "Error: input file is not an ASCII RGB PPM (P3).\n";
        std::cerr << "Expected P3, got: " << magic << "\n";
        return 1;
    }
    
    infile >> width >> height;
    infile >> maxval;

    std::cout << "Loaded RGB image: "
          << width << "x" << height
          << "  maxval=" << maxval << "\n";

    std::vector<int> image(width * height);

    //changed for R , G, B pixels
    for (int i = 0; i < width * height; i++) {

        int R;
        int G;
        int B;
        
        infile >> R >> G >> B;

        if (!infile) {
            std::cerr << "Error while reading RGB pixel "
                      << i << "\n";
            return 1;
        }

        image[i] =
              (static_cast<uint32_t>(R) << 16)
            | (static_cast<uint32_t>(G) << 8)
            |  static_cast<uint32_t>(B);
    }
    
    infile.close();

    Vsobel* top = new Vsobel;
    top->image_width = width;

    top->clk = 0;
    top->rst = 1;
    top->valid_in = 0;
    top->pixel_in = 0;

    for (int i = 0; i < 5; i++) {
        top->clk = !top->clk;
        top->eval();
    }
    top->rst = 0;

    std::vector<int> output(width * height, 0);

    // The module has a latency of (width + 2) clocks: the result for the window
    // centred on pixel n appears on clock edge n + width + 2. Run a couple of
    // extra clocks after the last pixel to collect the final results, and store
    // each result at the position of its centre pixel.
    const int total_clocks = width * height + 2;    ----------------------------
    for (int i = 0; i < total_clocks; i++) {                                    |
                                                                                |  
        top->valid_in = 1;                                                      |---------> Some changes need to be done here 
        top->pixel_in = (i < width * height) ? image[i] : 0;                    |

        top->clk = 0;
        top->eval();
        top->clk = 1;                                                           |  
        top->eval();                                  --------------------------                 

        if (top->valid_out) {
            int centre = i - (width + 2);
            if (centre >= 0 && centre < width * height) {
                output[centre] = top->pixel_out;
            }
        }
    }                                 

    delete top;

    std::ofstream outfile(output_file);

    //write output PGM here:-

    outfile << "P2\n";
    outfile << width << " " << height << "\n";
    outfile << "255\n";

    for (int i = 0; i < width * height; i++) {
        outfile << output[i] << " ";
        if ((i + 1) % width == 0) {
            outfile << "\n";
        }
    }

    outfile.close();

    std::cout << "RGB sobel output written to " << output_file << "\n";

    return 0;
    
}
