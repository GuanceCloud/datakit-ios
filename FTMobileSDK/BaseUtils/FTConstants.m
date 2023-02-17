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
NSString * const FT_DATA_TYPE_TRACING = @"Tracing";
NSString * const FT_DATA_TYPE_OBJECT = @"Object";
NSString * const FT_MEASUREMENT  = @"measurement";
NSString * const FT_FIELDS  = @"fields";
NSString * const FT_TAGS  = @"tags";
NSString * const FT_AGENT_OPDATA  = @"opdata";
NSString * const FT_AGENT_OP  = @"op";
NSString * const FT_LOGGER_SOURCE = @"df_rum_ios_log";
NSString * const FT_USER_AGENT = @"ft_mobile_sdk_ios";
NSString * const FT_DEFAULT_SERVICE_NAME = @"df_rum_ios";
NSString * const FT_NULL_VALUE  = @"N/A";
NSString * const FT_TYPE = @"type";

NSString * const FT_TERMINAL_APP = @"app";
NSString * const FT_TERMINAL_MINIPROGRA = @"miniprogram";
#pragma mark ========== RUM ==========
NSString * const FT_TYPE_JS = @"js";

NSString * const FT_MEASUREMENT_RUM_RESOURCE = @"resource";
NSString * const FT_MEASUREMENT_RUM_ERROR = @"error";
NSString * const FT_MEASUREMENT_RUM_VIEW = @"view";
NSString * const FT_MEASUREMENT_RUM_ACTION = @"action";
NSString * const FT_MEASUREMENT_RUM_LONG_TASK = @"long_task";

//session tag
NSString * const FT_RUM_KEY_SESSION_ID = @"session_id";
NSString * const FT_RUM_KEY_SESSION_TYPE = @"session_type";

//view field
NSString * const FT_RUM_KEY_LOADING_TIME = @"loading_time";
NSString * const FT_KEY_TIME_SPEND = @"time_spent";
NSString * const FT_KEY_VIEW_ERROR_COUNT = @"view_error_count";
NSString * const FT_KEY_VIEW_RESOURCE_COUNT = @"view_resource_count";
NSString * const FT_KEY_VIEW_LONG_TASK_COUNT = @"view_long_task_count";
NSString * const FT_KEY_VIEW_ACTION_COUNT = @"view_action_count";
//Monitor
NSString * const FT_CPU_TICK_COUNT_PER_SECOND = @"cpu_tick_count_per_second";
NSString * const FT_CPU_TICK_COUNT = @"cpu_tick_count";
NSString * const FT_MEMORY_AVG = @"memory_avg";
NSString * const FT_MEMORY_MAX = @"memory_max";
NSString * const FT_FPS_MINI = @"fps_mini";
NSString * const FT_FPS_AVG = @"fps_avg";
//view tag
NSString * const FT_KEY_VIEW_ID = @"view_id";
NSString * const FT_KEY_IS_ACTIVE = @"is_active";
NSString * const FT_KEY_VIEW_REFERRER = @"view_referrer";
NSString * const FT_KEY_VIEW_NAME = @"view_name";
//resource field
NSString * const FT_RUM_KEY_RESOURCE_SIZE = @"resource_size";
NSString * const FT_RUM_KEY_RESOURCE_DNS = @"resource_dns";
NSString * const FT_RUM_KEY_RESOURCE_TCP = @"resource_tcp";
NSString * const FT_RUM_KEY_RESOURCE_SSL = @"resource_ssl";
NSString * const FT_RUM_KEY_RESOURCE_TTFB = @"resource_ttfb";
NSString * const FT_RUM_KEY_RESOURCE_TRANS = @"resource_trans";
NSString * const FT_RUM_KEY_RESOURCE_FIRST_BYTE = @"resource_first_byte";
//resource tag
NSString * const FT_RUM_KEY_RESOURCE_URL = @"resource_url";
NSString * const FT_RUM_KEY_RESOURCE_URL_HOST = @"resource_url_host";
NSString * const FT_RUM_KEY_RESOURCE_URL_PATH = @"resource_url_path";
NSString * const FT_RUM_KEY_RESOURCE_URL_QUERY = @"resource_url_query";
NSString * const FT_RUM_KEY_RESOURCE_URL_PATH_GROUP = @"resource_url_path_group";
NSString * const FT_RUM_KEY_RESOURCE_TYPE = @"resource_type";
NSString * const FT_RUM_KEY_RESOURCE_METHOD = @"resource_method";
NSString * const FT_RUM_KEY_RESOURCE_STATUS = @"resource_status";
NSString * const FT_RUM_KEY_RESOURCE_STATUS_GROUP = @"resource_status_group";

//error filed
NSString * const FT_RUM_KEY_ERROR_MESSAGE = @"error_message";
NSString * const FT_RUM_KEY_ERROR_STACK = @"error_stack";
//error tag
NSString * const FT_RUM_KEY_ERROR_SOURCE = @"error_source";
NSString * const FT_RUM_KEY_ERROR_TYPE = @"error_type";
NSString * const FT_RUM_KEY_ERROR_SITUATION = @"error_situation";
NSString * const FT_RUM_KEY_NETWORK = @"network";

//long task field
NSString * const FT_RUM_KEY_LONG_TASK_STACK = @"long_task_stack";
NSString * const FT_DURATION  = @"duration";

//action field
NSString * const FT_RUM_KEY_ACTION_LONG_TASK_COUNT = @"action_long_task_count";
NSString * const FT_RUM_KEY_ACTION_RESOURCE_COUNT = @"action_resource_count";
NSString * const FT_RUM_KEY_ACTION_ERROR_COUNT = @"action_error_count";
//action tag
NSString * const FT_RUM_KEY_ACTION_ID = @"action_id";
NSString * const FT_RUM_KEY_ACTION_NAME = @"action_name";
NSString * const FT_RUM_KEY_ACTION_TYPE = @"action_type";
NSString * const FT_RUM_KEY_ACTION_TYPE_CLICK = @"click";

#pragma mark ========== AUTOTRACK  ==========
NSString * const FT_AUTOTRACK_MEASUREMENT  = @"mobile_tracker";
NSString * const FT_KEY_EVENT = @"event";

#pragma mark ========== MONTION ==========
NSString * const FT_MONITOR_MEMORY_TOTAL  = @"memory_total";
NSString * const FT_MONITOR_MEMORY_USE  = @"memory_use";
NSString * const FT_MONITOR_CPU_USE  = @"cpu_use";
NSString * const FT_MONITOR_BATTERY_USE = @"battery_use";
NSString * const FT_MONITOR_DEVICE_NAME  = @"device_name";
NSString * const FT_MONITOR_PROVINCE  = @"province";
NSString * const FT_MONITOR_CITY  = @"city";
NSString * const FT_MONITOR_COUNTRY  = @"country";
NSString * const FT_MONITOR_WITF_SSID  = @"wifi_ssid";
NSString * const FT_MONITOR_NETWORK_STRENGTH  = @"network_strength";

NSString * const FT_NETWORK_CONNECT_TIME = @"connectTime";
NSString * const FT_KEY_HOST = @"host";
NSString * const FT_MONITOR_NETWORK_ERROR_RATE  = @"network_error_rate";
NSString * const FT_MONITOR_NETWORK_PROXY  = @"network_proxy";
NSString * const FT_NETWORK_REQUEST_URL  = @"url";

NSString * const FT_ISERROR = @"isError";
NSString * const FT_MONITOR_GPS_OPEN  = @"gps_open";
NSString * const FT_MONITOR_FPS  = @"fps";
NSString * const FT_MONITOR_BT_OPEN  = @"bt_open";
NSString * const FT_MONITOR_POWER = @"power";

#pragma mark ========== logging key ==========
NSString * const FT_KEY_SOURCE = @"source";
NSString * const FT_KEY_STATUS = @"status";
NSString * const FT_KEY_CONTENT = @"conent";
NSString * const FT_KEY_MESSAGE = @"message";
NSString * const FT_KEY_SPANTYPE = @"span_type";

NSString * const FT_KEY_ENDPOINT = @"endpoint";
#pragma mark ==========  network trace key==========
NSString * const FT_KEY_TRACEID  = @"trace_id";
NSString * const FT_KEY_SPANID = @"span_id";
NSString * const FT_KEY_SERVICE = @"service";
NSString * const FT_KEY_OPERATION = @"operation";
NSString * const FT_APPLICATION_UUID = @"application_UUID";
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

NSString * const FT_NETWORK_HEADERS = @"headers";
NSString * const FT_NETWORK_BODY = @"body";
NSString * const FT_LOGGING_CLASS_TRACING = @"tracing";
NSString * const FT_SPANTYPE_ENTRY = @"entry";
NSString * const FT_NETWORK_REQUEST_CONTENT = @"requestContent";
NSString * const FT_NETWORK_RESPONSE_CONTENT = @"responseContent";
NSString * const FT_NETWORK_CODE = @"code";
NSString * const FT_NETWORK_ERROR = @"error";
NSString * const FT_KEY_TRUE = @"true";
NSString * const FT_KEY_FALSE = @"false";
NSString * const FT_TRACING_STATUS = @"status";

NSUInteger const FT_LOGGING_CONTENT_SIZE = 30720;
NSUInteger const FT_DB_CONTENT_MAX_COUNT = 5000;
NSUInteger const MXRMonitorRunloopOneStandstillMillisecond = 1000;
NSUInteger const MXRMonitorRunloopStandstillCount = 5;
NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME = @"ftMobileSdk";


NSString * const FT_USER_ID = @"userid";
NSString * const FT_USER_NAME = @"user_name";
NSString * const FT_USER_EMAIL = @"user_email";
NSString * const FT_USER_EXTRA = @"user_extra";
NSString * const FT_USER_INFO = @"FT_USER_INFO";
