//
//  FTConstants.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTConstants.h"

NSString * const FT_DATA_TYPE_RUM = @"RUM";
NSString * const FT_DATA_TYPE_LOGGING = @"Logging";
NSString * const FT_MEASUREMENT  = @"measurement";
NSString * const FT_FIELDS  = @"fields";
NSString * const FT_TAGS  = @"tags";
NSString * const FT_OPDATA  = @"opdata";
NSString * const FT_OP  = @"op";
// source
NSString * const FT_KEY_SOURCE = @"source";
NSString * const FT_LOGGER_SOURCE = @"df_rum_ios_log";
NSString * const FT_LOGGER_MACOS_SOURCE = @"df_rum_macos_log";

NSString * const FT_RUM_SOURCE_RESOURCE = @"resource";
NSString * const FT_RUM_SOURCE_ERROR = @"error";
NSString * const FT_RUM_SOURCE_VIEW = @"view";
NSString * const FT_RUM_SOURCE_ACTION = @"action";
NSString * const FT_RUM_SOURCE_LONG_TASK = @"long_task";
//service
NSString * const FT_KEY_SERVICE = @"service";
NSString * const FT_DEFAULT_SERVICE_NAME = @"df_rum_ios";
NSString * const FT_IOS_SDK_NAME = @"df_ios_rum_sdk";
NSString * const FT_MACOS_SDK_NAME = @"df_macos_rum_sdk";
NSString * const FT_IS_WEBVIEW = @"is_web_view";
NSString * const FT_NULL_VALUE  = @"N/A";
NSString * const FT_TYPE = @"type";
NSString * const FT_SDK_VERSION = @"sdk_version";
NSString * const FT_SDK_NAME = @"sdk_name";
#pragma mark ========== BASE PROPERTY ==========
NSString * const FT_COMMON_PROPERTY_APP_NAME = @"app_name";
NSString * const FT_COMMON_PROPERTY_OS_VERSION = @"os_version";
NSString * const FT_COMMON_PROPERTY_OS_VERSION_MAJOR = @"os_version_major";
NSString * const FT_IS_SIGNIN = @"is_signin";
NSString * const FT_COMMON_PROPERTY_OS = @"os";
NSString * const FT_COMMON_PROPERTY_DEVICE = @"device";
NSString * const FT_COMMON_PROPERTY_DISPLAY = @"display";
NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL = @"model";
NSString * const FT_SCREEN_SIZE = @"screen_size";
NSString * const FT_CPU_ARCH = @"arch";
NSString * const FT_COMMON_PROPERTY_DEVICE_UUID = @"device_uuid";
NSString * const FT_APPLICATION_UUID = @"application_uuid";
NSString * const FT_ENV = @"env";
NSString * const FT_VERSION = @"version";
#pragma mark ========== RUM ==========
NSString * const FT_TERMINAL_APP = @"app";
NSString * const FT_APP_ID = @"app_id";
NSString * const FT_DURATION  = @"duration";
//session tag
NSString * const FT_RUM_KEY_SESSION_ID = @"session_id";
NSString * const FT_RUM_KEY_SESSION_TYPE = @"session_type";
//view tag
NSString * const FT_KEY_VIEW_ID = @"view_id";
NSString * const FT_KEY_IS_ACTIVE = @"is_active";
NSString * const FT_KEY_VIEW_REFERRER = @"view_referrer";
NSString * const FT_KEY_VIEW_NAME = @"view_name";
//view field
NSString * const FT_KEY_LOADING_TIME = @"loading_time";
NSString * const FT_KEY_TIME_SPENT = @"time_spent";
NSString * const FT_KEY_VIEW_UPDATE_TIME = @"view_update_time";
NSString * const FT_KEY_VIEW_ERROR_COUNT = @"view_error_count";
NSString * const FT_KEY_VIEW_RESOURCE_COUNT = @"view_resource_count";
NSString * const FT_KEY_VIEW_LONG_TASK_COUNT = @"view_long_task_count";
NSString * const FT_KEY_VIEW_ACTION_COUNT = @"view_action_count";
//Device Monitor
NSString * const FT_CPU_TICK_COUNT_PER_SECOND = @"cpu_tick_count_per_second";
NSString * const FT_CPU_TICK_COUNT = @"cpu_tick_count";
NSString * const FT_MEMORY_AVG = @"memory_avg";
NSString * const FT_MEMORY_MAX = @"memory_max";
NSString * const FT_FPS_MINI = @"fps_mini";
NSString * const FT_FPS_AVG = @"fps_avg";

//resource tag
NSString * const FT_KEY_RESOURCE_URL = @"resource_url";
NSString * const FT_KEY_RESOURCE_URL_HOST = @"resource_url_host";
NSString * const FT_KEY_RESOURCE_URL_PATH = @"resource_url_path";
NSString * const FT_KEY_RESOURCE_URL_QUERY = @"resource_url_query";
NSString * const FT_KEY_RESOURCE_URL_PATH_GROUP = @"resource_url_path_group";
NSString * const FT_KEY_RESOURCE_TYPE = @"resource_type";
NSString * const FT_KEY_RESOURCE_METHOD = @"resource_method";
NSString * const FT_KEY_RESOURCE_STATUS = @"resource_status";
NSString * const FT_KEY_RESOURCE_STATUS_GROUP = @"resource_status_group";
NSString * const FT_KEY_RESPONSE_CONNECTION = @"response_connection";
NSString * const FT_KEY_RESPONSE_CONTENT_TYPE = @"response_content_type";
NSString * const FT_KEY_RESPONSE_CONTENT_ENCODING = @"response_content_encoding";
//resource field
NSString * const FT_KEY_RESOURCE_SIZE = @"resource_size";
NSString * const FT_KEY_RESOURCE_DNS = @"resource_dns";
NSString * const FT_KEY_RESOURCE_TCP = @"resource_tcp";
NSString * const FT_KEY_RESOURCE_SSL = @"resource_ssl";
NSString * const FT_KEY_RESOURCE_TTFB = @"resource_ttfb";
NSString * const FT_KEY_RESOURCE_TRANS = @"resource_trans";
NSString * const FT_KEY_RESOURCE_FIRST_BYTE = @"resource_first_byte";
NSString * const FT_KEY_RESPONSE_HEADER = @"response_header";
NSString * const FT_KEY_REQUEST_HEADER = @"request_header";
NSString * const FT_KEY_RESOURCE_HOST_IP = @"resource_host_ip";
//trace link rum tag
NSString * const FT_KEY_TRACEID  = @"trace_id";
NSString * const FT_KEY_SPANID = @"span_id";
//error filed
NSString * const FT_KEY_ERROR_MESSAGE = @"error_message";
NSString * const FT_KEY_ERROR_STACK = @"error_stack";
//error tag
NSString * const FT_KEY_ERROR_SOURCE = @"error_source";
NSString * const FT_KEY_ERROR_TYPE = @"error_type";
NSString * const FT_KEY_ERROR_SITUATION = @"error_situation";
NSString * const FT_KEY_CARRIER = @"carrier";
NSString * const FT_KEY_LOCALE = @"locale";
//error source value
NSString * const FT_NETWORK = @"network";
NSString * const FT_LOGGER = @"logger";
//error type
NSString * const FT_NETWORK_ERROR = @"network_error";

//long task field
NSString * const FT_KEY_LONG_TASK_STACK = @"long_task_stack";

//action field
NSString * const FT_KEY_ACTION_LONG_TASK_COUNT = @"action_long_task_count";
NSString * const FT_KEY_ACTION_RESOURCE_COUNT = @"action_resource_count";
NSString * const FT_KEY_ACTION_ERROR_COUNT = @"action_error_count";
//action tag
NSString * const FT_KEY_ACTION_ID = @"action_id";
NSString * const FT_KEY_ACTION_NAME = @"action_name";
NSString * const FT_KEY_ACTION_TYPE = @"action_type";
NSString * const FT_KEY_ACTION_TYPE_CLICK = @"click";
NSString * const FT_LAUNCH_HOT = @"launch_hot";
NSString * const FT_LAUNCH_COLD = @"launch_cold";
NSString * const FT_LAUNCH_WARM = @"launch_warm";

NSString * const FT_RUM_CUSTOM_KEYS = @"custom_keys";
#pragma mark ========== error monitor ==========
NSString * const FT_MEMORY_TOTAL  = @"memory_total";
NSString * const FT_MEMORY_USE  = @"memory_use";
NSString * const FT_CPU_USE  = @"cpu_use";
NSString * const FT_BATTERY_USE = @"battery_use";

#pragma mark ========== logging key ==========
NSString * const FT_KEY_STATUS = @"status";
NSString * const FT_KEY_CONTENT = @"content";
NSString * const FT_KEY_MESSAGE = @"message";

#pragma mark ==========  network trace key==========

NSString * const FT_NETWORK_ZIPKIN_TRACEID = @"X-B3-TraceId";
NSString * const FT_NETWORK_ZIPKIN_SPANID = @"X-B3-SpanId";
NSString * const FT_NETWORK_ZIPKIN_PARENTSPANID = @"X-B3-ParentSpanId";
NSString * const FT_NETWORK_ZIPKIN_SAMPLED =@"X-B3-Sampled";
NSString * const FT_NETWORK_JAEGER_TRACEID = @"uber-trace-id";
NSString * const FT_NETWORK_DDTRACE_TRACEID = @"x-datadog-trace-id";
NSString * const FT_NETWORK_DDTRACE_SPANID = @"x-datadog-parent-id";
NSString * const FT_NETWORK_DDTRACE_ORIGIN = @"x-datadog-origin";
NSString * const FT_NETWORK_DDTRACE_SAMPLED = @"x-datadog-sampled";
NSString * const FT_NETWORK_DDTRACE_SAMPLING_PRIORITY = @"x-datadog-sampling-priority";
NSString * const FT_NETWORK_SKYWALKING_V3 = @"sw8";
NSString * const FT_NETWORK_SKYWALKING_V2 = @"sw6";
NSString * const FT_NETWORK_TRACEPARENT_KEY = @"traceparent";
NSString * const FT_NETWORK_ZIPKIN_SINGLE_KEY = @"b3";

NSUInteger const FT_LOGGING_CONTENT_SIZE = 30720;
NSUInteger const FT_TIME_INTERVAL = 100;

int const FT_DB_CONTENT_MAX_COUNT = 5000;
int const FT_DB_RUM_MAX_COUNT = 100000;
// 100MB
long const FT_DEFAULT_DB_SIZE_LIMIT = 104857600;
long const FT_MIN_DB_SIZE_LIMIT = 31457280;

NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME = @"ftMobileSdk";
long const FT_DEFAULT_BLOCK_DURATIONS_MS = 250;
long const FT_MINI_DEFAULT_BLOCK_DURATIONS_MS = 100;
long const FT_ANR_THRESHOLD_MS = 5000;

long long const FT_ANR_THRESHOLD_NS = 5000000000;

#pragma mark ==========  user info ==========
NSString * const FT_USER_ID = @"userid";
NSString * const FT_USER_NAME = @"user_name";
NSString * const FT_USER_EMAIL = @"user_email";
NSString * const FT_USER_EXTRA = @"user_extra";
NSString * const FT_USER_INFO = @"FT_USER_INFO";
