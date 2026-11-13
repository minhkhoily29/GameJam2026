const int TILT_PIN     = 14;
const int BUTTON_PIN   = 27;
const int JOY_BUTTON   = 33;
const int JOY_X        = 34;
const int JOY_Y        = 35;

const unsigned long SEND_INTERVAL = 20; // 50 updates/second
unsigned long lastSend = 0;

void setup() {
  Serial.begin(115200);

  pinMode(TILT_PIN, INPUT_PULLUP);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(JOY_BUTTON, INPUT_PULLUP);

  pinMode(JOY_X, INPUT);
  pinMode(JOY_Y, INPUT);

  analogReadResolution(12);
}

void loop() {
  unsigned long now = millis();

  if (now - lastSend < SEND_INTERVAL) {
    return;
  }
  lastSend = now;

  int x = analogRead(JOY_X);
  int y = analogRead(JOY_Y);

  // 1 = pressed / switch closed, 0 = released / open
  bool button = digitalRead(BUTTON_PIN) == HIGH;
  bool joystickButton = digitalRead(JOY_BUTTON) == LOW;
  bool tilt = digitalRead(TILT_PIN) == LOW;

  // Output format: x,y,button,joystickButton,tilt
  Serial.print(x);
  Serial.print(',');
  Serial.print(y);
  Serial.print(',');
  Serial.print(button);
  Serial.print(',');
  Serial.print(joystickButton);
  Serial.print(',');
  Serial.println(tilt);
}