if(NOT VENDOR_SPACEMIT_ORT_ROOT)
    if(DEFINED ENV{SPACEMIT_ORT_ROOT})
        set(VENDOR_SPACEMIT_ORT_ROOT "$ENV{SPACEMIT_ORT_ROOT}")
    elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../third_party/vendor/spacemit-ort.riscv64.2.0.1")
        get_filename_component(_repo_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
        set(VENDOR_SPACEMIT_ORT_ROOT "${_repo_root}/third_party/vendor/spacemit-ort.riscv64.2.0.1")
    endif()
endif()

if(EXISTS "${VENDOR_SPACEMIT_ORT_ROOT}/include/onnxruntime_cxx_api.h" AND
   EXISTS "${VENDOR_SPACEMIT_ORT_ROOT}/include/spacemit_ort_env.h")
    set(VENDOR_SPACEMIT_ORT_INCLUDE_DIR "${VENDOR_SPACEMIT_ORT_ROOT}/include")
endif()

if(EXISTS "${VENDOR_SPACEMIT_ORT_ROOT}/lib/libonnxruntime.so")
    set(VENDOR_SPACEMIT_ORT_ONNXRUNTIME "${VENDOR_SPACEMIT_ORT_ROOT}/lib/libonnxruntime.so")
endif()

if(EXISTS "${VENDOR_SPACEMIT_ORT_ROOT}/lib/libspacemit_ep.so")
    set(VENDOR_SPACEMIT_ORT_SPACEMIT_EP "${VENDOR_SPACEMIT_ORT_ROOT}/lib/libspacemit_ep.so")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(VendorSpacemitOrt
    REQUIRED_VARS
        VENDOR_SPACEMIT_ORT_INCLUDE_DIR
        VENDOR_SPACEMIT_ORT_ONNXRUNTIME
        VENDOR_SPACEMIT_ORT_SPACEMIT_EP
)

if(VendorSpacemitOrt_FOUND)
    if(NOT TARGET Vendor::onnxruntime)
        add_library(Vendor::onnxruntime SHARED IMPORTED)
        set_target_properties(Vendor::onnxruntime PROPERTIES
            IMPORTED_LOCATION "${VENDOR_SPACEMIT_ORT_ONNXRUNTIME}"
            INTERFACE_INCLUDE_DIRECTORIES "${VENDOR_SPACEMIT_ORT_INCLUDE_DIR}"
        )
    endif()

    if(NOT TARGET Vendor::spacemit_ep)
        add_library(Vendor::spacemit_ep SHARED IMPORTED)
        set_target_properties(Vendor::spacemit_ep PROPERTIES
            IMPORTED_LOCATION "${VENDOR_SPACEMIT_ORT_SPACEMIT_EP}"
            INTERFACE_INCLUDE_DIRECTORIES "${VENDOR_SPACEMIT_ORT_INCLUDE_DIR}"
        )
    endif()
endif()
