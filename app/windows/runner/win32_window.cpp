#include "win32_window.h"

#include <dwmapi.h>
#include <flutter/win32_flutter_window.h>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include "../anti_screenshot.h"

Win32Window::Win32Window() {}
Win32Window::~Win32Window() {}

bool Win32Window::CreateAndShow(const wchar_t* title, const Point& origin, const Size& size) {
  window_title_ = title;

  WNDCLASS wc = {};
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.lpszClassName = kClassName;
  wc.style = CS_VREDRAW | CS_HREDRAW;
  wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  wc.hIconSm = LoadIcon(nullptr, IDI_APPLICATION);
  RegisterClass(&wc);

  RECT rect = {origin.x, origin.y, origin.x + size.width, origin.y + size.height};
  AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, FALSE);

  window_handle_ = CreateWindowEx(
      0, kClassName, title,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  // Anti-screenshot: deny screen capture
  if (window_handle_) {
    SetWindowDisplayAffinity(window_handle_, WDA_MONITOR);
    
    // Try DWM blur behind for anti-capture
    DWM_BLURBEHIND bb = {};
    bb.dwFlags = DWM_BB_ENABLE;
    bb.fEnable = FALSE;
    bb.hRgnBlur = nullptr;
    DwmEnableBlurBehindWindow(window_handle_, &bb);
  }

  return window_handle_ != nullptr;
}

RECT Win32Window::GetClientArea() {
  RECT rect;
  GetClientRect(window_handle_, &rect);
  return rect;
}

LRESULT CALLBACK Win32Window::WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
  switch (message) {
    case WM_CREATE: {
      CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lParam);
      SetWindowLongPtr(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
      return 0;
    }
    case WM_DESTROY: {
      auto self = reinterpret_cast<Win32Window*>(GetWindowLongPtr(hWnd, GWLP_USERDATA));
      if (self) {
        self->Release();
      }
      SetWindowLongPtr(hWnd, GWLP_USERDATA, 0);
      return 0;
    }
    case WM_DISPLAYCHANGE: {
      // Screen resolution changed - possible screen capture
      auto self = reinterpret_cast<Win32Window*>(GetWindowLongPtr(hWnd, GWLP_USERDATA));
      if (self) {
        // Could trigger blur or security warning
      }
      return DefWindowProc(hWnd, message, wParam, lParam);
    }
    default:
      return DefWindowProc(hWnd, message, wParam, lParam);
  }
}

void Win32Window::Release() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
}
