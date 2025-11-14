/* Framebuffer test - draw checker pattern */
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>

/* Simple write wrapper */
static void print(const char *str)
{
    write(1, str, __builtin_strlen(str));
}

static void print_num(int num)
{
    char buf[12];
    int i = 0;
    int neg = 0;

    if (num < 0)
    {
        neg = 1;
        num = -num;
    }

    if (num == 0)
    {
        write(1, "0", 1);
        return;
    }

    while (num > 0)
    {
        buf[i++] = '0' + (num % 10);
        num /= 10;
    }

    if (neg)
        buf[i++] = '-';

    while (i > 0)
    {
        write(1, &buf[--i], 1);
    }
}

int main()
{
    int fd;
    uint32_t pixel;
    int x, y;
    int square_size = 50;
    int width = 800;
    int height = 600;
    int written;

    print("Opening /dev/fb0...\n");
    fd = open("/dev/fb0", O_WRONLY);
    if (fd < 0)
    {
        print("Error: Cannot open /dev/fb0\n");
        return 1;
    }

    print("Drawing checker pattern to framebuffer...\n");

    /* Draw checker pattern pixel by pixel */
    for (y = 0; y < height; y++)
    {
        for (x = 0; x < width; x++)
        {
            int check_x = (x / square_size) % 2;
            int check_y = (y / square_size) % 2;

            if (check_x == check_y)
            {
                /* White square - ARGB format */
                pixel = 0xFFFFFFFF;
            }
            else
            {
                /* Black square - ARGB format */
                pixel = 0xFF000000;
            }

            /* Write pixel */
            written = write(fd, &pixel, 4);
            if (written != 4)
            {
                print("Write error at pixel ");
                print_num(y * width + x);
                print("\n");
                close(fd);
                return 1;
            }
        }

        /* Progress indicator every 100 lines */
        if (y % 100 == 0)
        {
            print(".");
        }
    }

    print("\nChecker pattern complete!\n");
    close(fd);
    return 0;
}
