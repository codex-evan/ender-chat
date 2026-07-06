#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

namespace utils {
// Creates the console used by the sample program.
HWND CreateStdoutConsole();

// Parses the command-line arguments.
// See https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731.aspx
std::vector<std::string> GetCommandLineArguments();

// Replaces the current stdout/stderr with new console windows.
void RedirectIOToConsole();
}  // namespace utils

#endif  // RUNNER_UTILS_H_
