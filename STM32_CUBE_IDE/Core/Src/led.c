#include "led.h"

void led_main(void);
extern void button_check(void);
extern volatile int TIM10_1ms_counter;  // ADD SIKWON
extern volatile int TIM10_1ms_ledcnt;   // ADD SIKWON

int func_index=-1;
// led_all_on : open source 방식
// LedAllOn() : MS
void led_all_on(void)
{
	  HAL_GPIO_WritePin(GPIOB, 0xff, 1);
//	  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3 |
//			  	  	  	  	   GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7, 1);
}

void led_all_off(void)
{
	  HAL_GPIO_WritePin(GPIOB, 0xff, 0);
//	  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3 |
//			  	  	  	  	   GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7, 0);
}

// 7 6 5 4 3 2 <- 1<-0
// 100ms주기로 위의 동작을 실행 (기존에 on 된 led는 off로 처리)
void led_up_on(void)
{
	static int i=0;

	if (TIM10_1ms_ledcnt >= 100)
	{
		TIM10_1ms_ledcnt=0;
		led_all_off();
		HAL_GPIO_WritePin(GPIOB, 0x01 << i, 1);
		i++;
		i %= 8;
	}
}

// 7-> 6-> 5 4 3 2 -> 1->0
// 100ms주기로 위의 동작을 실행 (기존에 on 된 led는 off로 처리)
void led_down_on(void)
{
	static int i=0;

#if 1
	if (TIM10_1ms_ledcnt >= 100)
	{
		TIM10_1ms_ledcnt=0;
		led_all_off();
		HAL_GPIO_WritePin(GPIOB, 0x80 >> i, 1);
		i++;
		i %= 8;
	}
#endif
#if 0
	for (int i=0; i < 8; i++)
	{
		led_all_off();
		HAL_GPIO_WritePin(GPIOB, 0x80 >> i, 1);
		HAL_Delay(100);
	}
	led_all_off();
	HAL_Delay(100);
#endif
}

void led_flower_on(void)
{
#if 1
	static int i=0;

	if (TIM10_1ms_counter >= 100)
	{
		TIM10_1ms_counter=0;
		HAL_GPIO_WritePin(GPIOB, 0x10 << i | 0x08 >> i, 1);
		i++;
		i %= 4;
	}
#else // org
	for (int i=0; i < 4; i++)
	{
		HAL_GPIO_WritePin(GPIOB, 0x10 << i | 0x08 >> i , 1);
		HAL_Delay(200);
	}
	led_all_off();
	HAL_Delay(200);
#endif
}

void led_flower_off(void)
{
#if 1
	static int i=0;

	if (TIM10_1ms_counter >= 100)
	{
		TIM10_1ms_counter=0;
		HAL_GPIO_WritePin(GPIOB, 0x10 << (3-i) | 0x08 >> (3-i) , 0);
		i++;
		i %= 4;
	}
#endif
#if 0
	led_all_on();
	HAL_Delay(200);
	for (int i=0; i < 4; i++)
	{
		HAL_GPIO_WritePin(GPIOB, 0x10 << (3-i) | 0x08 >> (3-i) , 0);
		HAL_Delay(200);
	}
#endif
}


// 7 6 5 4 3 2 <- 1<-0
// 100ms주기로 위의 동작을 실행 (기존에 on 된 led는 on로 처리)
void led_keepon_up(void)
{
	for (int i=0; i < 8; i++)  // or (int i=0; i <= 7; i++)
	{
		HAL_GPIO_WritePin(GPIOB, 0x01 << i, 1);
		HAL_Delay(100);
	}
	led_all_off();
	HAL_Delay(100);
}
// 7-> 6-> 5 4 3 2 -> 1->0
// 100ms주기로 위의 동작을 실행 (기존에 on 된 led는 on로 처리)
void led_keepon_down(void)
{
	for (int i=0; i < 8; i++)  // or (int i=0; i <= 7; i++)
	{
		HAL_GPIO_WritePin(GPIOB, 0x80 >> i, 1);
		HAL_Delay(100);
	}
	led_all_off();
	HAL_Delay(100);
}
/*
 *  1) timer INT를 활용 해서
 *
 */
void (*funcp[]) () =
{
	led_all_on,  //
	led_all_off,
	led_up_on,
	led_down_on,
	led_flower_on,
	led_flower_off
};

void led_main(void)
{

	while(1)
	{

		if (TIM10_1ms_counter >= 100)
		{
			TIM10_1ms_counter=0;
			//HAL_GPIO_TogglePin(LD2_GPIO_Port, LD2_Pin);
		}

		button_check();
#if 0
		if (func_index != -1)
			funcp[func_index]();
#else
		switch(func_index)
		{
		case 0:
			led_all_on();
			break;
		case 1:
			led_all_off();
			break;
		case 2:
			led_up_on();
			break;
		case 3:
			led_down_on();
			break;
		case 4:
			led_flower_on();
			break;
		case 5:
			led_flower_off();
			break;
		default:
			break;
		}
#endif
	}

}


//		led_all_on();
//		HAL_Delay(50);
//		led_all_off();
//		HAL_Delay(50);
//		led_up_on();
//		led_down_on();
//		led_keepon_up();
//		led_keepon_down();

