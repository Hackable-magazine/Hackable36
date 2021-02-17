#include <OneWire.h>
#include <DallasTemperature.h>

#define MSECOND  1000UL
#define MMINUTE  60*MSECOND
#define MHOUR    60*MMINUTE
#define MDAY     24*MHOUR

#define BASET    (5*MSECOND) // attention aux parenthèse (macro = remplacement)
#define FRACM    ((MMINUTE/BASET)/2.0) // float pour longue période -> 20s pe

#define PWMFAN   6
#define ONEWIRE  A0

unsigned long previousMillis = 0;
volatile int n = 0;

OneWire oneWire(ONEWIRE);
DallasTemperature ds(&oneWire);

void count() {
  n++;
}

void setup() {
  TCCR0B = TCCR0B & B11111000 | B00000001; // PWM freq à 62,50 kHz
  pinMode(PWMFAN, OUTPUT);
  // tacho signal
  pinMode(2, INPUT_PULLUP);

  ds.begin();
  ds.setResolution(9);
  
  Serial.begin(115200);
  Serial.println("Go go go!");

  analogWrite(PWMFAN, 0);
  //mapwm6(255);

  attachInterrupt(digitalPinToInterrupt(2), count, FALLING);

}

void loop() {
  unsigned long currentMillis = millis();
  // modification *64 -> freq timer0 modifiée
  if (currentMillis - previousMillis >= BASET*64) {
    previousMillis = currentMillis;
    unsigned int rpm = n*FRACM; // cast
    n=0;
    
    ds.requestTemperatures();
    float t = ds.getTempCByIndex(0);
    unsigned short duty = ((t-20)*8)-1;
    if(duty < 50) duty = 0;
    if(duty > 255) duty = 255;
    analogWrite(PWMFAN, duty);
    //mapwm6(duty);
    
    Serial.print("Temp= ");
    Serial.print(t);
    Serial.print("°C    ");
    Serial.print(rpm);
    Serial.print(" RPM    duty= ");
    Serial.print(duty*100/255);
    Serial.print("% (");
    Serial.print(duty);
    Serial.println(")");
  }
}
