/* Framebuffer test - draw checker pattern */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/ioctl.h>

/* Simplified fb structures for our test */
struct fb_var_screeninfo
{
    uint32_t xres;
    uint32_t yres;
    uint32_t xres_virtual;
    uint32_t yres_virtual;
    uint32_t xoffset;
    uint32_t yoffset;
    uint32_t bits_per_pixel;
};

struct fb_fix_screeninfo
{
    char id[16];
    unsigned long smem_start;
    uint32_t smem_len;
    uint32_t type;
    uint32_t type_aux;
    uint32_t visual;
    uint16_t xpanstep;
    uint16_t ypanstep;
    uint16_t ywrapstep;
    uint32_t line_length;
};

#define FBIOGET_VSCREENINFO 0x4600
#define FBIOGET_FSCREENINFO 0x4602

int main()
{
    int fd;
    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    uint32_t *fbp;
    int x, y;
    int square_size = 50;

    printf("Opening framebuffer device /dev/fb0...\n");
    fd = open("/dev/fb0", O_RDWR);
    if (fd == -1)
    {
        perror("Error opening framebuffer device");
        return 1;
    }

    /* Get fixed screen information */
    if (ioctl(fd, FBIOGET_FSCREENINFO, &finfo) == -1)
    {
        perror("Error reading fixed information");
        close(fd);
        return 1;
    }

    /* Get variable screen information */
    if (ioctl(fd, FBIOGET_VSCREENINFO, &vinfo) == -1)
    {
        perror("Error reading variable information");
        close(fd);
        return 1;
    }

    printf("Framebuffer: %dx%d, %d bpp\n",
           vinfo.xres, vinfo.yres, vinfo.bits_per_pixel);
    printf("Line length: %d bytes\n", finfo.line_length);

    /* Allocate buffer */
    int screensize = vinfo.yres * finfo.line_length;
    fbp = (uint32_t *)malloc(screensize);
    if (!fbp)
    {
        printf("Error allocating framebuffer memory\n");
        close(fd);
        return 1;
    }

    printf("Drawing checker pattern...\n");

    /* Draw checker pattern */
    for (y = 0; y < vinfo.yres; y++)
    {
        for (x = 0; x < vinfo.xres; x++)
        {
            int check_x = (x / square_size) % 2;
            int check_y = (y / square_size) % 2;
            uint32_t color;

            if (check_x == check_y)
            {
                /* White square */
                color = 0xFFFFFFFF;
            }
            else
            {
                /* Black square */
                color = 0xFF000000;
            }

            /* Calculate position in framebuffer */
            int offset = y * (finfo.line_length / 4) + x;
            fbp[offset] = color;
        }
    }

    /* Write to framebuffer */
    printf("Writing to framebuffer...\n");
    if (write(fd, fbp, screensize) != screensize)
    {
        perror("Error writing to framebuffer");
    }
    else
    {
        printf("Checker pattern drawn successfully!\n");
    }

    free(fbp);
    close(fd);

    printf("Press Enter to exit...\n");
    getchar();

    return 0;
}
