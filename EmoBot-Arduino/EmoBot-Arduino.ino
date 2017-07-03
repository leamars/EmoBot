// Much code borrowed, learned from, and adapted from:
// http://www.geocities.jp/arduino_diecimila/led_matrix_accel.pde.txt
// http://tronixstuff.com/2010/04/30/getting-started-with-arduino-chapter-four/
// https://www.arduino.cc/en/Tutorial/Genuino101CurieIMUShockDetect

#include <CurieBLE.h>
#include "CurieIMU.h"
#include <MadgwickAHRS.h>

#define  LATCH  13
#define  CLOCK  12
#define  DATA   11
#define  DELAY  40

byte rowParser[8];
byte matrix[8];

int clearCounter = 0; // After X amount of inactivity clear the face

// Possible faces to mimic 
String faces[17] = {
  "Simple",
  "Big",
  "Small",
  "Evil",
  "Duh",
  "SuperDuh",
  "Quirky",
  "Sad",
  "Depressed",
  "Confused",
  "SuperCute",
  "SmallSurprise",
  "BigSurprise",
  "Nonchalant",
  "Cool",
  "Tongue",
  "Angry"
  };

int randomFace = 0;
bool isShowing = false;

bool waitForInput = false;

// SENSORS
Madgwick filter;
unsigned long microsPerReading, microsPrevious;
float accelScale, gyroScale;

// Create my own UUIDs; used https://www.uuidgenerator.net/
// https://github.com/drejkim/edison-arduino101-iot/blob/master/arduino/imu/imu.ino
// BLE Stuff
BLEService ledService("19B10000-E8F2-537E-4F6C-D104768A1214"); // create service

// create switch characteristic and allow remote device to read and write
BLEUnsignedIntCharacteristic switchChar("19B10000-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite | BLENotify);

int intVal;

void setup() {
  pinMode(CLOCK, OUTPUT);
  pinMode(LATCH, OUTPUT);
  pinMode(DATA,  OUTPUT);
  
  digitalWrite(CLOCK, LOW);
  digitalWrite(LATCH, LOW);
  digitalWrite(DATA,  LOW);
  
  initLED();
  clearLED();
  clearMatrix();
  
  rowParser[0] = 1;
  rowParser[1] = 2;
  rowParser[2] = 4;
  rowParser[3] = 8;
  rowParser[4] = 16;
  rowParser[5] = 32;
  rowParser[6] = 64;
  rowParser[7] = 128;
  
  Serial.begin(9600);

  // BLE Settings
  BLE.setLocalName("EmoBot-Local");
  BLE.setAdvertisedService(ledService); // set the UUID for the service this peripheral advertises
  BLE.setDeviceName("EmoBot");

  ledService.addCharacteristic(switchChar); // add the characteristic to the service
  BLE.addService(ledService); // add service

  // assign event handlers to peripheral
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  // assign event handlers to characteristic
  switchChar.setEventHandler(BLEWritten, switchCharacteristicWritten);
  switchChar.setValue(0); // set an initial value for the characteristic

  BLE.begin(); // start advertising
  BLE.advertise(); // begin initialization

  // Sensors
  CurieIMU.begin();
  CurieIMU.setGyroRate(25);
  CurieIMU.setAccelerometerRate(25);
  filter.begin(25);
  CurieIMU.setAccelerometerRange(2);
  CurieIMU.setGyroRange(250);

  microsPerReading = 1000000 / 25;

  CurieIMU.begin();
  CurieIMU.attachInterrupt(shakeDetect);

  /* Enable Shock Detection */
  CurieIMU.setDetectionThreshold(CURIE_IMU_SHOCK, 15000); // 1.5g = 1500 mg
  CurieIMU.setDetectionDuration(CURIE_IMU_SHOCK, 5000);   // 50ms
  CurieIMU.interrupts(CURIE_IMU_SHOCK);
}

void loop() {

  BLE.poll();
  
  // SMILEY
  if (!isShowing) {
    randomFace = random(17);
    hiSmiley();
    switchChar.setValue(42); //  this resets the board, 42 so it doesn't match any enum values
    isShowing = true;
    refreshLED(); // This is what actually writes to the LED
    delay(DELAY);
  } 
 
  clearCounter++;
  Serial.println(switchChar.value());
  if (clearCounter == 300000) {
    clearCounter = 0;
    switchChar.setValue(42); //  this resets the board, 42 so it doesn't match any enum values
    hiSmiley();
    refreshLED(); // This is what actually writes to the LED
    delay(DELAY);
  }
}

void showFace(int face) {
  clearCounter = 0;
  String selectedFace = faces[face];
  Serial.print("Selected face: ");
  Serial.println(selectedFace);
  
  if (selectedFace == "Simple" ) {
    simplePixelSmiley();
  } else if (selectedFace == "Big" ) {
    bigSmilePixelSmiley();
  } else if (selectedFace == "Small" ) {
    smallSmilePixelSmiley();
  } else if (selectedFace == "Evil" ) {
    evilSmilePixelSmiley();
  } else if (selectedFace == "Duh" ) {
    duhSmilePixelSmiley();
  } else if (selectedFace == "SuperDuh" ) {
    superDuhSmilePixelSmiley();
  } else if (selectedFace == "Quirky" ) {
    quirkySmilePixelSmiley();
  } else if (selectedFace == "Sad" ) {
    sadPixelSmiley();
  } else if (selectedFace == "Depressed" ) {
    depressedPixelSmiley();
  } else if (selectedFace == "Confused" ) {
    confusedPixelSmiley();
  } else if (selectedFace == "SuperCute" ) {
    superCutePixelSmiley();
  } else if (selectedFace == "SmallSurprise" ) {
    smallSurprisePixelSmiley();
  } else if (selectedFace == "BigSurprise" ) {
    bigSurprisePixelSmiley();
  } else if (selectedFace == "Nonchalant" ) {
    nonchalantPixelSmiley();
  } else if (selectedFace == "Tongue" ) {
    tonguePixelSmiley();
  } else if (selectedFace == "Cool" ) {
    coolPixelSmiley();
  } else if (selectedFace == "Angry") {
    angryPixelSmiley();
  }

  waitForInput = true; // When we detect a face - give them X amount of time to mimic EmoBot's face
  switchChar.setValue(face); // Set value of char to face num we're showing
  
  refreshLED(); // This is what actually writes to the LED
  delay(DELAY);
}

void setLed(int row, int column) {
  int parsedRow = rowParser[row];
  matrix[column] = parsedRow;
}

void createDiagonal() {
  for (int i = 0; i < 8; i++) {
    setLed(i, i);
  }
}

void line() {
  for (int i = 0; i < 8; i++) {
    setLed(0, i);
  }
}

// ------- BLE Methods ------------------------------------------------
void blePeripheralConnectHandler(BLEDevice central) {
  // central connected event handler
  Serial.print("Connected event, central: ");
  Serial.println(central.address());
}

void blePeripheralDisconnectHandler(BLEDevice central) {
  // central disconnected event handler
  Serial.print("Disconnected event, central: ");
  Serial.println(central.address());
}

void switchCharacteristicWritten(BLEDevice central, BLECharacteristic characteristic) {
  // central wrote new value to characteristic, update LED
  Serial.print("Characteristic event, written: ");
  Serial.println(characteristic);

  clearCounter = 0;
  
  if (switchChar.value()) {
     
     intVal = switchChar.value(); // read it and store it in val
     if (intVal == 1337) {
      heartSmiley();     
     }

     if (intVal == 666) {
      poopSmiley();
     }
     
     Serial.print("Switch char val: ");
     Serial.println(intVal);
     
     refreshLED(); // This is what actually writes to the LED
     delay(DELAY);
    
  } else {
    Serial.println("No char :(");
  }
}

// ------- LED Setup ------------------------------------------------
/* Follows sorce code from http://www.bryanchung.net/?p=177 */

void ledOut(int n) {
  digitalWrite(LATCH, LOW); // Make the data flow by setting latch (aka switch to low)

  shiftOut(DATA, CLOCK, MSBFIRST, (n>>8)); // Turn the pin on - and make the data have 8 bits of data - - - - - -
  // https://processing.org/reference/leftshift.html -> good explanation
  
  shiftOut(DATA, CLOCK, MSBFIRST, n); // Turn the pin on
  
  digitalWrite(LATCH, HIGH); // Close the "latch"
  delay(1);
  digitalWrite(LATCH, LOW);
}

void initLED() {
  ledOut(0x0B07); //2823
  ledOut(0x0A07); // 2567
  ledOut(0x0900); //2304
  ledOut(0x0C01); //3073
}

void clearLED() {
  int n;
  int o;
  int m;
  for(n=1;n<9;n++){
    o = n;
    m = n;

    ledOut((n<<8)); //+0x00 = 0
  }
}

void clearMatrix(){
  for(int n=0; n<8; n++) {
    matrix[n]=0;
  }
}

void refreshLED() {
  int n1, n2, n3;

  for (int i=0;i<8;i++) {
    n1 = i+1;
    n2 = matrix[i];
    n3 = (n1<<8)+n2;

    ledOut(n3);
  }
}

// ------- Detect Shake ------------------------------------------------

static void shakeDetect(void)
{
  randomFace = random(17);
  showFace(randomFace);
}

// ------- Led Faces ------------------------------------------------
void simplePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 108;
  matrix[2] = 98;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 98;
  matrix[6] = 108;
  matrix[7] = 0;
}

void bigSmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 108;
  matrix[2] = 106;
  matrix[3] = 10;
  matrix[4] = 10;
  matrix[5] = 106;
  matrix[6] = 108;
  matrix[7] = 0;
}

void smallSmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 100;
  matrix[2] = 98;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 98;
  matrix[6] = 100;
  matrix[7] = 0;
}

void evilSmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 96;
  matrix[2] = 34;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 34;
  matrix[6] = 96;
  matrix[7] = 0;
}

void duhSmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 36;
  matrix[2] = 34;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 34;
  matrix[6] = 32;
  matrix[7] = 0;
}

void superDuhSmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 34;
  matrix[2] = 34;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 34;
  matrix[6] = 34;
  matrix[7] = 0;
}

void quirkySmilePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 36;
  matrix[2] = 98;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 34;
  matrix[6] = 96;
  matrix[7] = 0;
}

void sadPixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 98;
  matrix[2] = 100;
  matrix[3] = 4;
  matrix[4] = 4;
  matrix[5] = 100;
  matrix[6] = 98;
  matrix[7] = 0;
}

void depressedPixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 36;
  matrix[2] = 100;
  matrix[3] = 4;
  matrix[4] = 4;
  matrix[5] = 100;
  matrix[6] = 36;
  matrix[7] = 0;
}

void confusedPixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 6;
  matrix[2] = 100;
  matrix[3] = 6;
  matrix[4] = 2;
  matrix[5] = 102;
  matrix[6] = 0;
  matrix[7] = 0;
}

void superCutePixelSmiley() {
  matrix[0] = 32;
  matrix[1] = 68;
  matrix[2] = 34;
  matrix[3] = 2;
  matrix[4] = 2;
  matrix[5] = 34;
  matrix[6] = 68;
  matrix[7] = 32;
}

void smallSurprisePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 96;
  matrix[2] = 100;
  matrix[3] = 10;
  matrix[4] = 10;
  matrix[5] = 100;
  matrix[6] = 96;
  matrix[7] = 0;
}

void bigSurprisePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 96;
  matrix[2] = 110;
  matrix[3] = 10;
  matrix[4] = 10;
  matrix[5] = 110;
  matrix[6] = 96;
  matrix[7] = 0;
}

void nonchalantPixelSmiley() {
  matrix[0] = 96;
  matrix[1] = 80;
  matrix[2] = 82;
  matrix[3] = 98;
  matrix[4] = 98;
  matrix[5] = 82;
  matrix[6] = 80;
  matrix[7] = 96;
}

void coolPixelSmiley() {
  matrix[0] = 96;
  matrix[1] = 84;
  matrix[2] = 82;
  matrix[3] = 98;
  matrix[4] = 98;
  matrix[5] = 82;
  matrix[6] = 84;
  matrix[7] = 96;
}

void tonguePixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 38;
  matrix[2] = 101;
  matrix[3] = 6;
  matrix[4] = 4;
  matrix[5] = 36;
  matrix[6] = 100;
  matrix[7] = 0;
}

void xSmiley() {
  matrix[0] = 0;
  matrix[1] = 66;
  matrix[2] = 36;
  matrix[3] = 24;
  matrix[4] = 24;
  matrix[5] = 36;
  matrix[6] = 66;
  matrix[7] = 0;
}

void thumbsUpSmiley() {
  matrix[0] = 0;
  matrix[1] = 0;
  matrix[2] = 28;
  matrix[3] = 30;
  matrix[4] = 126;
  matrix[5] = 126;
  matrix[6] = 18;
  matrix[7] = 18;
}

void thumbsDownSmiley() {
  matrix[0] = 72;
  matrix[1] = 72;
  matrix[2] = 126;
  matrix[3] = 126;
  matrix[4] = 56;
  matrix[5] = 56;
  matrix[6] = 0;
  matrix[7] = 0;
}

void hiSmiley() {
  matrix[0] = 0;
  matrix[1] = 126;
  matrix[2] = 126;
  matrix[3] = 0;
  matrix[4] = 126;
  matrix[5] = 24;
  matrix[6] = 126;
  matrix[7] = 126;
}

void questionSmiley() {
  matrix[0] = 0;
  matrix[1] = 96;
  matrix[2] = 248;
  matrix[3] = 205;
  matrix[4] = 221;
  matrix[5] = 224;
  matrix[6] = 248;
  matrix[7] = 0;
}

void poopSmiley() {
  matrix[0] = 6;
  matrix[1] = 15;
  matrix[2] = 57;
  matrix[3] = 197;
  matrix[4] = 85;
  matrix[5] = 53;
  matrix[6] = 13;
  matrix[7] = 6;
}

void heartSmiley() {
  matrix[0] = 48;
  matrix[1] = 120;
  matrix[2] = 76;
  matrix[3] = 38;
  matrix[4] = 34;
  matrix[5] = 68;
  matrix[6] = 72;
  matrix[7] = 48;
}

void noSmiley() {
  matrix[0] = 126;
  matrix[1] = 66;
  matrix[2] = 126;
  matrix[3] = 0;
  matrix[4] = 126;
  matrix[5] = 28;
  matrix[6] = 62;
  matrix[7] = 126;
}

void yaSmiley() {
  matrix[0] = 126;
  matrix[1] = 80;
  matrix[2] = 126;
  matrix[3] = 0;
  matrix[4] = 112;
  matrix[5] = 30;
  matrix[6] = 30;
  matrix[7] = 112;
}

void appleSmiley() {
  matrix[0] = 28;
  matrix[1] = 34;
  matrix[2] = 241;
  matrix[3] = 241;
  matrix[4] = 113;
  matrix[5] = 33;
  matrix[6] = 34;
  matrix[7] = 28;
}

void angryPixelSmiley() {
  matrix[0] = 0;
  matrix[1] = 96;
  matrix[2] = 38;
  matrix[3] = 4;
  matrix[4] = 4;
  matrix[5] = 38;
  matrix[6] = 96;
  matrix[7] = 0;
}

