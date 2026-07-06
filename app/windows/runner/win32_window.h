#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates and shows a top-level window with the given title and dimensions.
  // Returns true on success.
  bool CreateAndShow(const wchar_t* title, const Point& origin, const Size& size);

  // Rectangular region of the window
  RECT GetClientArea();

 protected:
  // Window procedure
  static LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
  static LRESULT CALLBACK GlWindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);

  // Release resources acquired on window creation
  void Release();

  HWND window_handle_{nullptr};
  std::wstring window_title_;

 private:
  // Window class name
  static constexpr wchar_t kClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
};

#endif  // RUNNER_WIN32_WINDOW_H_
