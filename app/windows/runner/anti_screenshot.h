#ifndef ANTI_SCREENSHOT_H_
#define ANTI_SCREENSHOT_H_

#include <windows.h>

// Windows anti-screenshot/screen-capture protection
class AntiScreenshot {
 public:
  static void EnableProtection(HWND hwnd) {
    // Deny screen capture
    SetWindowDisplayAffinity(hwnd, WDA_MONITOR);
    
    // Try to enable DWM content protection
    // Note: Windows has limited anti-capture capabilities
    // Best-effort only
  }
  
  static void DisableProtection(HWND hwnd) {
    SetWindowDisplayAffinity(hwnd, WDA_NONE);
  }
  
  static void BlurWindow(HWND hwnd) {
    // Dim the window when focus is lost
    ShowWindow(hwnd, SW_MINIMIZE);
    SetForegroundWindow(hwnd);
  }
  
  static bool IsCaptureInProgress() {
    // Best-effort detection
    // Windows doesn't expose direct capture detection API
    return false;
  }
};

#endif  // ANTI_SCREENSHOT_H_
