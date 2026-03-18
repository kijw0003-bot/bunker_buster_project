#ifndef SSD1306_H
#define SSD1306_H

#include "main.h"

void ssd1306_init(void);
void ssd1306_update_screen(void);
void ssd1306_clear(void);

void ssd1306_draw_pixel(uint8_t x, uint8_t y);
void ssd1306_draw_grid(void);

void draw_char_pos(uint8_t pos, char c);

void grid_clear(void);
void grid_render(void);
void oled_uart_process(uint8_t data);

#endif
