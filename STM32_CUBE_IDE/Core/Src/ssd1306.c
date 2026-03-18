#include "ssd1306.h"

extern I2C_HandleTypeDef hi2c1;

#define SSD1306_ADDR (0x3C << 1)

uint8_t buffer[1024];
char grid_state[15];

const uint8_t font_R[5] = {0xE,0x9,0xE,0xA,0x9};
const uint8_t font_G[5] = {0x7,0x8,0xB,0x9,0x7};
const uint8_t font_B[5] = {0xE,0x9,0xE,0x9,0xE};

void ssd1306_write_command(uint8_t cmd)
{
    uint8_t data[2] = {0x00, cmd};
    HAL_I2C_Master_Transmit(&hi2c1, SSD1306_ADDR, data, 2, HAL_MAX_DELAY);
}

void ssd1306_write_data(uint8_t data_byte)
{
    uint8_t data[2] = {0x40, data_byte};
    HAL_I2C_Master_Transmit(&hi2c1, SSD1306_ADDR, data, 2, HAL_MAX_DELAY);
}

void ssd1306_init(void)
{
    HAL_Delay(100);

    ssd1306_write_command(0xAE);
    ssd1306_write_command(0xD5);
    ssd1306_write_command(0x80);
    ssd1306_write_command(0xA8);
    ssd1306_write_command(0x3F);
    ssd1306_write_command(0xD3);
    ssd1306_write_command(0x00);
    ssd1306_write_command(0x40);
    ssd1306_write_command(0x8D);
    ssd1306_write_command(0x14);
    ssd1306_write_command(0x20);
    ssd1306_write_command(0x00);
    ssd1306_write_command(0xA1);
    ssd1306_write_command(0xC8);
    ssd1306_write_command(0xDA);
    ssd1306_write_command(0x12);
    ssd1306_write_command(0x81);
    ssd1306_write_command(0xCF);
    ssd1306_write_command(0xD9);
    ssd1306_write_command(0xF1);
    ssd1306_write_command(0xDB);
    ssd1306_write_command(0x40);
    ssd1306_write_command(0xA4);
    ssd1306_write_command(0xA6);
    ssd1306_write_command(0xAF);

    ssd1306_clear();
    ssd1306_update_screen();
}

void ssd1306_update_screen(void)
{
    for(uint8_t page = 0; page < 8; page++)
    {
        ssd1306_write_command(0xB0 + page);
        ssd1306_write_command(0x00);
        ssd1306_write_command(0x10);

        for(uint8_t col = 0; col < 128; col++)
        {
            ssd1306_write_data(buffer[page*128 + col]);
        }
    }
}

void ssd1306_clear(void)
{
    for(int i=0;i<1024;i++)
        buffer[i] = 0;
}

void ssd1306_draw_pixel(uint8_t x, uint8_t y)
{
    uint16_t index = x + (y/8)*128;
    buffer[index] |= (1<<(y%8));
}

void ssd1306_draw_hline(uint8_t y)
{
    for(uint8_t x=0;x<128;x++)
        ssd1306_draw_pixel(x,y);
}

void ssd1306_draw_vline(uint8_t x)
{
    for(uint8_t y=0;y<64;y++)
        ssd1306_draw_pixel(x,y);
}

void ssd1306_draw_grid(void)
{
    uint8_t cell_w = 128/5;
    uint8_t cell_h = 64/3;

    for(uint8_t i=0;i<=5;i++)
        ssd1306_draw_vline(i*cell_w);

    for(uint8_t j=0;j<=3;j++)
        ssd1306_draw_hline(j*cell_h);
}

void draw_pixel_big(uint8_t x, uint8_t y)
{
    ssd1306_draw_pixel(x,y);
    ssd1306_draw_pixel(x+1,y);
    ssd1306_draw_pixel(x,y+1);
    ssd1306_draw_pixel(x+1,y+1);
}

void draw_char_big(uint8_t x, uint8_t y, const uint8_t *font)
{
    for(int col=0; col<4; col++)
    {
        for(int row=0; row<5; row++)
        {
            if(font[row] & (1<<(3-col)))
                draw_pixel_big(x+col*2,y+row*2);
        }
    }
}

void draw_char_pos(uint8_t pos, char c)
{
    uint8_t cell_w = 128/5;
    uint8_t cell_h = 64/3;

    uint8_t row = pos/5;
    uint8_t col = pos%5;

    uint8_t x = col*cell_w + cell_w/2 - 4;
    uint8_t y = row*cell_h + cell_h/2 - 4;

    if(c=='R') draw_char_big(x,y,font_R);
    if(c=='G') draw_char_big(x,y,font_G);
    if(c=='B') draw_char_big(x,y,font_B);
}

void grid_clear(void)
{
    for(int i=0;i<15;i++)
        grid_state[i]=' ';
}

void grid_render(void)
{
    ssd1306_clear();

    ssd1306_draw_grid();

    for(int i=0;i<15;i++)
        if(grid_state[i]!=' ')
            draw_char_pos(i,grid_state[i]);

    ssd1306_update_screen();
}

void oled_uart_process(uint8_t data)
{
    uint8_t pos = data & 0x0F;
    uint8_t type = data >> 4;

    if(pos>14) return;

    if(type==0x4) grid_state[pos]='R';
    else if(type==0x5) grid_state[pos]='G';
    else if(type==0x8) grid_state[pos]='B';

    grid_render();
}


