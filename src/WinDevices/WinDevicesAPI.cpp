/*
 * WinDevices C API Implementation
 */

#include "pch.h"
#include "WinDevicesAPI.h"
#include "DevicesManager.h"
#include "DeviceResultantInfo.h"
#include "DeviceInfo.h"
#include "UtilConvert.h"
#include "UsbClassCodes.h"
#include <spdlog/spdlog.h>
#include <memory>
#include <vector>
#include <string>
#include <cstring>

#define API_VERSION_MAJOR 1
#define API_VERSION_MINOR 0
#define API_VERSION_PATCH 0
#define API_BUILD_DATE __DATE__

/* Internal device manager wrapper */
struct DeviceManagerWrapper {
    std::unique_ptr<KDM::DevicesManager> manager;
    std::vector<DeviceResultantInfo> devices;
    std::string lastError;
    unsigned int vendorIdFilter = 0;
    unsigned int deviceClassFilter = 0;
};

/* Helper function to safely copy string to fixed buffer */
static void SafeStrCopy(char* dest, size_t destSize, const std::string& src) {
    if (dest && destSize > 0) {
        size_t copyLen = (std::min)(src.length(), destSize - 1);
        std::memcpy(dest, src.c_str(), copyLen);
        dest[copyLen] = '\0';
    }
}

/* Converts a wide string to UTF-8 and copies it into a fixed-size buffer.
 *
 * The destination always receives a NUL-terminated, *valid* UTF-8 sequence: if the
 * converted text does not fit it is truncated at a character boundary rather than
 * mid-sequence, so a partial multi-byte sequence is never emitted.
 */
static void SafeStrCopy(char* dest, size_t destSize, const std::wstring& src) {
    if (!dest || destSize == 0) {
        return;
    }

    dest[0] = '\0';

    if (src.empty()) {
        return;
    }

    /* Convert into a temporary buffer first. Passing a too-small buffer straight to
     * WideCharToMultiByte does not truncate - it fails with ERROR_INSUFFICIENT_BUFFER
     * and leaves the destination contents undefined. */
    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, src.c_str(), (int)src.length(), NULL, 0, NULL, NULL);
    if (sizeNeeded <= 0) {
        return;
    }

    std::string utf8(static_cast<size_t>(sizeNeeded), '\0');
    int written = WideCharToMultiByte(CP_UTF8, 0, src.c_str(), (int)src.length(),
                                      &utf8[0], sizeNeeded, NULL, NULL);
    if (written <= 0) {
        return;
    }
    utf8.resize(static_cast<size_t>(written));

    size_t copyLen = (std::min)(utf8.size(), destSize - 1);

    /* Back off to a character boundary so a multi-byte sequence is never split.
     * UTF-8 continuation bytes match 10xxxxxx. */
    while (copyLen > 0 && (static_cast<unsigned char>(utf8[copyLen]) & 0xC0) == 0x80) {
        --copyLen;
    }

    std::memcpy(dest, utf8.data(), copyLen);
    dest[copyLen] = '\0';
}

/* Validate handle */
static bool IsValidHandle(HDEVICE_MANAGER handle) {
    return handle != nullptr;
}

/* ========== Device Manager Functions ========== */

WINDEVICES_API WD_RESULT WD_CreateDeviceManager(HDEVICE_MANAGER* handle) {
    if (!handle) {
        spdlog::error("WD_CreateDeviceManager: NULL handle pointer");
        return WD_ERROR_NULL_POINTER;
    }

    try {
        auto wrapper = new DeviceManagerWrapper();
        wrapper->manager = std::make_unique<KDM::DevicesManager>();
        *handle = wrapper;
        
        spdlog::info("Device manager created successfully");
        return WD_SUCCESS;
    }
    catch (const std::bad_alloc&) {
        spdlog::error("WD_CreateDeviceManager: Out of memory");
        return WD_ERROR_OUT_OF_MEMORY;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_CreateDeviceManager: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_DestroyDeviceManager(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_DestroyDeviceManager: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        delete wrapper;
        
        spdlog::info("Device manager destroyed successfully");
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_DestroyDeviceManager: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_EnumerateUsbDevices(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_EnumerateUsbDevices: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->devices.clear();
        
        wrapper->manager->EnumerateUsbDevices();
        wrapper->devices = wrapper->manager->GetDevices();
        
        spdlog::info("Enumerated {} USB devices", wrapper->devices.size());
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->lastError = std::string("Exception: ") + e.what();
        spdlog::error("WD_EnumerateUsbDevices: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_EnumerateAllDevices(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_EnumerateAllDevices: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->devices.clear();

        // For now, just enumerate USB devices since that's what's implemented
        wrapper->manager->EnumerateUsbDevices();
        wrapper->devices = wrapper->manager->GetDevices();

        spdlog::info("Enumerated {} devices", wrapper->devices.size());
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->lastError = std::string("Exception: ") + e.what();
        spdlog::error("WD_EnumerateAllDevices: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_EnumerateByDeviceClass(HDEVICE_MANAGER handle, const WD_GUID* classGuid) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_EnumerateByDeviceClass: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    if (!classGuid) {
        spdlog::error("WD_EnumerateByDeviceClass: NULL classGuid pointer");
        return WD_ERROR_NULL_POINTER;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->devices.clear();

        // Convert WD_GUID to Windows GUID
        GUID deviceClassGuid;
        deviceClassGuid.Data1 = classGuid->Data1;
        deviceClassGuid.Data2 = classGuid->Data2;
        deviceClassGuid.Data3 = classGuid->Data3;
        std::memcpy(deviceClassGuid.Data4, classGuid->Data4, sizeof(deviceClassGuid.Data4));

        spdlog::info("WD_EnumerateByDeviceClass: Enumerating devices with class GUID: {{{:08X}-{:04X}-{:04X}-{:02X}{:02X}-{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}}}",
            deviceClassGuid.Data1, deviceClassGuid.Data2, deviceClassGuid.Data3,
            deviceClassGuid.Data4[0], deviceClassGuid.Data4[1], deviceClassGuid.Data4[2], deviceClassGuid.Data4[3],
            deviceClassGuid.Data4[4], deviceClassGuid.Data4[5], deviceClassGuid.Data4[6], deviceClassGuid.Data4[7]);

        wrapper->manager->EnumerateByDeviceClass(deviceClassGuid);
        wrapper->devices = wrapper->manager->GetDevices();

        spdlog::info("Enumerated {} devices by class", wrapper->devices.size());
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->lastError = std::string("Exception: ") + e.what();
        spdlog::error("WD_EnumerateByDeviceClass: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_EnumerateUsbMassStorage(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_EnumerateUsbMassStorage: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->devices.clear();

        // First enumerate all USB devices to get interface class from USB descriptors
        wrapper->manager->EnumerateUsbDevices();
        auto allDevices = wrapper->manager->GetDevices();

        // Filter to only mass storage devices using USB Interface Class
        // This is the correct way to detect mass storage - NOT using Windows Setup Class GUID
        // because the same device can appear under multiple Windows device classes (e.g., WPD)
        // Reference: https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/supported-usb-classes

        for (const auto& device : allDevices) {
            // Use USB interface class from the USB descriptor - this is authoritative
            // Device class at device level is often 0x00 (interface-defined)
            if (KDM::IsMassStorageClass(device.GetInterfaceClass()) ||
                KDM::IsMassStorageClass(device.GetDeviceClass())) {
                wrapper->devices.push_back(device);
            }
        }

        spdlog::info("WD_EnumerateUsbMassStorage: Found {} mass storage device(s) out of {} USB devices",
            wrapper->devices.size(), allDevices.size());
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->lastError = std::string("Exception: ") + e.what();
        spdlog::error("WD_EnumerateUsbMassStorage: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_GetDeviceCount(HDEVICE_MANAGER handle, int* count) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_GetDeviceCount: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    if (!count) {
        spdlog::error("WD_GetDeviceCount: NULL count pointer");
        return WD_ERROR_NULL_POINTER;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        *count = static_cast<int>(wrapper->devices.size());
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_GetDeviceCount: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_GetDeviceInfo(HDEVICE_MANAGER handle, int index, WD_DEVICE_INFO* info) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_GetDeviceInfo: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }
    
    if (!info) {
        spdlog::error("WD_GetDeviceInfo: NULL info pointer");
        return WD_ERROR_NULL_POINTER;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        
        if (index < 0 || index >= static_cast<int>(wrapper->devices.size())) {
            spdlog::error("WD_GetDeviceInfo: Invalid index {}", index);
            return WD_ERROR_INVALID_INDEX;
        }

        const auto& deviceResult = wrapper->devices[index];
        std::memset(info, 0, sizeof(WD_DEVICE_INFO));

        // Copy device info from DeviceResultantInfo
        SafeStrCopy(info->manufacturer, sizeof(info->manufacturer), deviceResult.GetManufacturer());
        SafeStrCopy(info->product, sizeof(info->product), deviceResult.GetProduct());
        SafeStrCopy(info->serialNumber, sizeof(info->serialNumber), deviceResult.GetSerialNumber());
        SafeStrCopy(info->description, sizeof(info->description), deviceResult.GetDescription());
        SafeStrCopy(info->deviceId, sizeof(info->deviceId), deviceResult.GetDeviceId());
        SafeStrCopy(info->friendlyName, sizeof(info->friendlyName), deviceResult.GetFriendlyName());
        SafeStrCopy(info->devicePath, sizeof(info->devicePath), deviceResult.GetDevicePath());

        // Copy all available numeric fields
        info->isUsbDevice = deviceResult.IsUsbDevice() ? 1 : 0;
        info->isConnected = deviceResult.IsConnected() ? 1 : 0;
        info->deviceClass = deviceResult.GetDeviceClass();
        info->interfaceClass = deviceResult.GetInterfaceClass();  // USB interface class from descriptor
        info->vendorId = deviceResult.GetVendorId();
        info->productId = deviceResult.GetProductId();

        // Copy the device class GUID
        const GUID& setupGuid = deviceResult.GetSetupClassGuid();
        info->deviceClassGuid.Data1 = setupGuid.Data1;
        info->deviceClassGuid.Data2 = setupGuid.Data2;
        info->deviceClassGuid.Data3 = setupGuid.Data3;
        std::memcpy(info->deviceClassGuid.Data4, setupGuid.Data4, sizeof(info->deviceClassGuid.Data4));

        // Copy vendor name (from USB-IF vendor database) and interface class name
        SafeStrCopy(info->vendorName, sizeof(info->vendorName), deviceResult.GetVendorName());
        SafeStrCopy(info->interfaceClassName, sizeof(info->interfaceClassName), deviceResult.GetInterfaceClassName());

        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->lastError = std::string("Exception: ") + e.what();
        spdlog::error("WD_GetDeviceInfo: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_ClearDevices(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_ClearDevices: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->devices.clear();
        wrapper->lastError.clear();
        
        spdlog::info("Devices cleared");
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_ClearDevices: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

/* ========== Utility Functions ========== */

WINDEVICES_API const char* WD_GetErrorMessage(WD_RESULT result) {
    switch (result) {
        case WD_SUCCESS:
            return "Success";
        case WD_ERROR_INVALID_HANDLE:
            return "Invalid handle";
        case WD_ERROR_OUT_OF_MEMORY:
            return "Out of memory";
        case WD_ERROR_NO_DEVICES:
            return "No devices found";
        case WD_ERROR_ENUM_FAILED:
            return "Device enumeration failed";
        case WD_ERROR_INVALID_INDEX:
            return "Invalid device index";
        case WD_ERROR_NULL_POINTER:
            return "NULL pointer argument";
        case WD_ERROR_UNKNOWN:
            return "Unknown error";
        default:
            return "Unrecognized error code";
    }
}

WINDEVICES_API WD_RESULT WD_GetVersion(WD_VERSION_INFO* version) {
    if (!version) {
        return WD_ERROR_NULL_POINTER;
    }

    version->major = API_VERSION_MAJOR;
    version->minor = API_VERSION_MINOR;
    version->patch = API_VERSION_PATCH;
    version->buildDate = API_BUILD_DATE;

    return WD_SUCCESS;
}

WINDEVICES_API const char* WD_GetLastError(HDEVICE_MANAGER handle) {
    if (!IsValidHandle(handle)) {
        return "Invalid handle";
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        return wrapper->lastError.empty() ? nullptr : wrapper->lastError.c_str();
    }
    catch (...) {
        return "Exception getting last error";
    }
}

/* ========== Filtering Functions ========== */

WINDEVICES_API WD_RESULT WD_FilterByVendorId(HDEVICE_MANAGER handle, unsigned int vendorId) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_FilterByVendorId: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->vendorIdFilter = vendorId;
        
        spdlog::info("Vendor ID filter set to: 0x{:04X}", vendorId);
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_FilterByVendorId: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}

WINDEVICES_API WD_RESULT WD_FilterByDeviceClass(HDEVICE_MANAGER handle, unsigned int deviceClass) {
    if (!IsValidHandle(handle)) {
        spdlog::error("WD_FilterByDeviceClass: Invalid handle");
        return WD_ERROR_INVALID_HANDLE;
    }

    try {
        auto wrapper = static_cast<DeviceManagerWrapper*>(handle);
        wrapper->deviceClassFilter = deviceClass;
        
        spdlog::info("Device class filter set to: 0x{:02X}", deviceClass);
        return WD_SUCCESS;
    }
    catch (const std::exception& e) {
        spdlog::error("WD_FilterByDeviceClass: Exception: {}", e.what());
        return WD_ERROR_UNKNOWN;
    }
}
