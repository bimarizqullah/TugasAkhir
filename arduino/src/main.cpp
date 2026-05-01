#include <Arduino.h>
#include <DMDESP.h>
#include <fonts/SystemFont5x7.h>

#define DISPLAYS_WIDE 1
#define DISPLAYS_HIGH 1

DMDESP dmd(DISPLAYS_WIDE, DISPLAYS_HIGH);

void setup() {
  Serial.begin(115200);
  Serial.println("START DMDESP CUSTOM PIN");

  dmd.start();
  dmd.selectFont(SystemFont5x7);

  dmd.clearScreen();
  dmd.drawText(1, 4, "OK");
}

void loop() {
}