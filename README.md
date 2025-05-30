# 🌡️ DHT11 Monitoring System

A complete sensor-based system to monitor **temperature and humidity** using the **DHT11 sensor** and trigger a **relay** when thresholds are exceeded. This project was built for the **Sensor-Based Systems (STTHK3113)** midterm assessment.

🔗 [Watch the YouTube Demo](https://youtu.be/iIOcbnN08EQ?si=hfrz_KdSRWov1YgA)

---

## 🧠 Background

Environmental monitoring systems are crucial in various settings—from smart homes to industrial automation—to ensure safe conditions and optimal performance. This project aims to simulate a basic Internet of Things (IoT) setup using the **ESP32 microcontroller** with a **DHT11 temperature and humidity sensor**, a **relay**, and an optional **OLED display**. 

The ESP32 sends sensor data every 10 seconds to a backend server, which then stores it in a SQL database. If predefined thresholds (e.g., temperature > 26°C or humidity > 70%) are exceeded, a relay is triggered to activate an alert mechanism like a fan or buzzer. A mobile application, built with Flutter, retrieves the data and displays it in near real-time graphs—helping users visualize and respond to changing environmental conditions.

---

## ✅ Features

- Periodic sensor data logging every 10 seconds
- Relay activation based on user-defined thresholds
- Real-time data visualization via mobile app
- Backend API integration and SQL data storage
- Optional OLED display for local output

---

## 🏗️ System Architecture

```
[DHT11 Sensor] ──┐
[OLED Display] ──┤──> [ESP32 Microcontroller] <──> [Relay Module]
                 │
                 └──> [Backend API Server] <──> [Flutter Mobile App]
```

---

## ⚙️ Setup Instructions

### 🧰 Hardware Pin Configuration

| Component     | VCC | GND | Data/SDA/SCL/IN | GPIO Pin  |
|---------------|-----|-----|------------------|-----------|
| DHT11         | 3.3V| GND | Data             | GPIO4     |
| OLED Display  | 3.3V| GND | SDA/SCL          | GPIO21/22 |
| Relay Module  | 3.3V| GND | IN               | GPIO25    |

### 🧪 Software Steps

1. Flash ESP32 with Arduino code to send sensor data via Wi-Fi
2. Host a backend using CPanel, PHP MyAdmin
3. Store incoming data in a MySQL database
4. Build and run the mobile app using Flutter

---

## 🖼️ Screenshots

### Backend

*(Insert screenshot here)*

### Relay Module

*(Insert screenshot here)*

### Mobile App (Flutter)

*(Insert screenshot here)*

---

## 🛠️ Challenges & Solutions

### ❌ Challenges:
- Delay in data transmission between microcontroller and app
- App showing stale data when offline
- Inconsistent chart rendering

### ✅ Solutions:
- Optimized data frequency and Flutter’s data handling
- Implemented periodic update checks and fallback messages
- Added parsing, pagination, and lazy loading for responsiveness

---

## 🚀 Future Improvements

- Real-time alerts for unsafe readings
- User roles (admin, technician, viewer)
- WebSocket-based live data instead of HTTP polling
- HTTPS for secure communication
- Upgrade to DHT22 for better sensor accuracy
- CSV/Excel export feature for historical logs

