#include "buzzer.h"

void buzzer_on(void)
{
    HAL_GPIO_WritePin(BUZZER_GPIO_Port, BUZZER_Pin, GPIO_PIN_SET);
}

void buzzer_off(void)
{
    HAL_GPIO_WritePin(BUZZER_GPIO_Port, BUZZER_Pin, GPIO_PIN_RESET);
}

void buzzer_beep(uint32_t on_ms, uint32_t off_ms, uint32_t repeat)
{
    for (uint32_t i = 0; i < repeat; i++)
    {
        buzzer_on();
        HAL_Delay(on_ms);
        buzzer_off();

        if (i != repeat - 1)
        {
            HAL_Delay(off_ms);
        }
    }
}

// 위
void buzzer_up(void)
{
    buzzer_beep(8, 0, 1);
}

// 아래
void buzzer_down(void)
{
    buzzer_beep(8, 0, 1);
}

// 왼쪽
void buzzer_left(void)
{
    buzzer_beep(8, 0, 1);
}

// 오른쪽
void buzzer_right(void)
{
    buzzer_beep(8, 0, 1);
}

// 가운데
void buzzer_center(void)
{
    buzzer_beep(8, 0, 1);
}
