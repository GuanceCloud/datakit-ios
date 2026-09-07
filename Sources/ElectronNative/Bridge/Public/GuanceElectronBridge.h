//
//  GuanceElectronBridge.h
//  GuanceElectronBridge
//
//  Electron component C ABI.
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#ifndef GuanceElectronBridge_h
#define GuanceElectronBridge_h

#include <TargetConditionals.h>
#include <stdint.h>

#if TARGET_OS_OSX

#if defined(__GNUC__)
#define GUANCE_ELECTRON_EXPORT __attribute__((visibility("default")))
#else
#define GUANCE_ELECTRON_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

GUANCE_ELECTRON_EXPORT char *guance_electron_invoke(
    const char *method,
    const char *payload_json
);
GUANCE_ELECTRON_EXPORT void guance_electron_free_string(char *value);

GUANCE_ELECTRON_EXPORT int32_t guance_electron_bridge_configuration(
    char *output,
    int32_t capacity
);
GUANCE_ELECTRON_EXPORT int32_t guance_electron_register_web_contents(
    void *electron_view,
    int64_t web_contents_id,
    int64_t slot_id,
    int32_t visible,
    int32_t z_index,
    int32_t has_bounds,
    double x,
    double y,
    double width,
    double height
);
GUANCE_ELECTRON_EXPORT int32_t guance_electron_update_web_contents(
    void *electron_view,
    int64_t web_contents_id,
    int32_t visible,
    int32_t z_index,
    int32_t has_bounds,
    double x,
    double y,
    double width,
    double height
);
GUANCE_ELECTRON_EXPORT int32_t guance_electron_receive_web_contents_message(
    int64_t web_contents_id,
    const char *message_queue
);
GUANCE_ELECTRON_EXPORT void guance_electron_unregister_web_contents(
    int64_t web_contents_id
);

typedef void (*guance_electron_command_callback)(
    int64_t web_contents_id,
    const char *command,
    void *context
);
GUANCE_ELECTRON_EXPORT void guance_electron_set_command_handler(
    guance_electron_command_callback callback,
    void *context
);

#ifdef __cplusplus
}
#endif

#undef GUANCE_ELECTRON_EXPORT

#endif // TARGET_OS_OSX

#endif
