#include <WiFi.h>

// PIN DEFINES (sama)
#define P10_DR   13
#define P10_CLK  27
#define P10_LAT  14
#define P10_OE   33
#define P10_A    25
#define P10_B    26

#define PANEL_W 32
#define PANEL_H 16
#define ROW_GROUPS 4

uint8_t framebuf[PANEL_H][PANEL_W/8];
hw_timer_t* dmdTimer = NULL;
portMUX_TYPE isr_mux = portMUX_INITIALIZER_UNLOCKED;

// GPIO Helper (sama seperti sebelumnya)
static inline void PIN_HI(int p){
  if(p<32) GPIO.out_w1ts = (1UL<<p);
  else     GPIO.out1_w1ts.val = (1UL<<(p-32));
}
static inline void PIN_LO(int p){
  if(p<32) GPIO.out_w1tc = (1UL<<p);
  else     GPIO.out1_w1tc.val = (1UL<<(p-32));
}

void p10_init(){
  pinMode(P10_DR, OUTPUT); PIN_LO(P10_DR);
  pinMode(P10_CLK,OUTPUT); PIN_LO(P10_CLK);
  pinMode(P10_LAT,OUTPUT); PIN_LO(P10_LAT);
  pinMode(P10_OE, OUTPUT); PIN_HI(P10_OE);
  pinMode(P10_A, OUTPUT); PIN_LO(P10_A);
  pinMode(P10_B, OUTPUT); PIN_LO(P10_B);
  memset(framebuf, 0xFF, sizeof(framebuf));
}

void shiftOutByte(uint8_t data){
  for(int i=7; i>=0; i--){
    if((data>>i)&1) PIN_HI(P10_DR); else PIN_LO(P10_DR);
    PIN_HI(P10_CLK); PIN_LO(P10_CLK);
  }
}

void scanRow(uint8_t g){
  PIN_HI(P10_OE);
  for(int b=(PANEL_W/8)-1; b>=0; b--){
    shiftOutByte(framebuf[g][b]);
    shiftOutByte(framebuf[(g+1)%ROW_GROUPS][b]);
  }
  PIN_HI(P10_LAT); PIN_LO(P10_LAT);
  PIN_LO(P10_A); if((g>>0)&1) PIN_HI(P10_A);
  PIN_LO(P10_B); if((g>>1)&1) PIN_HI(P10_B);
  PIN_LO(P10_OE);
}

void IRAM_ATTR timerISR(){
  static uint8_t g = 0;
  portENTER_CRITICAL_ISR(&isr_mux);
  scanRow(g);
  g = (g + 1) % ROW_GROUPS;
  portEXIT_CRITICAL_ISR(&isr_mux);
}

void initTimer(){
  uint8_t cpu = ESP.getCpuFreqMHz();
  dmdTimer = timerBegin(0, cpu, true);
  timerAttachInterrupt(dmdTimer, &timerISR, true);
  timerAlarmWrite(dmdTimer, 250, true);
  timerAlarmEnable(dmdTimer);
}

// DEBUG PIXEL - TRY DIFFERENT MAPPINGS
void setPixel(int lx, int ly, bool on){
  if(lx<0||lx>=PANEL_W||ly<0||ly>=PANEL_H) return;
  
  // TRIAL 1: Standard HUB12
  int phys_row = lx;
  int phys_col = ly;
  
  int byte_idx = phys_col / 8;
  int bit_idx  = 7 - (phys_col % 8);
  
  portENTER_CRITICAL(&isr_mux);
  if(on) framebuf[phys_row][byte_idx] &= ~(1<<bit_idx);
  else   framebuf[phys_row][byte_idx] |= (1<<bit_idx);
  portEXIT_CRITICAL(&isr_mux);
}

void clearDisplay(){ memset(framebuf, 0xFF, sizeof(framebuf)); }

void setup(){
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n=== P10 HARDWARE TEST ===");
  
  p10_init();
  initTimer();
  
  // RUN TESTS
  Serial.println("1. FULL WHITE...");
  memset(framebuf, 0x00, sizeof(framebuf)); delay(3000);
  
  Serial.println("2. FULL BLACK...");
  memset(framebuf, 0xFF, sizeof(framebuf)); delay(2000);
  
  Serial.println("3. CENTER DOT...");
  memset(framebuf, 0xFF, sizeof(framebuf));
  setPixel(16,8,true); delay(3000);
  
  Serial.println("4. H LINE...");
  memset(framebuf, 0xFF, sizeof(framebuf));
  for(int x=0;x<32;x++) setPixel(x,8,true); delay(3000);
  
  Serial.println("5. V LINE...");
  memset(framebuf, 0xFF, sizeof(framebuf));
  for(int y=0;y<16;y++) setPixel(16,y,true); delay(5000);
  
  Serial.println("TEST DONE! Report results:");
  Serial.println("- White screen OK?");
  Serial.println("- Single dot visible?");
  Serial.println("- Lines straight?");
}

void loop(){ delay(1000); }