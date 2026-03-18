/*
 * button.c
 *
 *  Created on: Jan 9, 2026
 *      Author: user
 */

#include "button.h"

unsigned char button_status[BUTTON_NUMBER] = {
	BUTTON_RELEASE,BUTTON_RELEASE,BUTTON_RELEASE,BUTTON_RELEASE,BUTTON_RELEASE
};

extern int func_index;
void button_check(void)
{
	// BUTTON0 을 눌렀다 떼면 아래를 차례로 실행
	// BUTTON0: led_all_on
    //          led_all_off
	//          led_up_on
	//          led_down_on
	//          led_flower_on
	//          led_flower_off
	if (get_button(GPIOC, GPIO_PIN_0 , BUTTON0 )  == BUTTON_PRESS)
	{
		func_index++;
		func_index %= 6;
	}
}

int get_button(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin, int button_number)
{
	int state;
	//   (1）ｂｕｔｔｏｎ을 읽고
	state = HAL_GPIO_ReadPin(GPIOx, GPIO_Pin);

	// （２） 눌렸는지   ｒｅｔｕｒｎ BUTTON_PRESS
	if (state == BUTTON_PRESS && button_status[button_number] == BUTTON_RELEASE)  // 처음 눌려진 상태 ?
	{
		HAL_Delay(20);  // 노이즈가 지나가기를 기다린다.
		button_status[button_number] = BUTTON_PRESS;   // 처음 눌려진 상태로 인정
		return BUTTON_RELEASE;   // 아직은 완전히 눌린 상태가 아닌다.
	}
	// （３） 떼었는지 확인  ｒｅｔｕｒｎ BUTTON_ＲＥＬＥＡＳＥ
	else if (state == BUTTON_RELEASE && button_status[button_number] == BUTTON_PRESS)
	{
		HAL_Delay(20);  // 노이즈가 지나가기를 기다린다.
		button_status[button_number] = BUTTON_RELEASE;   // 다음 버튼을 체크 하기 위해 초기화
		return BUTTON_PRESS;   // 완전히 1번 눌렀다 뗀것으로 인정
	}

	return BUTTON_RELEASE;   // 버튼이 idle 상태로 return

}
