/*
 * timer.c
 *
 *  Created on: Jan 12, 2026
 *      Author: user
 */
#include "timer.h"

extern TIM_HandleTypeDef htim2;
// us_delay(10);
void delay_us(unsigned int us);

#if 1
void delay_us(unsigned int us)
{
	// (1) 현재 counter값을 clear
	__HAL_TIM_SET_COUNTER(&htim2, 0);   // timer2의 counter를 clear
	// (2) 매개변수에서 지정한 us만큼 기다린다.
 	while (__HAL_TIM_GET_COUNTER(&htim2) < us)
		;   // NOP (no operation)
}

#endif
