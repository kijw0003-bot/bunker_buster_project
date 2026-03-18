#ifndef __BUZZER_H__
#define __BUZZER_H__

#include "main.h"

void buzzer_on(void);
void buzzer_off(void);
void buzzer_beep(uint32_t on_ms, uint32_t off_ms, uint32_t repeat);

void buzzer_up(void);
void buzzer_down(void);
void buzzer_left(void);
void buzzer_right(void);
void buzzer_center(void);

#endif
