#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID     = "MHS-PNM";
const char* WIFI_PASSWORD = "akupoltek";
const char* API_HOST      = "http://192.168.1.9:8000";
const int   TABLE_ID      = 1;

#define RELAY_PIN 4
#define LED_PIN   2

bool relayState = false;
unsigned long lastPoll = 0;

void connectWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\nConnected: " + WiFi.localIP().toString());
}

void setRelay(bool on) {
  digitalWrite(RELAY_PIN, on ? LOW : HIGH);
  digitalWrite(LED_PIN, on ? HIGH : LOW);
  Serial.print("RELAY: ");
  Serial.print(on ? "ON" : "OFF");
  Serial.print(" | PIN4: ");
  Serial.println(digitalRead(RELAY_PIN));
}

void checkTableStatus() {
  HTTPClient http;
  String url = String(API_HOST) + "/api/table-status/" + TABLE_ID;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode == 200) {
    String payload = http.getString();
    Serial.println(payload);

    JsonDocument doc;
    deserializeJson(doc, payload);

    bool active = doc["active"].is<bool>() 
      ? doc["active"].as<bool>() 
      : (doc["active"].as<String>() == "true");

    if (active && !relayState) {
      setRelay(true);
      relayState = true;
    } else if (!active && relayState) {
      setRelay(false);
      relayState = false;
    }
  }
  http.end();
}

void setup() {
  Serial.begin(115200);

  digitalWrite(RELAY_PIN, HIGH); // OFF sebelum pinMode
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  connectWiFi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWiFi();

  if (millis() - lastPoll > 2000) {
    lastPoll = millis();
    checkTableStatus();
  }
}