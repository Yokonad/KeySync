# Keylogger Serial para Arduino LCD

Script de PowerShell que captura teclas globalmente y las envía a un Arduino con pantalla LCD 16x2 vía puerto serial.

## Requisitos

### Hardware
- Arduino UNO/Nano/Mega
- Pantalla LCD 16x2
- Cable USB
- Cable Jumper

### Software
- Windows 10/11
- PowerShell 5.1+
- Arduino IDE

## Instalación Rápida

### 1. Código Arduino

```cpp
En el Repositorio
```

**Funcionamiento del código Arduino:**
- Recibe texto por serial terminado en `\n`
- Primera línea recibida: se guarda en línea superior del LCD
- Líneas siguientes: se guardan en línea inferior del LCD
- Efecto scroll cada 500ms para textos largos
- La función `procesarTexto()` extrae ventanas de 16 caracteres
- La función `actualizarPantalla()` refresca el LCD con el desplazamiento

### 2. Conexiones LCD

```
LCD Pin → Arduino
VSS     → GND
VDD     → 5V
V0      → Potenciómetro (contraste)
RS      → Pin 12
RW      → GND
E       → Pin 11
D4      → Pin 5
D5      → Pin 4
D6      → Pin 3
D7      → Pin 2
A       → 5V (con resistencia 220Ω)
K       → GND
```

## Uso

### Ejecutar esto en tu PowerShell (Modo usuario)

```cmd
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "ruta\al\script.ps1" -Port COM14 -BaudRate 9600
```

**Explicación del comando:**
- `powershell`: Ejecutable de PowerShell
- `-WindowStyle Hidden`: Oculta la ventana completamente
- `-ExecutionPolicy Bypass`: Ignora restricciones de seguridad de Windows
- `-File "ruta"`: Ruta completa al script
- `-Port COM14`: Puerto COM donde está el Arduino
- `-BaudRate 9600`: Velocidad de comunicación (debe coincidir con Arduino)

## Parámetros

| Parámetro | Descripción | Predeterminado |
|-----------|-------------|----------------|
| `-Port` | Puerto COM del Arduino | COM14 |
| `-BaudRate` | Velocidad serial | 9600 |


## Detener el Script

**PowerShell:**
```powershell
Get-Process powershell | Where-Object {$_.MainWindowTitle -eq ""} | Stop-Process
```

## Teclas Especiales Detectadas

- **Enter** → Salto de línea
- **Espacio** → Espacio
- **Tab** → `<TAB>`
- **Backspace** → `<BACK>`
- **Delete** → `<DEL>`
- **Flechas** → `<LEFT>`, `<RIGHT>`, `<UP>`, `<DOWN>`
- **Funciones** → `<F1>` a `<F12>`
- **ESC** → Cierra el programa

## Funcionamiento Técnico

### Script PowerShell

1. **Captura de Teclas**: Usa Windows Hooks (`WH_KEYBOARD_LL`) para interceptar eventos globales
2. **Buffer**: Mantiene hasta 100 caracteres en memoria
3. **Envío Serial**: Transmite los últimos 32 caracteres al Arduino
4. **Auto-limpieza**: Resetea buffer al llegar a 100 caracteres
5. **Info Inicial**: Envía hora, usuario y sistema al conectar

**Requiere permisos de administrador** por el uso de hooks del sistema.

### Código Arduino

1. **Recepción Serial**: Lee caracteres hasta encontrar `\n`
2. **Almacenamiento**: 
   - Primera línea → `primeraLinea`
   - Siguientes → `segundaLinea`
3. **Scroll Automático**: Desplaza texto cada 500ms si excede 16 caracteres
4. **Ventana Deslizante**: `procesarTexto()` extrae segmentos de 16 chars
5. **Actualización LCD**: `actualizarPantalla()` refresca continuamente

## Licencia

MIT License - Uso libre con atribución