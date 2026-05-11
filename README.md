# 🏢 STM32 Smart Elevator System

> A fully embedded smart elevator system built with the **STM32F103C8T6 Blue Pill** microcontroller and programmed entirely in **ARM Assembly language**.

This project simulates a real-world multi-floor elevator with intelligent floor scheduling, RFID security access, Bluetooth control, voice announcements, overload protection, LCD feedback, and automated door control — all implemented from bare metal with no HAL libraries.

---

## 📋 Table of Contents

- [Features](#-features)
- [Hardware Used](#-hardware-used)
- [Hardware Connections](#-hardware-connections)
- [Software Requirements](#-software-requirements)
- [Build & Flash](#-build--flash)
- [How It Works](#-how-it-works)
  - [RFID Authentication](#rfid-authentication)
  - [Smart Call Handling](#smart-call-handling)
  - [Safety Features](#safety-features)
  - [LCD States](#lcd-states)
  - [Audio System](#audio-system)
- [Embedded Systems Concepts](#-embedded-systems-concepts)

---

## ✨ Features

| Category | Details |
|---|---|
| 🧠 Intelligence | Smart call handling, direction-aware request interception, multi-floor request queue |
| 🔐 Security | RFID-secured keypad access |
| 📱 Control | Bluetooth mobile control, matrix keypad floor selection |
| 🔊 Feedback | Voice announcements (DFPlayer Mini), 16x2 I2C LCD display |
| ⚙️ Motion | Stepper motor elevator control, servo-driven automatic doors |
| 🛡️ Safety | Overweight detection (HX711 + load cell), emergency stop switch, IR obstacle sensor |
| 💻 Implementation | Pure ARM Assembly, software I2C, software SPI, polling-based architecture |

---

## 🔧 Hardware Used

| Component | Purpose |
|---|---|
| STM32F103C8T6 Blue Pill | Main microcontroller |
| Stepper Motor | Elevator movement |
| Servo Motors | Door mechanisms |
| MFRC522 RFID Module | Access control |
| HX711 + Load Cell | Weight sensing |
| DFPlayer Mini | Audio announcements |
| Bluetooth Module | Mobile app communication |
| 16x2 I2C LCD | Status display |
| Matrix Keypad | Floor selection |
| Buzzer | Safety alarm |
| Stop Switch | Emergency stop |
| IR Sensor | Obstacle detection |

---

## 🔌 Hardware Connections

| Component | GPIO Pin |
|---|---|
| Step Pulse | PA0 |
| Step Direction | PA1 |
| Step Enable | PA2 |
| Floor Button 0 | PA8 |
| Floor Button 1 | PA5 |
| Floor Button 2 | PA7 |
| Emergency Stop | PA15 |
| HX711 DOUT | PC13 |
| HX711 SCK | PC14 |
| Servo Floor 0 | PA6 |
| Servo Floor 1 | PA11 |
| Servo Floor 2 | PB0 |
| DFPlayer Mini | PB10 |
| LCD SCL | PB6 |
| LCD SDA | PB7 |
| RFID NSS | PB1 |
| RFID RST | PB4 |
| RFID MOSI | PB5 |
| RFID SCK | PA3 |
| RFID MISO | PA4 |

---

## 💾 Software Requirements

- [Keil µVision](https://www.keil.com/download/product/)
- ST-Link V2 driver
- ARM Compiler (bundled with Keil)

---

## 🚀 Build & Flash

**1. Open the Project**
```
Open the project folder in Keil µVision.
```

**2. Build**
```
Project → Build Target  (or press F7)
```

**3. Connect Hardware**
```
Connect STM32 Blue Pill to PC via ST-Link V2.
```

**4. Flash Firmware**

Using Keil Flash Tool:
```
Flash → Download  (or press F8)
```

Using STM32CubeProgrammer:
```
Open the generated .hex file and click Download.
```

---

## ⚙️ How It Works

### RFID Authentication

The keypad is **locked by default**. To use floor selection, the user must authenticate first.

```
Scan RFID card
    │
    ├─ ✅ Granted → LCD: "Access Granted" + audio confirmation
    │              → Keypad unlocked for ONE floor command
    │              → Keypad auto-locks after entry
    │
    └─ ❌ Denied  → LCD: "Access Denied" + audio warning
```

---

### Smart Call Handling

The elevator dynamically intercepts in-path floor requests while moving — similar to a real-world elevator controller.

**Example scenario:**

```
Elevator moving:  Floor 0 ──────────────────► Floor 2
                               ↑
                         Floor 1 requested
                               │
                         System detects Floor 1
                         is along the path
                               │
                         Elevator stops at Floor 1 ✅
                               │
                         Continues to Floor 2 ✅
```

**Benefits:**
- ⏱️ Reduced waiting time
- ⚡ Better energy efficiency
- 🏢 Realistic elevator behavior

---

### Safety Features

#### ⚖️ Overweight Protection
The HX711 continuously monitors cabin weight. If the threshold is exceeded:
1. Elevator motion stops immediately
2. All pending requests are cleared
3. Buzzer alarm activates

#### 🛑 Emergency Stop
The physical stop switch immediately:
1. Halts all motion
2. Disables the stepper motor driver
3. Clears the request queue

> System resumes only after a new valid floor command is issued.

---

### LCD States

| Display | Meaning |
|---|---|
| `Floor: X` | Current floor number |
| `Moving Up` | Ascending to target |
| `Moving Down` | Descending to target |
| `Access Granted` | Valid RFID scan |
| `Access Denied` | Invalid RFID scan |

---

### Audio System

The **DFPlayer Mini** module handles all audio playback:

- 🔢 Floor arrival announcements
- ⬆️⬇️ Direction announcements
- ✅ Access granted / ❌ Access denied prompts

---

## 🧩 Embedded Systems Concepts

### GPIO Register Programming
Direct STM32 register manipulation — **zero HAL library usage**. All peripherals (GPIO, stepper, LCD, keypad) are controlled through raw memory-mapped register writes.

### Software I²C
The 16x2 LCD driver is implemented via **GPIO bit-banging**, manually toggling SDA/SCL lines to emulate the I²C protocol in software.

### Software SPI
The MFRC522 RFID module communicates through a **manually implemented SPI driver**, handling clock, chip select, and data lines in pure Assembly.

### Polling-Based Architecture
The system uses a **continuous polling loop** instead of interrupt-driven I/O. The main loop cyclically checks:

```
┌─────────────────────────────────────┐
│           Main Loop                 │
│                                     │
│  ┌────────┐  ┌─────────┐            │
│  │  RFID  │  │Bluetooth│            │
│  └────────┘  └─────────┘            │
│  ┌────────┐  ┌─────────┐            │
│  │Keypad  │  │ Buttons │            │
│  └────────┘  └─────────┘            │
│  ┌────────────────────────┐         │
│  │   Safety Sensors       │         │
│  │ (Weight / IR / Stop)   │         │
│  └────────────────────────┘         │
│  ┌────────────────────────┐         │
│  │    Motion Updates      │         │
│  └────────────────────────┘         │
└─────────────────────────────────────┘
```

This approach provides **responsive real-time behavior** without requiring NVIC interrupt configuration.

---



<p align="center">Built with ❤️ in ARM Assembly on STM32</p>
