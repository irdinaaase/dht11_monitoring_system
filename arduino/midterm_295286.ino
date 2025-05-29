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

  // Hardware Configuration
  #define DHTPIN 4          // DHT11 Sensor connected to GPIO4
  #define DHTTYPE DHT11     // DHT11 sensor type
  #define RELAYPIN 25       // Relay connected to GPIO25
  #define SCREEN_WIDTH 128  // OLED display width
  #define SCREEN_HEIGHT 32 // OLED display height
  #define OLED_RESET -1     // Reset pin

  // System Configuration
  const char* device_id = "001"; // Simple numeric device ID
  const char* ssid = "Bullet Chicken";
  const char* password = "vagabond";
  const char* serverName = "http://humancc.site/irdinabalqis/relay_monitoring_system/insert_data.php";

  // Threshold Configuration (user-configurable)
  float tempThreshold = 26.0;    // Default temperature threshold (°C)
  float humThreshold = 70.0;     // Default humidity threshold (%)

  // Objects
  DHT dht(DHTPIN, DHTTYPE);
  Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
  bool alertActive = false;
  
  int currentPage = 0;
  unsigned long lastPageChange = 0;
  const int pageDelay = 2000; // 2 seconds per page

  void setup() {
    Serial.begin(115200);
    
    // Initialize hardware
    pinMode(RELAYPIN, OUTPUT);
    digitalWrite(RELAYPIN, LOW);
    dht.begin();
    
    // Initialize OLED
    if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
      Serial.println("OLED init failed - check wiring!");
      while(1); // Halt if display fails
    }
    Serial.println("OLED initialized");
    
    // Show startup screen
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0,0);
    display.println("System Starting...");
    display.display();
    delay(1000);

    display.clearDisplay();
    display.display();
    
    // Connect to WiFi
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      Serial.print(".");
    }
    Serial.println("\nWiFi connected");
  }

  void loop() {
      static unsigned long lastSendTime = 0;
      static float temperature = 0;
      static float humidity = 0;
      static bool thresholdExceeded = false;
      
      if (millis() - lastSendTime >= 10000) { // 10 second interval
        lastSendTime = millis();
        
        // Read sensors
        humidity = dht.readHumidity();
        temperature = dht.readTemperature();
        
        if (isnan(humidity) || isnan(temperature)) {
          Serial.println("Sensor error");
          return;
        }
        
        // Check thresholds
        thresholdExceeded = (temperature > tempThreshold || humidity > humThreshold);
        digitalWrite(RELAYPIN, thresholdExceeded ? HIGH : LOW);
        
        // OLED Alert Handling
        if (thresholdExceeded && !alertActive) {
          showAlert(temperature, humidity);
          alertActive = true;
        } 
        else if (!thresholdExceeded && alertActive) {
          clearAlert();
          alertActive = false;
        }
        
        // Send data to server
        if (WiFi.status() == WL_CONNECTED) {
          sendSensorData(temperature, humidity);
        }
        
        // Serial monitor output
        Serial.printf("[%s] Temp: %.1fC Hum: %.1f%% %s\n", 
                    device_id, temperature, humidity,
                    thresholdExceeded ? "ALERT" : "Normal");
      }

      // Update display with current readings
      updateDisplay(temperature, humidity, thresholdExceeded);
  }

  void updateDisplay(float temp, float hum, bool alert) {
      unsigned long currentTime = millis();
      
      // Change page every pageDelay milliseconds
      if (currentTime - lastPageChange >= pageDelay) {
          currentPage = (currentPage + 1) % 2; // Switch between 0 and 1
          lastPageChange = currentTime;
      }
      
      display.clearDisplay();
      
      // Page 0: Show temperature and humidity
      if (currentPage == 0) {
          display.setTextSize(1); // Reduced text size for 32px height
          display.setCursor(0, 0);
          display.print("Temp:");
          display.setCursor(0, 10);
          display.printf("%.1f C", temp);
          
          display.setCursor(64, 0);
          display.print("Hum:");
          display.setCursor(64, 10);
          display.printf("%.1f %%", hum);
      }
      // Page 1: Show status and relay state
      else {
          display.setTextSize(1);
          display.setCursor(0, 0);
          if (alert) {
              display.print("ALERT: ");
              display.print(temp > tempThreshold ? "HIGH TEMP" : "HIGH HUM");
          } else {
              display.print("Status: Normal");
          }
          
          display.setCursor(0, 10);
          display.print("Relay: ");
          display.print(digitalRead(RELAYPIN) ? "ON" : "OFF");
          
          // Add threshold info
          display.setCursor(0, 20);
          display.printf("Thresh: T>%.0f H>%.0f", tempThreshold, humThreshold);
      }
      
      display.display();
  }

  void displayError(const char* message) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(0,0);
    display.print("ERROR:");
    display.setTextSize(2);
    display.setCursor(0,20);
    display.print(message);
    display.display();
  }

  // Function to send sensor data to server
  void sendSensorData(float temp, float hum) {
    HTTPClient http;
    String url = String(serverName) + 
                "?device_id=" + String(device_id) +
                "&temp=" + String(temp) +
                "&hum=" + String(hum) +
                "&relay_status=" + String(digitalRead(RELAYPIN));
    
    http.begin(url);
    int httpCode = http.GET();
    if (httpCode > 0) {
      Serial.printf("Server response: %d\n", httpCode);
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
          display.printf("Temp: %.1fC", temp);
      }
      if (hum > humThreshold) {
          if (temp > tempThreshold) display.print(" ");
          display.printf("Hum: %.1f%%", hum);
      }
      
      display.setCursor(0, 20);
      display.print("Relay: ");
      display.print(digitalRead(RELAYPIN) ? "ACTIVE" : "OFF");
      display.display();
  }

  void clearAlert() {
    display.clearDisplay();
    display.display();
  }
