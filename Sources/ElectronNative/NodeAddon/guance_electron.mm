#include <node_api.h>

#include "GuanceElectronBridge.h"

#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace {

struct InvokeWork {
  napi_async_work work = nullptr;
  napi_deferred deferred = nullptr;
  std::string method;
  std::string payload;
  std::string result;
  std::string error;
};

struct Command {
  int64_t web_contents_id;
  std::string name;
};

std::mutex command_lock;
napi_threadsafe_function command_function = nullptr;

void Throw(napi_env env, const char* message) {
  napi_throw_error(env, nullptr, message);
}

bool ReadUTF8(napi_env env, napi_value value, std::string* output) {
  size_t length = 0;
  if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
    return false;
  }
  output->resize(length + 1);
  size_t written = 0;
  const bool success = napi_get_value_string_utf8(
      env, value, output->data(), output->size(), &written) == napi_ok;
  output->resize(written);
  return success;
}

bool ReadNativeView(napi_env env, napi_value value, void** native_view) {
  bool is_buffer = false;
  if (napi_is_buffer(env, value, &is_buffer) != napi_ok || !is_buffer) {
    return false;
  }
  void* data = nullptr;
  size_t length = 0;
  if (napi_get_buffer_info(env, value, &data, &length) != napi_ok ||
      length < sizeof(void*)) {
    return false;
  }
  std::memcpy(native_view, data, sizeof(void*));
  return *native_view != nullptr;
}

bool ReadOptionalBounds(
    napi_env env,
    napi_value value,
    int32_t* has_bounds,
    double* x,
    double* y,
    double* width,
    double* height
) {
  napi_valuetype type = napi_undefined;
  if (napi_typeof(env, value, &type) != napi_ok) return false;
  if (type == napi_null || type == napi_undefined) {
    *has_bounds = 0;
    return true;
  }
  if (type != napi_object) return false;
  const char* names[] = {"x", "y", "width", "height"};
  double* values[] = {x, y, width, height};
  for (size_t index = 0; index < 4; ++index) {
    napi_value property = nullptr;
    if (napi_get_named_property(env, value, names[index], &property) != napi_ok ||
        napi_get_value_double(env, property, values[index]) != napi_ok) {
      return false;
    }
  }
  *has_bounds = 1;
  return *width > 0 && *height > 0;
}

void ExecuteInvoke(napi_env, void* data) {
  auto* invocation = static_cast<InvokeWork*>(data);
  char* response = guance_electron_invoke(
      invocation->method.c_str(),
      invocation->payload.c_str()
  );
  if (!response) {
    invocation->error = "Native invocation returned no result";
    return;
  }
  std::string value(response);
  guance_electron_free_string(response);
  if (value.empty()) {
    invocation->error = "Native invocation returned an empty result";
  } else if (value.front() == '0') {
    invocation->result = value.substr(1);
  } else {
    invocation->error = value.substr(1);
  }
}

bool RequiresMainThread(const std::string& method) {
  return method == "sdk.initialize" ||
      method == "rum.configure" ||
      method == "logger.configure" ||
      method == "trace.configure" ||
      method == "sessionReplay.configure" ||
      method == "sdk.shutdown";
}

void CompleteInvoke(napi_env env, napi_status status, void* data) {
  std::unique_ptr<InvokeWork> invocation(static_cast<InvokeWork*>(data));
  if (status != napi_ok && invocation->error.empty()) {
    invocation->error = "Native asynchronous work failed";
  }
  if (!invocation->error.empty()) {
    napi_value message = nullptr;
    napi_value error = nullptr;
    napi_create_string_utf8(
        env,
        invocation->error.c_str(),
        invocation->error.size(),
        &message
    );
    napi_create_error(env, nullptr, message, &error);
    napi_reject_deferred(env, invocation->deferred, error);
  } else {
    napi_value result = nullptr;
    napi_create_string_utf8(
        env,
        invocation->result.c_str(),
        invocation->result.size(),
        &result
    );
    napi_resolve_deferred(env, invocation->deferred, result);
  }
  if (invocation->work) {
    napi_delete_async_work(env, invocation->work);
  }
}

napi_value Invoke(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  auto invocation = std::make_unique<InvokeWork>();
  if (argc != 2 ||
      !ReadUTF8(env, args[0], &invocation->method) ||
      !ReadUTF8(env, args[1], &invocation->payload)) {
    napi_throw_type_error(env, nullptr, "invoke expects method and JSON strings");
    return nullptr;
  }
  napi_value promise = nullptr;
  napi_value resource_name = nullptr;
  napi_create_promise(env, &invocation->deferred, &promise);
  if (RequiresMainThread(invocation->method)) {
    ExecuteInvoke(env, invocation.get());
    CompleteInvoke(env, napi_ok, invocation.release());
    return promise;
  }
  napi_create_string_utf8(env, "GuanceElectronInvoke", NAPI_AUTO_LENGTH, &resource_name);
  if (napi_create_async_work(
          env,
          nullptr,
          resource_name,
          ExecuteInvoke,
          CompleteInvoke,
          invocation.get(),
          &invocation->work) != napi_ok ||
      napi_queue_async_work(env, invocation->work) != napi_ok) {
    Throw(env, "Could not schedule Native invocation");
    return nullptr;
  }
  invocation.release();
  return promise;
}

napi_value GetBridgeConfiguration(napi_env env, napi_callback_info) {
  const int32_t required = guance_electron_bridge_configuration(nullptr, 0);
  if (required <= 1) {
    Throw(env, "Could not read Electron bridge configuration");
    return nullptr;
  }
  std::vector<char> output(static_cast<size_t>(required));
  const int32_t length = guance_electron_bridge_configuration(
      output.data(), static_cast<int32_t>(output.size()));
  if (length < 0) {
    Throw(env, "Could not serialize Electron bridge configuration");
    return nullptr;
  }
  napi_value result = nullptr;
  napi_create_string_utf8(env, output.data(), static_cast<size_t>(length), &result);
  return result;
}

napi_value RegisterWebContents(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  void* view = nullptr;
  int64_t web_contents_id = 0;
  int64_t slot_id = 0;
  bool visible = false;
  int32_t z_index = 0;
  int32_t has_bounds = 0;
  double x = 0, y = 0, width = 0, height = 0;
  if (argc < 5 || argc > 6 ||
      !ReadNativeView(env, args[0], &view) ||
      napi_get_value_int64(env, args[1], &web_contents_id) != napi_ok ||
      napi_get_value_int64(env, args[2], &slot_id) != napi_ok ||
      napi_get_value_bool(env, args[3], &visible) != napi_ok ||
      napi_get_value_int32(env, args[4], &z_index) != napi_ok ||
      (argc == 6 && !ReadOptionalBounds(
          env, args[5], &has_bounds, &x, &y, &width, &height))) {
    napi_throw_type_error(env, nullptr, "Invalid Electron WebContents registration");
    return nullptr;
  }
  const bool registered = guance_electron_register_web_contents(
      view, web_contents_id, slot_id, visible ? 1 : 0, z_index,
      has_bounds, x, y, width, height) == 1;
  napi_value result = nullptr;
  napi_get_boolean(env, registered, &result);
  return result;
}

napi_value UpdateWebContents(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  void* view = nullptr;
  int64_t web_contents_id = 0;
  bool visible = false;
  int32_t z_index = 0;
  int32_t has_bounds = 0;
  double x = 0, y = 0, width = 0, height = 0;
  if (argc < 4 || argc > 5 ||
      !ReadNativeView(env, args[0], &view) ||
      napi_get_value_int64(env, args[1], &web_contents_id) != napi_ok ||
      napi_get_value_bool(env, args[2], &visible) != napi_ok ||
      napi_get_value_int32(env, args[3], &z_index) != napi_ok ||
      (argc == 5 && !ReadOptionalBounds(
          env, args[4], &has_bounds, &x, &y, &width, &height))) {
    napi_throw_type_error(env, nullptr, "Invalid Electron WebContents update");
    return nullptr;
  }
  const bool updated = guance_electron_update_web_contents(
      view, web_contents_id, visible ? 1 : 0, z_index,
      has_bounds, x, y, width, height) == 1;
  napi_value result = nullptr;
  napi_get_boolean(env, updated, &result);
  return result;
}

napi_value ReceiveWebContentsMessage(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t web_contents_id = 0;
  std::string message;
  if (argc != 2 ||
      napi_get_value_int64(env, args[0], &web_contents_id) != napi_ok ||
      !ReadUTF8(env, args[1], &message)) {
    napi_throw_type_error(env, nullptr, "Expected WebContents ID and message string");
    return nullptr;
  }
  napi_value result = nullptr;
  napi_get_boolean(
      env,
      guance_electron_receive_web_contents_message(
          web_contents_id, message.c_str()) == 1,
      &result
  );
  return result;
}

napi_value UnregisterWebContents(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t web_contents_id = 0;
  if (argc != 1 || napi_get_value_int64(env, args[0], &web_contents_id) != napi_ok) {
    napi_throw_type_error(env, nullptr, "Expected a WebContents ID");
    return nullptr;
  }
  guance_electron_unregister_web_contents(web_contents_id);
  napi_value result = nullptr;
  napi_get_undefined(env, &result);
  return result;
}

void CallCommand(napi_env env, napi_value callback, void*, void* data) {
  std::unique_ptr<Command> command(static_cast<Command*>(data));
  if (!env || !callback || !command) return;
  napi_value undefined = nullptr;
  napi_value id = nullptr;
  napi_value name = nullptr;
  napi_get_undefined(env, &undefined);
  napi_create_int64(env, command->web_contents_id, &id);
  napi_create_string_utf8(env, command->name.c_str(), command->name.size(), &name);
  napi_value args[] = {id, name};
  napi_value result = nullptr;
  napi_call_function(env, undefined, callback, 2, args, &result);
}

void ForwardCommand(int64_t id, const char* name, void*) {
  std::lock_guard<std::mutex> lock(command_lock);
  if (!command_function) return;
  auto* command = new Command{id, name ? name : ""};
  if (napi_call_threadsafe_function(
          command_function, command, napi_tsfn_nonblocking) != napi_ok) {
    delete command;
  }
}

void ClearCommandHandler() {
  guance_electron_set_command_handler(nullptr, nullptr);
  std::lock_guard<std::mutex> lock(command_lock);
  if (!command_function) return;
  napi_release_threadsafe_function(command_function, napi_tsfn_abort);
  command_function = nullptr;
}

napi_value SetCommandHandler(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  napi_valuetype type = napi_undefined;
  if (argc != 1 || napi_typeof(env, args[0], &type) != napi_ok ||
      (type != napi_function && type != napi_null)) {
    napi_throw_type_error(env, nullptr, "Expected a callback or null");
    return nullptr;
  }
  ClearCommandHandler();
  if (type == napi_function) {
    napi_value resource_name = nullptr;
    napi_create_string_utf8(
        env, "GuanceElectronCommand", NAPI_AUTO_LENGTH, &resource_name);
    {
      std::lock_guard<std::mutex> lock(command_lock);
      if (napi_create_threadsafe_function(
              env, args[0], nullptr, resource_name, 0, 1, nullptr, nullptr,
              nullptr, CallCommand, &command_function) != napi_ok) {
        Throw(env, "Could not create Native command callback");
        return nullptr;
      }
    }
    guance_electron_set_command_handler(ForwardCommand, nullptr);
  }
  napi_value result = nullptr;
  napi_get_undefined(env, &result);
  return result;
}

void Cleanup(void*) {
  ClearCommandHandler();
}

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor properties[] = {
      {"invoke", nullptr, Invoke, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"getElectronBridgeConfiguration", nullptr, GetBridgeConfiguration, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"registerElectronWebContents", nullptr, RegisterWebContents, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"updateElectronWebContents", nullptr, UpdateWebContents, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"receiveElectronWebContentsMessage", nullptr, ReceiveWebContentsMessage, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"unregisterElectronWebContents", nullptr, UnregisterWebContents, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"setElectronCommandHandler", nullptr, SetCommandHandler, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(
      env, exports, sizeof(properties) / sizeof(properties[0]), properties);
  napi_add_env_cleanup_hook(env, Cleanup, nullptr);
  return exports;
}

}  // namespace

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
