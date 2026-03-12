#pragma once

#include "banana_demo/app/options.h"

namespace banana_demo {

class Application
{
public:
    explicit Application(AppOptions options);
    int Run();

private:
    int RunImageMode();
    int RunCameraMode();

    AppOptions options_;
};

}  // namespace banana_demo

