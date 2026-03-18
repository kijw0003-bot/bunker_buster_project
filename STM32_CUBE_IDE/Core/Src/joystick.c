#include "joystick.h"
#include "button.h"
#include <stdlib.h>
#include "buzzer.h"

//1wire
//#define JOY_CENTER_X 3130
//#define JOY_CENTER_Y 2870
//#define DEADZONE_X   300
//#define DEADZONE_Y   300
//#define MOVE_X       900
//#define MOVE_Y       900

//2wire
//#define JOY_CENTER_X 2025
//#define JOY_CENTER_Y 2050
//#define DEADZONE_X   250
//#define DEADZONE_Y   250
//#define MOVE_X       900
//#define MOVE_Y       900

#define JOY_CENTER_X 2055
#define JOY_CENTER_Y 2050
#define DEADZONE_X   400
#define DEADZONE_Y   400
#define MOVE_X       1200
#define MOVE_Y       1200

extern UART_HandleTypeDef huart2;

enum {
	CENTER,
	UP,
	DOWN,
	LEFT,
	RIGHT
};

static int prev_state = CENTER;

//int get_joystick_state(uint32_t x, uint32_t y)
//{
//
//	if(x > 1800 && x < 2300 &&
//	   y > 1800 && y < 2300)
//	{
//		return CENTER;
//	}
//
//	if(x < 1000) return LEFT;
//	if(x > 3000) return RIGHT;
//
//	if(y < 1000) return DOWN;
//	if(y > 3000) return UP;
//
//	return CENTER;
//
//}

//int get_joystick_state(uint32_t x, uint32_t y)
//{
//	int dx = x - JOY_CENTER;
//	int dy = y - JOY_CENTER;
//
//	if(abs(dx) < DEADZONE && abs(dy) < DEADZONE)
//		return CENTER;
//
//	if(abs(dx) > abs(dy))
//	{
//		if(dx > MOVE) return RIGHT;
//		if(dx < -MOVE) return LEFT;
//
//	}
//	else
//	{
//		if(dy > MOVE) return UP;
//		if(dy < -MOVE) return DOWN;
//	}
//
//	return CENTER;
//
//}

int get_joystick_state(uint32_t x, uint32_t y)
{
	int dx = (int)x - JOY_CENTER_X;
	int dy = (int)y - JOY_CENTER_Y;

    if (abs(dx) < DEADZONE_X && abs(dy) < DEADZONE_Y)
        return CENTER;

    if (abs(dx) > abs(dy))
    {
        if (dx > MOVE_X) return RIGHT;
        if (dx <  -MOVE_X) return LEFT;
    }
    else
    {
        if (dy > MOVE_Y) return UP;
        if (dy < -MOVE_Y) return DOWN;
    }

    return CENTER;
}

void joystick_check(uint32_t x, uint32_t y)
{

    int state;
    uint8_t tx_data;

    //
    static uint32_t last_tick = 0;

    if (HAL_GetTick() - last_tick < 100)
    	return;

    state = get_joystick_state(x, y);

    if(state != prev_state)
    {
        prev_state = state;

        if(state == CENTER)
        {
        	//printf("(CENTER)x:%d,y:%d\n",x,y);
            return;
        }
        switch(state)
        {

        case LEFT:
            buzzer_left();
            tx_data = 0x14;
            //printf("(LEFT)x:%d,y:%d\n",x,y);
            break;

        case RIGHT:
            buzzer_right();
            tx_data = 0x13;
            //printf("(RIGHT)x:%d,y:%d\n",x,y);
            break;

        case UP:
            buzzer_up();
            tx_data = 0x11;
            //printf("(UP)x:%d,y:%d\n",x,y);
            break;

        case DOWN:
            buzzer_down();
            tx_data = 0x10;
            //printf("(DOWN)x:%d,y:%d\n",x,y);
            break;
        }

        HAL_UART_Transmit(&huart2, &tx_data, 1, 10);

        //
        last_tick = HAL_GetTick();
    }
}
