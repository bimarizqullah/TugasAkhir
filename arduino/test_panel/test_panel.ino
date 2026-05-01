// ─── PIN P10 HUB12 ───────────────────────────────────
#define P10_DR   33
#define P10_CLK  26
#define P10_LAT  25
#define P10_OE   13
#define P10_A    14
#define P10_B    27

#define PANEL_W    32
#define PANEL_H    16
#define ROW_GROUPS  4

uint8_t framebuf[PANEL_H][PANEL_W / 8];

// ─── Font 3x5 ────────────────────────────────────────
const uint8_t font3x5[][3] = {
  { 0x1F, 0x11, 0x1F }, // 0
  { 0x00, 0x1F, 0x00 }, // 1
  { 0x1D, 0x15, 0x17 }, // 2
  { 0x11, 0x15, 0x1F }, // 3
  { 0x07, 0x04, 0x1F }, // 4
  { 0x17, 0x15, 0x1D }, // 5
  { 0x1F, 0x15, 0x1D }, // 6
  { 0x01, 0x01, 0x1F }, // 7
  { 0x1F, 0x15, 0x1F }, // 8
  { 0x17, 0x15, 0x1F }, // 9
};

// ─── DRIVER ──────────────────────────────────────────
void p10_init() {
  pinMode(P10_DR,  OUTPUT);
  pinMode(P10_CLK, OUTPUT);
  pinMode(P10_LAT, OUTPUT);
  pinMode(P10_OE,  OUTPUT);
  pinMode(P10_A,   OUTPUT);
  pinMode(P10_B,   OUTPUT);
  digitalWrite(P10_OE,  HIGH);
  digitalWrite(P10_LAT, LOW);
  digitalWrite(P10_CLK, LOW);
  digitalWrite(P10_DR,  LOW);
  memset(framebuf, 0xFF, sizeof(framebuf));
}

void p10_shiftByte(uint8_t data) {
  for (int i = 7; i >= 0; i--) {
    digitalWrite(P10_DR,  (data >> i) & 1);
    digitalWrite(P10_CLK, HIGH);
    digitalWrite(P10_CLK, LOW);
  }
}

void p10_scanRow(uint8_t group) {
  digitalWrite(P10_OE, HIGH);
  // scanMode 3 — paling umum untuk P10 HUB12
  for (int r = 0; r < 4; r++) {
    uint8_t row = group + (r * ROW_GROUPS);
    for (int b = (PANEL_W / 8) - 1; b >= 0; b--)
      p10_shiftByte(framebuf[row][b]);
  }
  digitalWrite(P10_LAT, HIGH);
  digitalWrite(P10_LAT, LOW);
  digitalWrite(P10_A, (group >> 0) & 1);
  digitalWrite(P10_B, (group >> 1) & 1);
  digitalWrite(P10_OE, LOW);
}

void p10_refresh() {
  for (uint8_t g = 0; g < ROW_GROUPS; g++) {
    p10_scanRow(g);
    delayMicroseconds(500);
  }
}

void p10_clear() {
  memset(framebuf, 0xFF, sizeof(framebuf));
}

void p10_setPixelRaw(int x, int y, bool on) {
  if (x < 0 || x >= PANEL_W || y < 0 || y >= PANEL_H) return;
  if (on) framebuf[y][x / 8] &= ~(0x80 >> (x % 8));
  else    framebuf[y][x / 8] |=  (0x80 >> (x % 8));
}

// ─── ROTASI: ubah ROT_MODE untuk mencari yang benar ──
// 0 = normal landscape
// 1 = 90° CW  (konektor kiri)
// 2 = 180°    (konektor kanan/atas terbalik)
// 3 = 90° CCW (konektor kanan)
// 4 = 90° CW + flip H
// 5 = 90° CCW + flip H

int ROT_MODE = 3; // ← GANTI INI (0–5) sampai benar

void p10_setPixel(int lx, int ly, bool on) {
  // r3 untuk landscape: lx=0..31, ly=0..15
  int px = PANEL_H - 1 - ly;
  int py = lx;
  p10_setPixelRaw(px, py, on);
}

// ─── TEST PATTERN ────────────────────────────────────
// Gambar huruf "F" di sudut kiri atas ruang logis (portrait 16x32)
// Jika "F" muncul tegak & terbaca normal → ROT_MODE sudah benar
// Jika mirror/terbalik → coba ROT_MODE lain
void drawTestF() {
  p10_clear();
  // Huruf F besar, 5 kolom x 7 baris, di pojok kiri atas logis (1,1)
  // F = kolom vertikal kiri + dua garis horizontal atas & tengah
  int ox = 1, oy = 1;
  // Garis vertikal kiri
  for (int r = 0; r < 7; r++) p10_setPixel(ox, oy + r, true);
  // Garis horizontal atas
  for (int c = 0; c < 5; c++) p10_setPixel(ox + c, oy, true);
  // Garis horizontal tengah
  for (int c = 0; c < 4; c++) p10_setPixel(ox + c, oy + 3, true);
}

// ─── Waktu Internal ──────────────────────────────────
uint32_t baseMillis = 0;
int baseH = 0, baseM = 0, baseS = 0;
int curH  = 0, curM  = 0, curS  = 0;

void setTime(int h, int m, int s) {
  baseH = h; baseM = m; baseS = s;
  baseMillis = millis();
}

void updateTime() {
  uint32_t elapsed = (millis() - baseMillis) / 1000;
  uint32_t totalSec = (uint32_t)(baseH*3600 + baseM*60 + baseS) + elapsed;
  totalSec %= 86400;
  curH = totalSec / 3600;
  curM = (totalSec % 3600) / 60;
  curS = totalSec % 60;
}

// ─── RENDER DIGIT & JAM ──────────────────────────────
void drawDigit(int cx, int cy, int digit) {
  for (int col = 0; col < 3; col++) {
    uint8_t colData = font3x5[digit][col];
    for (int row = 0; row < 5; row++)
      p10_setPixel(cx + col, cy + row, (colData >> row) & 1);
  }
}

void drawColon(int cx, int cy, bool on) {
  p10_setPixel(cx, cy + 1, on);
  p10_setPixel(cx, cy + 3, on);
}

void drawClock(int h, int m, int s) {
  p10_clear();
  bool blink = (s % 2 == 0);

  int ox = 2;   // X offset: (32-28)/2 = 2
  int oy = 5;   // Y offset: (16-5)/2 = 5

  drawDigit(ox,      oy, h / 10);
  drawDigit(ox + 4,  oy, h % 10);
  drawColon(ox + 8,  oy, blink);
  drawDigit(ox + 10, oy, m / 10);
  drawDigit(ox + 14, oy, m % 10);
  drawColon(ox + 18, oy, blink);
  drawDigit(ox + 20, oy, s / 10);
  drawDigit(ox + 24, oy, s % 10);
}

// ─── SERIAL ──────────────────────────────────────────
String serialBuf = "";
bool testMode = true; // true = tampil huruf F, false = tampil jam

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      serialBuf.trim();

      // Ganti ROT_MODE: ketik "r0" sampai "r5"
      if (serialBuf.startsWith("r") && serialBuf.length() == 2) {
        int mode = serialBuf.substring(1).toInt();
        if (mode >= 0 && mode <= 5) {
          ROT_MODE = mode;
          Serial.printf(">> ROT_MODE = %d\n", ROT_MODE);
        }
      }
      // Ketik "clock" untuk beralih ke mode jam
      else if (serialBuf == "clock") {
        testMode = false;
        Serial.println(">> Mode JAM aktif");
      }
      // Ketik "test" untuk kembali ke test pattern
      else if (serialBuf == "test") {
        testMode = true;
        Serial.println(">> Mode TEST aktif");
      }
      // Set jam: HH:MM:SS
      else if (serialBuf.length() == 8 && serialBuf[2] == ':' && serialBuf[5] == ':') {
        int h = serialBuf.substring(0,2).toInt();
        int m = serialBuf.substring(3,5).toInt();
        int s = serialBuf.substring(6,8).toInt();
        if (h<24 && m<60 && s<60) {
          setTime(h,m,s);
          testMode = false;
          Serial.printf(">> Jam diset ke %02d:%02d:%02d\n", h, m, s);
        }
      }
      else if (serialBuf.length() > 0) {
        Serial.println(">> Perintah: r0-r5 (rotasi), clock, test, HH:MM:SS");
        Serial.printf(">> ROT_MODE saat ini: %d\n", ROT_MODE);
      }
      serialBuf = "";
    } else {
      serialBuf += c;
    }
  }
}

// ═════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  delay(500);
  p10_init();
  setTime(0, 0, 0);
  Serial.println("=== P10 Portrait Debug ===");
  Serial.println("Ketik r0-r5 untuk ganti rotasi");
  Serial.println("Cari ROT_MODE yang membuat huruf F tegak & terbaca normal");
  Serial.println("Lalu ketik 'clock' atau HH:MM:SS");
}

void loop() {
  if (testMode) {
    drawTestF();
  } else {
    updateTime();
    drawClock(curH, curM, curS);
  }
  p10_refresh();
  handleSerial();
}