#include <LiquidCrystal.h>

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

String primeraLinea = "";
String segundaLinea = "";
bool lineaUnoRecibida = false;

String procesarTexto(String contenido, int desplazamiento) {
  contenido += "                ";
  if (desplazamiento > contenido.length() - 16) desplazamiento = 0;
  return contenido.substring(desplazamiento, desplazamiento + 16);
}

void actualizarPantalla(String texto1, String texto2) {
  static unsigned long tiempoAnterior = 0;
  static int posicion1 = 0;
  static int posicion2 = 0;

  if (millis() - tiempoAnterior >= 500) {
    lcd.setCursor(0, 0);
    lcd.print(procesarTexto(texto1, posicion1));

    lcd.setCursor(0, 1);
    lcd.print(procesarTexto(texto2, posicion2));

    posicion1 = (posicion1 + 1) % (texto1.length() + 1);
    posicion2 = (posicion2 + 1) % (texto2.length() + 1);

    tiempoAnterior = millis();
  }
}

void setup() {
  lcd.begin(16, 2);
  Serial.begin(9600);
  lcd.print("Iniciando...");
  delay(1000);
  lcd.clear();
}

void loop() {
  static String entrada = "";

  while (Serial.available()) {
    char caracter = Serial.read();
    if (caracter == '\n') {
      if (!lineaUnoRecibida) {
        primeraLinea = entrada;
        lineaUnoRecibida = true;
      } else {
        segundaLinea = entrada;
      }
      entrada = "";
    } else {
      entrada += caracter;
    }
  }

  actualizarPantalla(primeraLinea, segundaLinea);
}