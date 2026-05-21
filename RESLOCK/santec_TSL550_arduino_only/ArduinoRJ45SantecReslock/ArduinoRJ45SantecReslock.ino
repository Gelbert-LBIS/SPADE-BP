#include <ctype.h>
#include <Ethernet.h>
#include <utility/w5100.h>

#define UPL 2.7
#define DNL 0.5
#define BATT 1.5
#define centerlambda 1526.5

byte mac[] = { 0xA8, 0x61, 0x0A, 0xAE, 0x2E, 0x7D };
IPAddress ip(132, 68, 57, 77);
IPAddress dns(132, 68, 49, 13);
IPAddress gateway(132, 68, 57, 126);
IPAddress subnet(255, 255, 255, 128);
IPAddress santecIP(132, 68, 57, 59);
IPAddress MOKUIP(132, 68, 57, 22);
int SANTECport = 5900;
int MOKUport = 12346;
EthernetClient santec_client;
EthernetClient MOKU_client;

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

  // LED setup
  pinMode(LED_BUILTIN, OUTPUT);
  analogWrite(7, 0);
  analogWrite(6, 0);

  // build ethernet
  pinMode(4, OUTPUT);
  digitalWrite(4, HIGH);
  Ethernet.init(10);
  //forceCloseAllSockets();
  Ethernet.begin(mac, ip, dns, gateway, subnet);

  while (Ethernet.hardwareStatus() == EthernetNoHardware) {
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
  }

  while (Ethernet.linkStatus() != LinkON) {
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    Ethernet.begin(mac, ip, dns, gateway, subnet);
    delay(500);
  }

  santec_client.connect(santecIP, SANTECport);
  delay(500);

  //MOKU_client.connect(MOKUIP, MOKUport);
  //delay(500);

  while (santec_client.connected() != 1) {
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    santec_client.stop();
    santec_client.connect(santecIP, SANTECport);
    delay(500);
  }
  santec_client.flush();

  writecommand(":POW:SHUT 0");
  writecommand(":AM:SOUR 3");
  lambda = readwritecommand(":WAV?");
  lambdaFine = readwritecommand(":WAV:FIN?");

  PDH_OFF();

  UpdatePower();  // note - updates Ibest

  delay(1000);  // needed for the A1 check
  if (analogRead(A1) > 800) {
    //sweepCONT();
  } else {
    //sweep();
  }

  sweepCONT();


  centralize();
}

void forceCloseAllSockets() {
  for (uint8_t s = 0; s < MAX_SOCK_NUM; s++) {
    uint8_t st = W5100.readSnSR(s);
    // If any socket is active or half-closed, disconnect then close.
    // (DISCON sends FIN; CLOSE releases immediately.)
    if (st != SnSR::CLOSED) {
      W5100.execCmdSn(s, Sock_DISCON);
      delay(20);
      W5100.execCmdSn(s, Sock_CLOSE);
      W5100.writeSnIR(s, 0xFF);  // clear any pending socket IRQs
    }
  }
}

void writecommand(char* command) {
  if (santec_client) {
    santec_client.print(command);  // send the command body
    santec_client.print('\r');     // santecIP requires CR terminator
  }
}


float readwritecommand(char* command) {
  char str[32];
  int idx = 0;

  writecommand(command);

  digitalWrite(LED_BUILTIN, HIGH);

  unsigned long start = millis();
  while (millis() - start < 1000) {  // 1 second timeout
    while (santec_client.available()) {
      char c = santec_client.read();
      if (c == '\r') {    // end of response
        str[idx] = '\0';  // null-terminate
        digitalWrite(LED_BUILTIN, LOW);
        return atof(str);  // convert and return
      }
      if (idx < (int)sizeof(str) - 1) {
        str[idx++] = c;
      }
    }
  }
}

void setWA() {
  delay(100);
  if ((totallambda > centerlambda + 3) || (totallambda < centerlambda - 3)) {
    totallambda = centerlambda;
  }
  char command[15];
  sprintf(command, ":WAV %.4f", totallambda);
  writecommand(command);
  delay(350);
}

void setFT() {
  char command[17];
  if (lambdaFine < 0) {
    sprintf(command, ":WAV:FIN -%.2f", lambdaFine);
  } else {
    sprintf(command, ":WAV:FIN +%.2f", lambdaFine);
  }
  writecommand(command);
  //delay(10);
}

void setPWR() {
  char command[11];
  sprintf(command, ":POW %.2f", pwr);
  writecommand(command);
  delay(100);
}

void PDH_ON() {
  if (MOKU_client) {
    MOKU_client.flush();
    MOKU_client.print(lambdaFine, 6);  // send the command body
    MOKU_client.print('\n');           // santecIP requires CR terminator
  }
  zigzags = 0;
  writecommand(":AM:STAT 1");
  analogWrite(2, 255);
  //analogWrite(2, Qint);
  analogWrite(6, 100);
  PDHflag = 1;
  delay(1000);  // give it a chance
}

void PDH_OFF() {
  writecommand(":AM:STAT 0");
  analogWrite(2, 0);
  analogWrite(6, 0);
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
    Ibest = 200;  // for running at start and other BS (100=0.5v)
  }
  char command[24];
  writecommand(":WAV:SWE:MOD 1");  // cont 1 way
  delay(1000);
  writecommand(":WAV:SWE:CYCL 1");  // 1 run
  delay(1000);
  writecommand(":WAV:SWE:SPE 1");  // speed
  delay(1000);
  sprintf(command, ":WAV:SWE:STAR %.4f", centerlambda - 1.5);
  writecommand(command);  // start
  delay(1000);
  sprintf(command, ":WAV:SWE:STOP %.4f", centerlambda + 1.5);
  writecommand(command);  // end
  delay(1000);
  writecommand(":WAV:SWE:REP");  // ready
  delay(5000);
  writecommand(":WAV:SWE:SOFT");  // GO
  delay(100);                      // initial jump

  int ctr = 0;
  I = analogRead(A5);
  while ((I < 0.2 * Ibest) && (ctr < 15000)) { //150000
    I = analogRead(A5);
    ctr++;
  }

  writecommand(":WAV:SWE 0");  // pause
  delay(300);

  if (ctr == 15000) {
    Ibest = Ibest * 0.5;
    sweepCONT();
    return;
  }

  lambda = readwritecommand(":WAV?");
  lambdaFine = readwritecommand(":WAV:FIN?");
  totallambda = lambda - (lambdaFine * tunedconvertx);
}

void centralize() {
  totallambda = lambda - (lambdaFine * tunedconvertx);
  setWA();
  lambda = totallambda;
  lambdaFine = readwritecommand(":WAV:FIN?");  // NEEDED? ALLWAYS 0? STARTS THE FT?
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
  Ethernet.maintain();

  while (Ethernet.linkStatus() != LinkON) {
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    Ethernet.begin(mac, ip, dns, gateway, subnet);
    delay(500);
  }

  while (santec_client.connected() != 1) {
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    delay(100);
    analogWrite(6, 20);
    delay(100);
    analogWrite(6, 0);
    santec_client.stop();
    santec_client.connect(santecIP, SANTECport);
    delay(500);
  }

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
      lambdaFine = (100 * ((pdh - BATT) / 1.5)) + lambdaFine;
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
