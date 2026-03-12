#include <iostream>

#include <onnxruntime_cxx_api.h>

#include "banana_demo/app/application.h"
#include "banana_demo/app/options.h"

int main(int argc, char** argv)
{
    banana_demo::AppOptions options;
    std::string error;
    if (!banana_demo::ParseAppOptions(argc, argv, options, error))
    {
        if (!error.empty())
            std::cerr << "ERROR: " << error << '\n';
        std::cerr << banana_demo::BuildUsage();
        return 1;
    }

    try
    {
        banana_demo::Application app(options);
        return app.Run();
    }
    catch (const Ort::Exception& e)
    {
        std::cerr << "ORT exception: " << e.what() << '\n';
        return 2;
    }
    catch (const std::exception& e)
    {
        std::cerr << "Exception: " << e.what() << '\n';
        return 2;
    }
}
