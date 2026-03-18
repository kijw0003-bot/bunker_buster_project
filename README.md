# 📦 Automatic Bunker Detection System - Requirements

## 1. Overview

본 프로젝트는 FPGA, STM32, Python 기반 UI를 활용한 자동화 벙커 탐색 시스템입니다.
각 구성 요소는 UART 통신을 통해 연동됩니다.

---

## 2. System Architecture

* FPGA (Vivado, SystemVerilog)
* STM32 (STM32CubeIDE)
* Python UI (Pygame 기반 시각화 + Serial 통신)

---

## 3. Development Environment

### 3.1 OS

* Windows 10 / 11 (권장)

---

### 3.2 FPGA Environment

* Xilinx Vivado (권장: 2020.2 이상)
* 지원 보드: (사용한 FPGA 보드 명시)

---

### 3.3 Firmware (STM32)

* STM32CubeIDE
* MCU: (사용한 MCU 모델 : STM32F411RE)

---

### 3.4 Python Environment

* Python 3.10 이상

#### Required Python Packages

```bash
pip install pygame pyserial numpy
```

---

## 4. Python Dependencies

| Package  | Description |
| -------- | ----------- |
| pygame   | UI 및 시각화    |
| pyserial | UART 통신     |
| numpy    | 데이터 처리      |

---

## 5. Hardware Requirements

* FPGA Board (Xilinx)
* STM32 Board
* USB-UART 연결 (2개 포트 사용)

  * FPGA 연결 포트
  * STM32 연결 포트

---

## 6. Configuration

Python 코드 내 포트 설정 필요:

```python
PORT_FPGA = 'COM4'
PORT_STM32 = 'COM12'
```

※ 사용자 환경에 맞게 수정

---

## 7. Execution Steps

### 1. FPGA Bitstream 업로드

Vivado에서 Bitstream 생성 후 FPGA에 업로드

### 2. STM32 Firmware 업로드

STM32CubeIDE에서 빌드 후 보드에 업로드

### 3. Python 실행

```bash
python hint_monitor_3x5.py
```

---

## 8. Notes

* assets 폴더 (이미지, 사운드)는 반드시 포함되어야 함
* UART 통신 속도는 9600bps 기준
* 포트 충돌 시 프로그램 실행 불가

---

## 9. Optional (권장)

가상환경 사용:

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```
