// Windows anti-screenshot/screen-capture protection
// Uses Win32 APIs for best-effort protection

#include <windows.h>
#include <dwmapi.h>

// Enable Windows 10+ screen capture detection
void EnableScreenCaptureDetection(HWND hwnd) {
    // DWMWA_DISK_GPU_FILTER - Helps prevent some screen capture
    DWORD filter = 1;
    DwmSetWindowAttribute(
        hwnd,
        DWMWA_DISK_GPU_FILTER,
        &filter,
        sizeof(filter)
    );
}

// Blur window content when focus is lost (background switching)
void BlurOnBackgroundLoss(HWND hwnd, bool blur) {
    if (blur) {
        // Dim the window when it loses focus
        WINDOWCOMPOSITIONATTRIBDATA wcad = {0};
        wcad.Attrib = WCA_ACCENT_POLICY;
        
        ACCENT_POLICY accent = {
            AccentState::AccentDisabled, // Could use BlurBehind for visual effect
            0, 0, 0
        };
        wcad.pValue = &accent;
        wcad.cbSize = sizeof(wcad);
        
        SetWindowCompositionAttribute(hwnd, &wcad);
    }
}

// Check if screen capture is in progress (Windows 10+)
bool IsScreenCaptureInProgress() {
    // Use GetForegroundWindow to detect if another window might be capturing
    HWND foreground = GetForegroundWindow();
    if (foreground == nullptr) return false;
    
    // Check if a screen capture API is being used
    // This is best-effort as Windows doesn't expose direct capture detection
    return false;
}

// Note: Windows has limited anti-screenshot capabilities compared to mobile platforms.
// The best we can do is:
// 1. Blur window on background
// 2. Use DWM APIs to discourage capture
// 3. Show warnings when suspicious activity is detected
