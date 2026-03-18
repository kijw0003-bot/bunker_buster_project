#include "main.h"
#include "button.h"
#include "button_uart.h"
#include "buzzer.h"

extern UART_HandleTypeDef huart2;
extern volatile int shots_left;

void button_uart(void)
{
    uint8_t tx_data;

    if(get_button(GPIOC, GPIO_PIN_0, BUTTON0) == BUTTON_PRESS)
    {
        buzzer_up();
        tx_data = 0x10;   // UP
        HAL_UART_Transmit(&huart2, &tx_data, 1, 100);
    }

    if(get_button(GPIOC, GPIO_PIN_1, BUTTON1) == BUTTON_PRESS)
    {
    	buzzer_down();
        tx_data = 0x11;   // DOWN
        HAL_UART_Transmit(&huart2, &tx_data, 1, 100);
    }

    if(get_button(GPIOC, GPIO_PIN_2, BUTTON2) == BUTTON_PRESS)
    {
    	buzzer_center();
    	if(shots_left >= 0)
    	{
        tx_data = 0x12;   // CENTER
        HAL_UART_Transmit(&huart2, &tx_data, 1, 100);
        shots_left++;
    	}
    }

    if(get_button(GPIOC, GPIO_PIN_3, BUTTON3) == BUTTON_PRESS)
    {
    	buzzer_right();
        tx_data = 0x13;   // RIGHT
        HAL_UART_Transmit(&huart2, &tx_data, 1, 100);
    }

    if(get_button(GPIOB, GPIO_PIN_0, BUTTON4) == BUTTON_PRESS)
    {
    	buzzer_left();
        tx_data = 0x14;   // LEFT
        HAL_UART_Transmit(&huart2, &tx_data, 1, 100);
    }
}

