import sys
import numpy as np


# Write an ASCII P3 RGB PPM image

def write_ppm(filename, image):
    """
    image shape:
        (height, width, 3)

    Channel order:
        image[y, x, 0] = R
        image[y, x, 1] = G
        image[y, x, 2] = B
    """

    h, w, _ = image.shape

    with open(filename, "w") as f:
        f.write("P3\n")
        f.write(f"{w} {h}\n")
        f.write("255\n")

        for y in range(h):
            for x in range(w):
                r, g, b = image[y, x]

                f.write(
                    f"{int(r)} {int(g)} {int(b)} "
                )

            f.write("\n")


# Basic RGB pattern generators

def vertical_pattern(width, height):
    """
    Vertical edge:
        left  = 0
        right = 255
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    img[:, width // 2:, :] = 255

    return img


def horizontal_pattern(width, height):
    """
    Horizontal edge:
        top    = 0
        bottom = 255
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    img[height // 2:, :, :] = 255

    return img


def checker_pattern(width, height, block_size=8):
    """
    Checkerboard pattern.
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    for y in range(height):
        for x in range(width):

            if ((x // block_size) +
                (y // block_size)) % 2 == 0:

                value = 0

            else:

                value = 255

            img[y, x, :] = value

    return img


def diagonal_pattern(width, height):
    """
    Diagonal line.
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    for i in range(min(width, height)):
        img[i, i, :] = 255

    return img


# RGB test patterns

def vertical_rgb(width, height):
    """
    R channel -> vertical
    G channel -> horizontal
    B channel -> diagonal

    This deliberately gives each RGB path a different pattern.
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    # R = vertical
    img[:, width // 2:, 0] = 255

    # G = horizontal
    img[height // 2:, :, 1] = 255

    # B = diagonal
    for i in range(min(width, height)):
        img[i, i, 2] = 255

    return img


def horizontal_rgb(width, height):
    """
    R channel -> horizontal
    G channel -> checkerboard
    B channel -> vertical
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    # R = horizontal
    img[height // 2:, :, 0] = 255

    # G = checkerboard
    block_size = 8

    for y in range(height):
        for x in range(width):

            if ((x // block_size) +
                (y // block_size)) % 2 == 1:

                img[y, x, 1] = 255

    # B = vertical
    img[:, width // 2:, 2] = 255

    return img


def checker_rgb(width, height):
    """
    R channel -> checkerboard
    G channel -> diagonal
    B channel -> horizontal
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    # R = checkerboard
    block_size = 8

    for y in range(height):
        for x in range(width):

            if ((x // block_size) +
                (y // block_size)) % 2 == 1:

                img[y, x, 0] = 255

    # G = diagonal
    for i in range(min(width, height)):
        img[i, i, 1] = 255

    # B = horizontal
    img[height // 2:, :, 2] = 255

    return img


def diagonal_rgb(width, height):
    """
    R channel -> diagonal
    G channel -> vertical
    B channel -> checkerboard
    """

    img = np.zeros((height, width, 3), dtype=np.uint8)

    # R = diagonal
    for i in range(min(width, height)):
        img[i, i, 0] = 255

    # G = vertical
    img[:, width // 2:, 1] = 255

    # B = checkerboard
    block_size = 8

    for y in range(height):
        for x in range(width):

            if ((x // block_size) +
                (y // block_size)) % 2 == 1:

                img[y, x, 2] = 255

    return img


def random_noise_rgb(width, height):
    """
    Independent random noise in R, G and B.
    """

    img = np.random.randint(
        0,
        256,
        (height, width, 3),
        dtype=np.uint8
    )

    return img


# Main

if __name__ == "__main__":

    if len(sys.argv) < 4:

        print(
            "Usage: python imagegen.py "
            "width height test_type"
        )

        print(
            "test_type = "
            "vertical | horizontal | checker | diagonal | noise"
        )

        sys.exit(1)


    width = int(sys.argv[1])
    height = int(sys.argv[2])
    test_type = sys.argv[3].lower()


    # Select test pattern

    if test_type == "vertical":

        image = vertical_rgb(width, height)

    elif test_type == "horizontal":

        image = horizontal_rgb(width, height)

    elif test_type == "checker":

        image = checker_rgb(width, height)

    elif test_type == "diagonal":

        image = diagonal_rgb(width, height)

    elif test_type == "noise":

        image = random_noise_rgb(width, height)

    else:

        print(f"Unknown test type: {test_type}")

        print(
            "test_type = "
            "vertical | horizontal | checker | diagonal | noise"
        )

        sys.exit(1)


    # Output filename

    filename = f"{test_type}_rgb_{width}x{height}.ppm"


    # Write P3 PPM

    write_ppm(filename, image)


    print(f"Generated {filename}")
