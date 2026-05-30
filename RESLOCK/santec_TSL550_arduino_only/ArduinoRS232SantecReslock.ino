#include <ctype.h>
#define bit9600Delay 100
#define halfBit9600Delay 50
#define UPL 2.7
#define DNL 0.4
#define centerlambda 1528.7


byte SWval;   // for reading
byte rx = 7;  // connect 7 to RX on MAX3232 chip
byte tx = 8;  // connect 8 to TX on MAX3232 chip
// setup santec to 9600baud and LF only.

float tunedconvertx = 0.0008;  // was 0.0008;
float lambda = 0;
float lambdaFine = 0;
float totallambda = 0;
float I = 0;
float Ibest = 0;
float Itmp = 0;
float d = 0.1;  // step setting, 1 is 0.8pm
float pwr = 0;
float pwrOLD = 0;
float pdh = 0;
float rawp = 0;
int Qint = 120;
int dsign = 1;
int rawd = 0;
int rawpdh = 0;
int PDHflag = 0;  // is pdh on ?
int zigzags = 0;  // zig zag counter


void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(rx, INPUT);
  pinMode(tx, OUTPUT);
  digitalWrite(tx, HIGH);

  lambda = readwritecommand("WA");
  lambdaFine = readwritecommand("FT");

  analogWrite(5, 0);  // GND for led
  PDH_OFF();

  UpdatePower();  // note - updates Ibest

  delay(1000);  // needed for the A1 check
  if (analogRead(A1) > 800) {
    sweepCONT();
  } else {
    sweep();
  }

  centralize();

  if (0) {  //special runs
    I = 0;
    int indx = 0;
    float arr[8];
    for (float v = 0.0005; v <= 0.0009; v = v + 0.00005) {
      totallambda = lambda - (lambdaFine * v);
      setWA();
      arr[indx] = readTEN();
      indx++;
    }
    for (indx = 0; indx < 8; indx++) {
      if (arr[indx] > I) {
        I = arr[indx];
        tunedconvertx = 0.0005 + (0.00005 * indx);
        analogWrite(4, 20);  // count blinks :)
        delay(400);
        analogWrite(4, 0);
        delay(400);
      }
    }
  }
}

void SWprint(int data) {
  byte mask;
  //startbit
  digitalWrite(tx, LOW);
  delayMicroseconds(bit9600Delay);
  for (mask = 0x01; mask > 0; mask <<= 1) {
    if (data & mask) {         // choose bit
      digitalWrite(tx, HIGH);  // send 1
    } else {
      digitalWrite(tx, LOW);  // send 0
    }
    delayMicroseconds(bit9600Delay);
  }
  //stop bit
  digitalWrite(tx, HIGH);
  delayMicroseconds(bit9600Delay);
}

int SWread() {
  byte val = 0;
  while (digitalRead(rx))
    ;
  //wait for start bit
  if (digitalRead(rx) == LOW) {
    delayMicroseconds(halfBit9600Delay);
    for (int offset = 0; offset < 7; offset++) {
      delayMicroseconds(bit9600Delay);
      val |= digitalRead(rx) << offset;
    }
    //wait for stop bit + extra
    delayMicroseconds(bit9600Delay);
    delayMicroseconds(bit9600Delay);
    return val;
  }
}

void writecommand(char* command) {
  int indx = 0;
  while (command[indx]) {
    SWprint(command[indx]);
    indx++;
  }
  SWprint(10);
}

float readwritecommand(char* command) {
  char str[10];
  int indx = 0;
  writecommand(command);
  digitalWrite(LED_BUILTIN, HIGH);
  while (1) {
    SWval = SWread();
    if (SWval == 10) {
      break;
    }
    str[indx] = SWval;
    indx++;
  }
  str[indx] = '\0';
  digitalWrite(LED_BUILTIN, LOW);
  return atof(str);
}

void setWA() {
  delay(100);
  if ((totallambda > centerlambda + 3) || (totallambda < centerlambda - 3)) {
    totallambda = centerlambda;
  }
  char command[12];
  sprintf(command, "WA%.4f", totallambda);
  writecommand(command);
  delay(350);
}

void setFT() {
  char command[10];
  if (lambdaFine < 0) {
    sprintf(command, "FT%.2f", lambdaFine);
  } else {
    sprintf(command, "FT+%.2f", lambdaFine);
  }
  writecommand(command);
  //delay(10);
}

void setPWR() {
  char command[8];
  sprintf(command, "OP%.2f", pwr);
  writecommand(command);
  delay(100);
}

void PDH_ON() {
  zigzags = 0;
  analogWrite(2, 255);
  //analogWrite(2, Qint);
  analogWrite(4, 100);
  PDHflag = 1;
  delay(1000);  // give it a chance
}

void PDH_OFF() {
  analogWrite(2, 0);
  analogWrite(4, 0);
  PDHflag = 0;
}

void UpdatePower() {
  rawp = analogRead(A0) + analogRead(A0) + analogRead(A0) + analogRead(A0) + analogRead(A0) + analogRead(A0) + analogRead(A0) + analogRead(A0);
  rawp = rawp * 0.125;          // 0-1023
  pwr = rawp * (5.0 / 1023.0);  // 0-5 V
  pwr = 2.4 * pwr;              // 0 - 12 dbm
  if ((pwrOLD - pwr > 0.2) || (pwrOLD - pwr < -0.2)) {
    setPWR();
    pwrOLD = pwr;
    Ibest = readTEN();
  }
}

void sweep() {
  // compensate for slew rate to initial position
  lambdaFine = -100.00;
  setFT();
  delay(20);

  I = 0;
  int indx = 0;
  int arr[200];
  for (float i = -100.00; i <= +100.00; i++) {
    lambdaFine = i;
    setFT();
    delay(10);
    arr[indx] = readTEN();
    indx++;
  }
  for (indx = 0; indx < 200; indx++) {
    if (arr[indx] > I) {
      I = arr[indx];
      lambdaFine = indx - 100.00;
    }
  }
  lambdaFine = lambdaFine - 15;
  setFT();
  Ibest = I;

  //Q calc
  float Q = 0;
  for (indx = 0; indx < 200; indx++) {
    if (arr[indx] > 0.5 * Ibest) {
      Q++;
    }
  }
  Q = (lambda / (Q * tunedconvertx)) / 1000;
  Qint = (int)Q;
  if (Qint > 255) {
    Qint = 255;
  }
}

void sweepCONT() {
  if (Ibest < 20) {
    Ibest = 100;  // for running at start and other BS (100=0.5v)
  }
  char command[12];
  writecommand("SM7");  // cont 1 way
  delay(100);
  writecommand("SZ1");  // 1 run
  delay(100);
  writecommand("SN1.0");  // speed
  delay(100);
  sprintf(command, "SS%.4f", centerlambda - 1.5);
  writecommand(command);  // start
  delay(100);
  sprintf(command, "SE%.4f", centerlambda + 1.5);
  writecommand(command);  // end
  delay(100);
  writecommand("SG");  // ready
  delay(100);
  writecommand("ST");  // GO
  delay(50);           // initial jump

  int ctr = 0;
  I = analogRead(A5);
  while ((I < 0.2 * Ibest) && (ctr < 150000)) {
    I = analogRead(A5);
    ctr++;
  }

  writecommand("SP");  // pause
  delay(300);
  writecommand("SQ");  // stop
  delay(300);

  if (ctr == 150000) {
    Ibest = Ibest * 0.5;
    sweepCONT();
    return;
  }

  lambda = readwritecommand("WA");
  lambdaFine = readwritecommand("FT");
  totallambda = lambda - (lambdaFine * tunedconvertx);
}

void centralize() {
  totallambda = lambda - (lambdaFine * tunedconvertx);
  setWA();
  lambda = totallambda;
  lambdaFine = readwritecommand("FT");
}

float readTEN() {
  Itmp = 0;
  for (int v = 0; v < 10; v++) {
    Itmp = Itmp + analogRead(A5);
    delay(2);
  }
  return 0.5 * Itmp;
}

void zigzag() {
  centralize();
  // get I
  I = readTEN();
  //
  while (I < 0.3 * Ibest) {
    Itmp = I;
    if (lambdaFine < 0) {
      lambdaFine = -lambdaFine;
    } else {
      lambdaFine = -lambdaFine - 2;
    }
    setFT();
    delay(20);
    I = readTEN();
    if (lambdaFine < -95.00) {
      if (I > Itmp) {
        break;
      } else {
        lambdaFine = 95.00;
        setFT();
        I = readTEN();
        break;
      }
    }
    if (analogRead(A1) > 800) {
      Ibest = 0;
      break;  // go to sweepCONT
    }
  }
}

void loop() {
  while (analogRead(A4) > 800) {
    delay(100);
    if (PDHflag == 0) {
      Qint = 200;
      PDH_ON();
    }
  }

  rawd = analogRead(A3);      // 0-1023
  d = rawd * (5.0 / 1023.0);  // 0-5 V
  d = 0.2 * d;                // 0 - 0.5 (0 - 0.8pm)

  I = readTEN();
  if ((I < 0.90 * Ibest) && (PDHflag == 0)) {
    lambdaFine = lambdaFine + dsign * d;
    setFT();
    Itmp = readTEN();
    if (Itmp < I) {
      dsign = -dsign;
    }
  } else {
    Itmp = I;
    if (PDHflag == 0) {
      PDH_ON();
    }
  }
  if (Itmp > Ibest) {
    Ibest = Itmp;
  }
  //Ibest = 0.999 * Ibest + 0.001 * Itmp;

  if ((lambdaFine < -98.00) || (lambdaFine > +98.00)) {
    centralize();
  }

  if (Itmp > 0.3 * Ibest) {
    if (PDHflag == 0) {
      PDH_ON();
    }
  }

  if (Itmp < 0.3 * Ibest) {
    PDH_OFF();
    zigzags = zigzags + 1;
    zigzag();
    if (zigzags > 3) {
      zigzags = 0;
      sweepCONT();  // auto enter
    }
  }

  if (analogRead(A1) > 800) {
    PDH_OFF();
    sweepCONT();
  }

  if (PDHflag == 1) {
    // PDH
    rawpdh = analogRead(A2);        // 0-1023
    pdh = rawpdh * (5.0 / 1023.0);  // 0-5 V

    if (((pdh > UPL) || (pdh < DNL)) && (Itmp < 0.7 * Ibest)) {
      PDH_OFF();
      lambdaFine = (100 * ((pdh - 1.58) / 1.5)) + lambdaFine;
      if (lambdaFine > 100.0) {
        lambdaFine = 100.0;
      }
      if (lambdaFine < -100.0) {
        lambdaFine = -100.0;
      }
      centralize();
    }

    if ((pdh < 0.5) && (lambdaFine > -80)) {
      lambdaFine = lambdaFine - 1;
      setFT();
      delay(100);
    }
  }
  UpdatePower();
}
