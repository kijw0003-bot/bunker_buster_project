import pygame
import serial
import sys
import random
import time

# pygame 초기화
pygame.init()

# =========================
# UART 설정
# =========================
PORT = "COM6"
BAUD = 9600

try:
    ser = serial.Serial(PORT, BAUD, timeout=0.01)
    print(f"[UART] Connected: {PORT}, {BAUD}")
except Exception as e:
    print(f"[UART] UART open failed: {e}")
    ser = None

# =========================
# 화면 / 맵 설정
# =========================
COLS = 5
ROWS = 3
TOTAL_CELLS = COLS * ROWS

info = pygame.display.Info()
WIDTH = info.current_w
HEIGHT = info.current_h

screen = pygame.display.set_mode((WIDTH, HEIGHT), pygame.FULLSCREEN)
pygame.display.set_caption("Bunker Hint UI")

clock = pygame.time.Clock()

CELL_W = WIDTH // COLS
CELL_H = HEIGHT // ROWS

# =========================
# 색상 정의
# =========================
BLACK  = (0, 0, 0)
WHITE  = (255, 255, 255)
RED    = (255, 0, 0)
YELLOW = (255, 255, 0)
GREEN  = (0, 255, 0)
BLUE   = (0, 0, 255)

# =========================
# 폰트
# =========================
font_attack = pygame.font.SysFont("arial", 56, bold=True)

# =========================
# UART 상수
# =========================
FRAME_UPDATE = 0x7E
HIT_WIN      = 0x81
RESET_UI     = 0xDD

# =========================
# 상태 변수
# =========================
bunker_pos = None

target_pos = None
target_show = False
target_expire_time = 0.0

bunker_visible = False
bunker_expire_time = 0.0
show_bunker = True

show_aim = True
initial_hints_pending = False

bunker_revealed = False

hit_counts = [0] * TOTAL_CELLS

attack_pos = None
attack_visible = False
attack_expire_time = 0.0

hints = {}

pending_frame_update_after_draw = False
# =========================
# 테스트용 인덱스
# =========================
test_bunker_pos = 0
test_target_pos = 0

# =========================
# UART 송신 함수
# =========================
def uart_send(byte_val):
    if ser is not None and ser.is_open:
        ser.write(bytes([byte_val & 0xFF]))
        print(f"UART TX : 0x{byte_val:02X}")
    else:
        print(f"UART TX FAIL : 0x{byte_val:02X}")

def send_frame_update():
    uart_send(FRAME_UPDATE)

def send_bunker_hit():
    uart_send(HIT_WIN)

# =========================
# 전체 UI 리셋 함수
# =========================
def reset_ui_state():
    global bunker_pos
    global target_pos, target_show, target_expire_time
    global bunker_visible, bunker_expire_time
    global initial_hints_pending
    global bunker_revealed
    global hit_counts
    global attack_pos, attack_visible, attack_expire_time
    global hints
    global pending_frame_update_after_draw

    bunker_pos = None

    target_pos = None
    target_show = False
    target_expire_time = 0.0

    bunker_visible = False
    bunker_expire_time = 0.0

    initial_hints_pending = False
    bunker_revealed = False

    hit_counts = [0] * TOTAL_CELLS

    attack_pos = None
    attack_visible = False
    attack_expire_time = 0.0

    hints.clear()
    pending_frame_update_after_draw = False
    
# =========================
# 좌표 관련 함수
# =========================
def pos_to_xy(pos):
    x = pos % COLS
    y = pos // COLS
    return x, y

def xy_to_pos(x, y):
    return y * COLS + x

def cell_rect(x, y):
    return pygame.Rect(x * CELL_W, y * CELL_H, CELL_W, CELL_H)

def cell_center(x, y):
    cx = x * CELL_W + CELL_W // 2
    cy = y * CELL_H + CELL_H // 2
    return cx, cy

# =========================
# 거리 / 후보 함수
# =========================
def get_distance(pos_a, pos_b):
    ax, ay = pos_to_xy(pos_a)
    bx, by = pos_to_xy(pos_b)
    return abs(ax - bx) + abs(ay - by)

def get_cross_positions(center_pos):
    x, y = pos_to_xy(center_pos)

    offsets = [
        (0, 0),
        (0, -1),
        (0, 1),
        (-1, 0),
        (1, 0),
    ]

    positions = []
    for dx, dy in offsets:
        nx = x + dx
        ny = y + dy
        if 0 <= nx < COLS and 0 <= ny < ROWS:
            positions.append(xy_to_pos(nx, ny))

    return positions

def split_positions_by_distance(candidates, center_pos):
    near_positions = []
    far_positions = []

    for pos in candidates:
        if get_distance(pos, center_pos) <= 2:
            near_positions.append(pos)
        else:
            far_positions.append(pos)

    return near_positions, far_positions

def build_hint(pos, color):
    return {"pos": pos, "color": color}

def choose_hint_count_after_miss(max_count):
    r = random.random()

    if max_count <= 1:
        return 1
    if max_count == 2:
        return 1 if r < 0.60 else 2

    if r < 0.50:
        return 1
    elif r < 0.85:
        return 2
    else:
        return 3

# =========================
# 힌트 생성 함수
# =========================
def generate_initial_hints():
    global hints, bunker_pos

    hints.clear()

    if bunker_pos is None:
        return

    all_positions = list(range(TOTAL_CELLS))
    near_positions, far_positions = split_positions_by_distance(all_positions, bunker_pos)

    random.shuffle(near_positions)
    random.shuffle(far_positions)

    selected = []

    for _ in range(2):
        if near_positions:
            selected.append((near_positions.pop(), GREEN))

    for _ in range(1):
        if far_positions:
            selected.append((far_positions.pop(), BLUE))

    used_positions = {pos for pos, _ in selected}
    remain_candidates = [p for p in all_positions if p not in used_positions]
    random.shuffle(remain_candidates)

    while len(selected) < 3 and remain_candidates:
        pos = remain_candidates.pop()
        color = GREEN if get_distance(pos, bunker_pos) <= 2 else BLUE
        selected.append((pos, color))

    for pos, color in selected:
        hints[pos] = build_hint(pos, color)

def generate_hints_after_miss():
    global hints, bunker_pos, target_pos, bunker_revealed

    if bunker_pos is None or target_pos is None:
        return

    if bunker_revealed:
        return

    candidates = get_cross_positions(target_pos)
    if not candidates:
        return

    near_positions, far_positions = split_positions_by_distance(candidates, bunker_pos)

    random.shuffle(near_positions)
    random.shuffle(far_positions)

    hint_count = choose_hint_count_after_miss(len(candidates))
    selected = []

    if hint_count == 1:
        if random.random() < 0.80:
            desired_green, desired_blue = 1, 0
        else:
            desired_green, desired_blue = 0, 1
    elif hint_count == 2:
        if random.random() < 0.70:
            desired_green, desired_blue = 2, 0
        else:
            desired_green, desired_blue = 1, 1
    else:
        if random.random() < 0.40:
            desired_green, desired_blue = 3, 0
        else:
            desired_green, desired_blue = 2, 1

    for _ in range(desired_green):
        if near_positions:
            selected.append((near_positions.pop(), GREEN))

    for _ in range(desired_blue):
        if far_positions:
            selected.append((far_positions.pop(), BLUE))

    used_positions = {pos for pos, _ in selected}
    remain_candidates = [p for p in candidates if p not in used_positions]
    random.shuffle(remain_candidates)

    while len(selected) < hint_count and remain_candidates:
        pos = remain_candidates.pop()
        color = GREEN if get_distance(pos, bunker_pos) <= 2 else BLUE
        selected.append((pos, color))

    for pos, color in selected:
        hints[pos] = build_hint(pos, color)

# =========================
# 게임 처리 함수
# =========================
def can_attack_pos(pos):
    if not (0 <= pos < TOTAL_CELLS):
        return False

    if bunker_pos is None or pos != bunker_pos:
        return hit_counts[pos] < 2

    return hit_counts[pos] < 3

def on_receive_bunker(pos):
    global bunker_pos, bunker_visible, bunker_expire_time
    global target_pos, target_show
    global initial_hints_pending
    global bunker_revealed
    global hit_counts
    global attack_pos, attack_visible, attack_expire_time
    global pending_frame_update_after_draw

    print(f"[BUNKER] pos={pos}")

    bunker_pos = pos
    bunker_visible = True
    bunker_expire_time = time.time() + 3.0
    
    target_pos = None
    target_show = False

    initial_hints_pending = True
    bunker_revealed = False
    hit_counts = [0] * TOTAL_CELLS

    attack_pos = None
    attack_visible = False
    attack_expire_time = 0.0

    hints.clear()
    pending_frame_update_after_draw = False

def on_receive_target(pos):
    global target_pos, target_show, target_expire_time
    global bunker_pos, bunker_visible, bunker_revealed
    global hit_counts
    global attack_pos, attack_visible, attack_expire_time
    global initial_hints_pending

    print(f"[TARGET] pos={pos}")

    if not can_attack_pos(pos):
        print(f"[ATTACK BLOCKED] pos={pos}, hit_count={hit_counts[pos]}")
        return

    target_pos = pos
    target_show = True
    target_expire_time = time.time() + 5.0

    hit_counts[pos] += 1
    print(f"[HIT COUNT] pos={pos}, count={hit_counts[pos]}")

    if bunker_pos is not None and pos == bunker_pos:
        if hit_counts[pos] == 1:
            generate_hints_after_miss()
            send_frame_update()
            return

        if hit_counts[pos] == 2:
            bunker_revealed = True
            bunker_visible = True
            initial_hints_pending = False
            send_frame_update()
            return

        if hit_counts[pos] == 3:
            attack_pos = pos
            attack_visible = True
            attack_expire_time = time.time() + 2.0

            bunker_visible = False
            hints.clear()

            send_frame_update()
            #send_bunker_hit()
            return

    generate_hints_after_miss()
    send_frame_update()

def process_uart(byte_val):
    upper = (byte_val >> 4) & 0x0F
    lower = byte_val & 0x0F

    if byte_val == RESET_UI:
        reset_ui_state()
        send_frame_update()
        return

    if upper == 0x4 and 0 <= lower < TOTAL_CELLS:
        on_receive_bunker(lower)

    elif upper == 0xF and 0 <= lower < TOTAL_CELLS:
        on_receive_target(lower)

def poll_uart():
    if ser is None:
        return

    while ser.in_waiting > 0:
        data = ser.read(1)
        if data:
            print(f"UART RX : 0x{data[0]:02X}")
            process_uart(data[0])

# =========================
# 표시 시간 갱신
# =========================
def update_timers():
    global target_show, bunker_visible
    global initial_hints_pending
    global attack_visible, attack_pos
    global pending_frame_update_after_draw

    now = time.time()

    if target_show and now > target_expire_time:
        target_show = False

    if bunker_visible and now > bunker_expire_time:
        if not bunker_revealed:
            bunker_visible = False

        if initial_hints_pending:
            generate_initial_hints()
            initial_hints_pending = False
            pending_frame_update_after_draw = True

    if attack_visible and now > attack_expire_time:
        attack_visible = False
        attack_pos = None

# =========================
# 그리기 함수
# =========================
def draw_grid():
    for y in range(ROWS):
        for x in range(COLS):
            rect = cell_rect(x, y)
            pos = xy_to_pos(x, y)

            if show_aim and target_show and target_pos == pos:
                pygame.draw.rect(screen, YELLOW, rect, 6)
            else:
                pygame.draw.rect(screen, WHITE, rect, 3)

def draw_bunker():
    if bunker_pos is None:
        return
    if not bunker_visible:
        return
    if not show_bunker:
        return

    x, y = pos_to_xy(bunker_pos)
    cx, cy = cell_center(x, y)

    size = min(CELL_W, CELL_H) // 5
    rect = pygame.Rect(cx - size, cy - size, size * 2, size * 2)

    pygame.draw.rect(screen, RED, rect)

def draw_single_hint(hint):
    x, y = pos_to_xy(hint["pos"])
    cx, cy = cell_center(x, y)

    size = min(CELL_W, CELL_H) // 5
    rect = pygame.Rect(cx - size, cy - size, size * 2, size * 2)

    pygame.draw.rect(screen, hint["color"], rect)

def draw_hints():
    for hint in hints.values():
        draw_single_hint(hint)

def draw_attack():
    if not attack_visible or attack_pos is None:
        return

    x, y = pos_to_xy(attack_pos)
    rect = cell_rect(x, y)

    text = font_attack.render("ATTACK", True, YELLOW)
    text_rect = text.get_rect(center=rect.center)
    screen.blit(text, text_rect)

# =========================
# 메인 루프
# =========================
running = True

while running:
    clock.tick(60)

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

            elif event.key == pygame.K_v:
                show_bunker = not show_bunker
                send_frame_update()

            elif event.key == pygame.K_b:
                show_aim = not show_aim
                send_frame_update()

            elif event.key == pygame.K_1:
                test_byte = 0x40 | test_bunker_pos
                print(f"UART RX : 0x{test_byte:02X}")
                process_uart(test_byte)
                print(f"[TEST] bunker pos = {test_bunker_pos}")
                test_bunker_pos = (test_bunker_pos + 1) % TOTAL_CELLS

            elif event.key == pygame.K_2:
                test_byte = 0xF0 | test_target_pos
                print(f"UART RX : 0x{test_byte:02X}")
                process_uart(test_byte)
                print(f"[TEST] target pos = {test_target_pos}")
                test_target_pos = (test_target_pos + 1) % TOTAL_CELLS

            elif event.key == pygame.K_r:
                process_uart(0xDD)

    poll_uart()
    update_timers()

    screen.fill(BLACK)
    draw_hints()
    draw_bunker()
    draw_attack()
    draw_grid()

    pygame.display.flip()

    if pending_frame_update_after_draw:
        send_frame_update()
        pending_frame_update_after_draw = False
    
pygame.quit()
sys.exit()