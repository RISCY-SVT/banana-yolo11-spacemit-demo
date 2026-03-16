/**
 * @file application.h
 * @brief Top-level application runner for image and camera workflows.
 */

#pragma once

#include "banana_demo/app/options.h"

namespace banana_demo {

/**
 * @brief Orchestrates CLI-selected image or camera execution.
 */
class Application
{
public:
    /**
     * @brief Construct the application runner.
     * @param options Immutable application options snapshot.
     */
    explicit Application(AppOptions options);
    /**
     * @brief Run the selected source mode.
     * @return Process exit code compatible with the helper scripts.
     */
    int Run();

private:
    /** @brief Execute single-image inference mode. */
    int RunImageMode();
    /** @brief Execute live camera inference mode. */
    int RunCameraMode();

    /** Immutable per-run configuration snapshot. */
    AppOptions options_;
};

}  // namespace banana_demo
