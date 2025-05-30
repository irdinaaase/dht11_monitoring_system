  /* =================================================================

  📌 Objective
      To develop a sensor-based monitoring system that:
      •	Captures temperature and humidity data every 10 seconds
      •	Stores the data in a SQL relational database
      •	Activates a relay if thresholds (user can set) are exceeded
      •	Displays real-time readings in a graph on a mobile/web app  

  🧰 System Requirements
      1. Hardware
        Use the following components:
          •	ESP32 (main controller)
          •	DHT11 Sensor (for temperature and humidity)
          •	Relay (to trigger fan/alarm if limits exceeded)
          •	OLED Display (optional, to show live values)
      2. Backend
        Choose one backend:
          •	PHP, Flask, or NodeJS
          •	Database: MySQL or PostgreSQL
        Backend Functions:
          •	Accept sensor data every 10 seconds via API
          •	Store data with timestamp
          •	Provide endpoint to fetch data for graphing
      3. Mobile/Web App
        Build a simple app using Flutter or React Native that:
          •	Fetches temperature and humidity data from backend
          •	Displays values in a graph/chart
            o	Use packages like fl_chart, syncfusion_flutter_charts, or equivalent
          •	Optional: Display latest value or status message (e.g., “Alert: High Temp!”)

  ⚙️ System Behaviour
      •	Data Interval: Every 10 seconds, ESP32 sends:
        o	Temperature (°C)
        o	Humidity (%)
        o	Timestamp
      •	Relay Trigger (user able to configure): Activated when:
        o	Temperature > i.e 26°C OR
        o	Humidity > 70%
      •	App graph must reflect these values clearly

  ====================================================================*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>

// Hardware Configuration
#define DHTPIN 4          // DHT11 Sensor connected to GPIO4
#define DHTTYPE DHT11     // DHT11 sensor type
#define RELAYPIN 25       // Relay connected to GPIO25
#define SCREEN_WIDTH 128  // OLED display width
#define SCREEN_HEIGHT 32  // OLED display height
#define OLED_RESET -1     // Reset pin

// System Configuration
const char* device_id = "001"; 
const char* ssid = "Bullet Chicken";
const char* password = "vagabond";
const char* dataServer = "http://humancc.site/irdinabalqis/relay_monitoring_system/relay_data/insert_data.php";
const char* thresholdServer = "http://humancc.site/irdinabalqis/relay_monitoring_system/threshold_data/load_threshold.php";

// Timing Configuration
const long MAIN_INTERVAL = 10000;        // 10 second main cycle
const long THRESHOLD_CHECK_INTERVAL = 30000; // 30 seconds for threshold checks
const long DISPLAY_UPDATE_INTERVAL = 2000;   // 2 seconds per display page

// Threshold Configuration
float tempThreshold = 26.0;    // Default values
float humThreshold = 70.0;     // Default values
bool thresholdsUpdated = false;
bool alertActive = false;

// System Objects
DHT dht(DHTPIN, DHTTYPE);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Display Management
int currentPage = 0;
unsigned long lastMainCycle = 0;
unsigned long lastThresholdCheck = 0;
unsigned long lastPageChange = 0;
static unsigned long updateTime = 0;  // For tracking threshold updates

void setup() {
  Serial.begin(115200);
  
  // Initialize hardware
  pinMode(RELAYPIN, OUTPUT);
  digitalWrite(RELAYPIN, LOW);
  dht.begin();
  
  // Initialize OLED
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED initialization failed!");
    while(1);
  }
  Serial.println("OLED initialized");
  
  // Show startup screen
  displayStartup();
  
  // Connect to WiFi
  connectToWiFi();
  
  // Initial threshold check
  checkThresholdUpdates();
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Main 10-second cycle
  if (currentMillis - lastMainCycle >= MAIN_INTERVAL) {
    lastMainCycle = currentMillis;
    executeMainCycle();
  }
  
  // Check for threshold updates periodically
  if (currentMillis - lastThresholdCheck >= THRESHOLD_CHECK_INTERVAL) {
    lastThresholdCheck = currentMillis;
    checkThresholdUpdates();
  }
  
  // Update display pages
  updateDisplayManagement();
}

void displayStartup() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("System Starting...");
  display.display();
  delay(1000);
  display.clearDisplay();
  display.display();
}

void connectToWiFi() {
  WiFi.begin(ssid, password);
  display.clearDisplay();
  display.setCursor(0,0);
  display.print("Connecting to WiFi");
  display.display();
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    display.print(".");
    display.display();
  }
  
  display.clearDisplay();
  display.setCursor(0,0);
  display.println("WiFi connected!");
  display.printf("IP: %s", WiFi.localIP().toString().c_str());
  display.display();
  delay(2000);
}

void executeMainCycle() {
  // Read sensors
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  if (isnan(humidity) || isnan(temperature)) {
    displayError("Sensor Error");
    return;
  }
  
  // Check thresholds and control relay
  bool thresholdExceeded = checkThresholds(temperature, humidity);
  digitalWrite(RELAYPIN, thresholdExceeded ? HIGH : LOW);
  
  // Manage alerts
  manageAlerts(temperature, humidity, thresholdExceeded);
  
  // Send data to server if connected
  if (WiFi.status() == WL_CONNECTED) {
    sendSensorData(temperature, humidity);
  }
  
  // Log to serial
  Serial.printf("[%s] Temp: %.1f°C Hum: %.1f%% %s\n", 
              device_id, temperature, humidity,
              thresholdExceeded ? "ALERT" : "Normal");
}

bool checkThresholds(float temp, float hum) {
  return (temp > tempThreshold || hum > humThreshold);
}

void manageAlerts(float temp, float hum, bool exceeded) {
  if (exceeded && !alertActive) {
    showAlert(temp, hum);
    alertActive = true;
  } 
  else if (!exceeded && alertActive) {
    clearAlert();
    alertActive = false;
  }
}

void updateDisplayManagement() {
  unsigned long currentMillis = millis();
  
  // Rotate display pages every 2 seconds
  if (currentMillis - lastPageChange >= DISPLAY_UPDATE_INTERVAL) {
    currentPage = (currentPage + 1) % 2;
    lastPageChange = currentMillis;
    updateDisplayContent();
  }
}

void updateDisplayContent() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  bool thresholdExceeded = checkThresholds(temperature, humidity);
  
  display.clearDisplay();
  
  // Show "UPDATED" indicator if thresholds were recently updated
  if (thresholdsUpdated && (millis() - updateTime < 5000)) {
    display.setTextSize(1);
    display.setCursor(80, 0);
    display.print("UPDATED");
  } else {
    thresholdsUpdated = false;
  }
  
  // Page 0: Values display
  if (currentPage == 0) {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("Temp:");
    display.setCursor(0, 10);
    display.printf("%.1f/%.1fC", temperature, tempThreshold);
    
    display.setCursor(64, 0);
    display.print("Hum:");
    display.setCursor(64, 10);
    display.printf("%.1f/%.1f%%", humidity, humThreshold);
  }
  // Page 1: Status display
  else {
    display.setTextSize(1);
    display.setCursor(0, 0);
    if (thresholdExceeded) {
      display.print("ALERT: ");
      display.print(temperature > tempThreshold ? "HIGH TEMP" : "HIGH HUM");
    } else {
      display.print("Status: Normal");
    }
    
    display.setCursor(0, 10);
    display.print("Relay: ");
    display.print(digitalRead(RELAYPIN) ? "ON" : "OFF");
    
    display.setCursor(0, 20);
    display.printf("Thresh: T>%.0f H>%.0f", tempThreshold, humThreshold);
  }
  
  display.display();
}

void checkThresholdUpdates() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot check thresholds - WiFi disconnected");
    return;
  }
  
  HTTPClient http;
  http.begin(thresholdServer);
  int httpCode = http.GET();
  
  if (httpCode == HTTP_CODE_OK) {
    String payload = http.getString();
    DynamicJsonDocument doc(256);
    DeserializationError error = deserializeJson(doc, payload);
    
    if (!error && doc["status"] == "success") {
      float newTemp = doc["temp_threshold"];
      float newHum = doc["hum_threshold"];
      
      if (newTemp != tempThreshold || newHum != humThreshold) {
        tempThreshold = newTemp;
        humThreshold = newHum;
        thresholdsUpdated = true;
        updateTime = millis();
        
        Serial.printf("Thresholds updated - Temp: %.1f°C, Hum: %.1f%%\n", 
                     tempThreshold, humThreshold);
      }
    } else {
      Serial.println("Failed to parse threshold data");
    }
  } else {
    Serial.printf("Threshold update failed, HTTP code: %d\n", httpCode);
  }
  http.end();
}

void sendSensorData(float temp, float hum) {
  HTTPClient http;
  String url = String(dataServer) + 
              "?device_id=" + String(device_id) +
              "&temp=" + String(temp) +
              "&hum=" + String(hum) +
              "&relay_status=" + String(digitalRead(RELAYPIN));
  
  http.begin(url);
  int httpCode = http.GET();
  if (httpCode > 0) {
    Serial.printf("Data sent - Response: %d\n", httpCode);
  }
  http.end();
}

void showAlert(float temp, float hum) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(10, 0);
  display.print("! ALERT !");
  
  display.setCursor(0, 10);
  if (temp > tempThreshold) {
    display.printf("Temp: %.1f > %.1f", temp, tempThreshold);
  }
  
  display.setCursor(0, 20);
  if (hum > humThreshold) {
    display.printf("Hum: %.1f > %.1f", hum, humThreshold);
  }
  
  display.display();
}

void clearAlert() {
  display.clearDisplay();
  display.display();
}

void displayError(const char* message) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0,0);
  display.print("ERROR:");
  display.setCursor(0,10);
  display.print(message);
  display.display();
}