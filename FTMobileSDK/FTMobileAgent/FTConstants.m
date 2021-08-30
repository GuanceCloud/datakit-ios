//
//  FTConstants.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTConstants.h"

NSString * const FT_AGENT_MEASUREMENT  = @"measurement";
NSString * const FT_AGENT_FIELD  = @"field";
NSString * const FT_AGENT_TAGS  = @"tags";
NSString * const FT_AGENT_OPDATA  = @"opdata";
NSString * const FT_AGENT_OP  = @"op";
NSString * const FT_LOGGER_SOURCE = @"df_rum_ios_log";
NSString * const FT_USER_AGENT = @"ft_mobile_sdk_ios";
NSString * const FT_DEFAULT_SERVICE_NAME = @"df_rum_ios";
NSString * const FT_NULL_VALUE  = @"N/A";
NSString * const FT_TYPE = @"type";
NSString * const FT_AUTO_TRACK_OP_LAUNCH = @"launch";

NSString * const FT_TERMINAL_APP = @"app";
NSString * const FT_TERMINAL_MINIPROGRA = @"miniprogram";
#pragma mark ========== InfluxDB 指标集==========
NSString * const FT_RUM_APP_STARTUP = @"rum_app_startup";
NSString * const FT_RUM_APP_VIEW = @"rum_app_view";
NSString * const FT_RUM_APP_FREEZE = @"rum_app_freeze";
#pragma mark ========== ES ==========
NSString * const FT_TYPE_JS = @"js";
NSString * const FT_TYPE_PAGE = @"page";
NSString * const FT_TYPE_RESOURCE = @"resource";
NSString * const FT_TYPE_ERROR = @"error";
NSString * const FT_TYPE_FREEZE = @"freeze";
NSString * const FT_TYPE_VIEW = @"view";
//NSString * const FT_TYPE_ERROR = @"error";
NSString * const FT_TYPE_ACTION = @"action";
NSString * const FT_TYPE_LONG_TASK = @"long_task";

#pragma mark ========== AUTOTRACK  ==========
NSString * const FT_AUTOTRACK_MEASUREMENT  = @"mobile_tracker";
NSString * const FT_KEY_EVENT = @"event";

#pragma mark ========== MONTION ==========
NSString * const FT_MONITOR_MEMORY_TOTAL  = @"memory_total";
NSString * const FT_MONITOR_MEMORY_USE  = @"memory_use";
NSString * const FT_MONITOR_DEVICE_NAME  = @"device_name";
NSString * const FT_MONITOR_PROVINCE  = @"province";
NSString * const FT_MONITOR_CITY  = @"city";
NSString * const FT_MONITOR_COUNTRY  = @"country";
NSString * const FT_MONITOR_LATITUDE  = @"latitude";
NSString * const FT_MONITOR_LONGITUDE  = @"longitude";
NSString * const FT_MONITOR_WITF_SSID  = @"wifi_ssid";
NSString * const FT_MONITOR_NETWORK_STRENGTH  = @"network_strength";

NSString * const FT_NETWORK_CONNECT_TIME = @"connectTime";
NSString * const FT_DURATION_TIME =@"duration";
NSString * const FT_KEY_HOST = @"host";
NSString * const FT_MONITOR_NETWORK_ERROR_RATE  = @"network_error_rate";
NSString * const FT_MONITOR_NETWORK_PROXY  = @"network_proxy";
NSString * const FT_NETWORK_REQUEST_URL  = @"url";

NSString * const FT_ISERROR = @"isError";
NSString * const FT_MONITOR_GPS_OPEN  = @"gps_open";
NSString * const FT_MONITOR_FPS  = @"fps";
NSString * const FT_MONITOR_BT_OPEN  = @"bt_open";
NSString * const FT_MONITOR_CPU_USAGE = @"cpu_usage";
NSString * const FT_MONITOR_MEM_USAGE = @"mem_usage";
NSString * const FT_MONITOR_POWER = @"power";

#pragma mark ========== logging key ==========
NSString * const FT_KEY_SOURCE = @"source";
NSString * const FT_KEY_STATUS = @"status";
NSString * const FT_KEY_CONTENT = @"conent";
NSString * const FT_KEY_MESSAGE = @"message";
NSString * const FT_KEY_SPANTYPE = @"span_type";
NSString * const FT_KEY_DURATION  = @"duration";
NSString * const FT_FLOW_TRACEID  = @"trace_id";
NSString * const FT_KEY_SPANID = @"span_id";
NSString * const FT_KEY_ENDPOINT = @"endpoint";
#pragma mark ==========  network trace key==========
NSString * const FT_KEY_SERVICE = @"service";
NSString * const FT_KEY_OPERATION = @"operation";
NSString * const FT_APPLICATION_UUID = @"application_UUID";
NSString * const FT_NETWORK_ZIPKIN_TRACEID = @"X-B3-TraceId";
NSString * const FT_NETWORK_ZIPKIN_SPANID = @"X-B3-SpanId";
NSString * const FT_NETWORK_ZIPKIN_SAMPLED =@"X-B3-Sampled";
NSString * const FT_NETWORK_JAEGER_TRACEID = @"uber-trace-id";
NSString * const FT_NETWORK_DDTRACE_TRACEID = @"x-datadog-trace-id";
NSString * const FT_NETWORK_DDTRACE_SPANID = @"x-datadog-parent-id";
NSString * const FT_NETWORK_DDTRACE_ORIGIN = @"x-datadog-origin";
NSString * const FT_NETWORK_DDTRACE_SAMPLED = @"x-datadog-sampling-priority";
NSString * const FT_NETWORK_SKYWALKING_V3 = @"sw8";
NSString * const FT_NETWORK_SKYWALKING_V2 = @"sw6";
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


