#include "utils.h"

#include <fcntl.h>
#include <iostream>
#include <windows.h>

namespace utils {
HWND CreateStdoutConsole() {
  AllocConsole();
  SetConsoleTitle(L"EncChat Console");
  FILE* unused;
  freopen_s(&unused, "CONOUT$" , "w" , stdout);
  freopen_s(&unused, "CONIN$" , "r" , stdin);
  return GetConsoleWindow();
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (!argv) {
    return std::vector<std::string>();
  }
  std::vector<std::string> result;
  for (int idx = 0; idx < argc; ++idx) {
    auto sizeWide = ::WideCharToMultiByte(CP_UTF8, 0, argv[idx], -1, nullptr, 0, nullptr, nullptr);
    if (sizeWide <= 0) continue;
    auto sizeMB = sizeWide - 1;
    std::string argument(sizeMB, 0);
    ::WideCharToMultiByte(CP_UTF8, 0, argv[idx], -1, &argument[0], sizeMB, nullptr, nullptr);
    result.push_back(argument);
  }
  ::LocalFree(argv);
  return result;
}
}  // namespace utils
