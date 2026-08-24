/*
 * WinDevices C API
 * Pure C interface for .NET P/Invoke interop
 *
 * This API provides a C interface to the WinDevices C++ library
 * for use with .NET applications via P/Invoke.
 *
 * SAL Annotations Reference:
 * https://docs.microsoft.com/en-us/cpp/code-quality/understanding-sal
 */

#ifndef WINDEVICES_API_H
#define WINDEVICES_API_H

/* Include SAL annotations for better static analysis */
#ifdef _WIN32
#include <sal.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
    #ifdef WINDEVICES_API_EXPORTS
        #define WINDEVICES_API __declspec(dllexport)
    #else
        #define WINDEVICES_API __declspec(dllimport)
    #endif
#else
    #define WINDEVICES_API
    /* Define empty SAL macros for non-Windows platforms */
    #ifndef _In_
        #define _In_
        #define _Out_
        #define _Inout_
        #define _In_opt_
        #define _Out_opt_
        #define _Outptr_
        #define _Ret_maybenull_
        #define _Success_(x)
        #define _Must_inspect_result_
    #endif
#endif

/* Opaque handle types */
/* Using modern C++ 'using' syntax (compatible with C via typedef fallback) */
#ifdef __cplusplus
using HDEVICE_MANAGER = void*;
#else
typedef void* HDEVICE_MANAGER;
#endif

/* GUID structure for device class GUIDs */
typedef struct {
    unsigned long  Data1;
    unsigned short Data2;
    unsigned short Data3;
    unsigned char  Data4[8];
} WD_GUID;

/* Error codes */
typedef enum {
    WD_SUCCESS = 0,
    WD_ERROR_INVALID_HANDLE = -1,
    WD_ERROR_OUT_OF_MEMORY = -2,
    WD_ERROR_NO_DEVICES = -3,
    WD_ERROR_ENUM_FAILED = -4,
    WD_ERROR_INVALID_INDEX = -5,
    WD_ERROR_NULL_POINTER = -6,
    WD_ERROR_UNKNOWN = -99
} WD_RESULT;

/* Device information structure (C-compatible)
 *
 * STRING ENCODING: every char[] field below is UTF-8 encoded and NUL-terminated.
 * They are NOT in the caller's ANSI codepage. Consumers must decode them as UTF-8;
 * decoding them as ANSI corrupts every non-ASCII character (e.g. the German 'a-umlaut'
 * U+00E4 is stored as the two bytes C3 A4 and would otherwise render as 'A-tilde,
 * currency sign'). Strings too long for their buffer are truncated at a character
 * boundary, so the result is always valid UTF-8.
 */
typedef struct {
    char manufacturer[256];
    char product[256];
    char serialNumber[256];
    char description[256];
    char deviceId[512];
    char friendlyName[256];
    char devicePath[512];
    unsigned int vendorId;
    unsigned int productId;
    unsigned int deviceClass;
    unsigned int interfaceClass;
    unsigned int deviceSubClass;
    unsigned int deviceProtocol;
    int isConnected;
    int isUsbDevice;
    WD_GUID deviceClassGuid;
    char vendorName[128];       /* USB-IF registered vendor name from VID lookup */
    char productName[128];      /* USB-IF registered product name from VID/PID lookup */
    char interfaceClassName[64]; /* Human-readable USB Interface Class name */
} WD_DEVICE_INFO;

/* API Version Information */
typedef struct {
    int major;
    int minor;
    int patch;
    const char* buildDate;
} WD_VERSION_INFO;

/* ========== Device Manager Functions ========== */

/**
 * @brief Create a new device manager instance
 * @param handle Pointer to receive the device manager handle
 * @return WD_SUCCESS on success, error code otherwise
 */
_Must_inspect_result_
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_CreateDeviceManager(
    _Outptr_ HDEVICE_MANAGER* handle);

/**
 * @brief Destroy a device manager instance and free resources
 * @param handle Device manager handle to destroy
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_DestroyDeviceManager(
    _In_ HDEVICE_MANAGER handle);

/**
 * @brief Enumerate all USB devices
 * @param handle Device manager handle
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_EnumerateUsbDevices(
    _In_ HDEVICE_MANAGER handle);

/**
 * @brief Enumerate all devices (USB and non-USB)
 * @param handle Device manager handle
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_EnumerateAllDevices(
    _In_ HDEVICE_MANAGER handle);

/**
 * @brief Enumerate devices by Windows Device Setup Class GUID
 * @param handle Device manager handle
 * @param classGuid Pointer to WD_GUID structure containing the device class GUID
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_EnumerateByDeviceClass(
    _In_ HDEVICE_MANAGER handle,
    _In_ const WD_GUID* classGuid);

/**
 * @brief Enumerate external USB mass storage devices only
 * @param handle Device manager handle
 * @return WD_SUCCESS on success, error code otherwise
 *
 * This function enumerates USB devices and filters to only return
 * mass storage devices (USB interface class 0x08). This is useful
 * for DLP solutions that need to monitor removable storage.
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_EnumerateUsbMassStorage(
    _In_ HDEVICE_MANAGER handle);

/**
 * @brief Get the count of enumerated devices
 * @param handle Device manager handle
 * @param count Pointer to receive the device count
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_GetDeviceCount(
    _In_ HDEVICE_MANAGER handle,
    _Out_ int* count);

/**
 * @brief Get device information by index
 * @param handle Device manager handle
 * @param index Zero-based device index
 * @param info Pointer to WD_DEVICE_INFO structure to fill
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_GetDeviceInfo(
    _In_ HDEVICE_MANAGER handle,
    _In_ int index,
    _Out_ WD_DEVICE_INFO* info);

/**
 * @brief Clear all enumerated devices
 * @param handle Device manager handle
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_ClearDevices(
    _In_ HDEVICE_MANAGER handle);

/* ========== Utility Functions ========== */

/**
 * @brief Get human-readable error message for result code
 * @param result Result code to get message for
 * @return Error message string (do not free)
 */
_Ret_maybenull_
WINDEVICES_API const char* WD_GetErrorMessage(
    _In_ WD_RESULT result);

/**
 * @brief Get API version information
 * @param version Pointer to WD_VERSION_INFO structure to fill
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_GetVersion(
    _Out_ WD_VERSION_INFO* version);

/**
 * @brief Get the last error message from the device manager
 * @param handle Device manager handle
 * @return Last error message string (do not free), or NULL if no error
 */
_Ret_maybenull_
WINDEVICES_API const char* WD_GetLastError(
    _In_ HDEVICE_MANAGER handle);

/* ========== Filtering Functions ========== */

/**
 * @brief Filter devices by vendor ID
 * @param handle Device manager handle
 * @param vendorId Vendor ID to filter by (0 to clear filter)
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_FilterByVendorId(
    _In_ HDEVICE_MANAGER handle,
    _In_ unsigned int vendorId);

/**
 * @brief Filter devices by device class
 * @param handle Device manager handle
 * @param deviceClass Device class to filter by (0 to clear filter)
 * @return WD_SUCCESS on success, error code otherwise
 */
_Success_(return == WD_SUCCESS)
WINDEVICES_API WD_RESULT WD_FilterByDeviceClass(
    _In_ HDEVICE_MANAGER handle,
    _In_ unsigned int deviceClass);

#ifdef __cplusplus
}
#endif

#endif /* WINDEVICES_API_H */
