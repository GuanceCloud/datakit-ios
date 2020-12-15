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
NSString * const FT_USER_AGENT = @"ft_mobile_sdk_ios";
NSString * const FT_DEFAULT_SERVICE_NAME = @"dataflux sdk";
NSString * const FT_NULL_VALUE  = @"N/A";
NSString * const FT_TYPE = @"type";
NSString * const FT_AUTO_TRACK_OP_LAUNCH = @"launch";

NSString * const FT_TERMINAL_APP = @"app";
NSString * const FT_TERMINAL_MINIPROGRA = @"miniprogram";
#pragma mark ========== InfluxDB 指标集==========
NSString * const FT_RUM_WEB_PAGE_PERFORMANCE = @"rum_web_page_performance";
NSString * const FT_RUM_WEB_RESOURCE_PERFORMANCE = @"rum_web_resource_performance";
NSString * const FT_RUM_APP_STARTUP = @"rum_app_startup";
NSString * const FT_RUM_APP_VIEW = @"rum_app_view";
NSString * const FT_RUM_APP_FREEZE = @"rum_app_freeze";
NSString * const FT_RUM_APP_RESOURCE_PERFORMANCE = @"rum_app_resource_performance";
#pragma mark ========== ES ==========
NSString * const FT_TYPE_JS = @"js";
NSString * const FT_TYPE_PAGE = @"page";
NSString * const FT_TYPE_RESOURCE = @"resource";
NSString * const FT_TYPE_CRASH = @"crash";
NSString * const FT_TYPE_FREEZE = @"freeze";
NSString * const FT_TYPE_VIEW = @"view";
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
NSString *const FTBaseInfoHanderDeviceCPUType = @"FTBaseInfoHanderDeviceCPUType";
NSString *const FTBaseInfoHanderDeviceCPUClock = @"FTBaseInfoHanderDeviceCPUClock";
NSString *const FTBaseInfoHanderBatteryTotal = @"FTBaseInfoHanderBatteryTotal";
NSString *const FTBaseInfoHanderDeviceGPUType = @"FTBaseInfoHanderDeviceGPUType";

#pragma mark ========== API ==========
NSString *const FT_DATA_TYPE_RUM = @"RUM";
NSString *const FT_DATA_TYPE_ES = @"ES";
NSString *const FT_DATA_TYPE_INFLUXDB = @"InfluxDB";
NSString *const FT_DATA_TYPE_LOGGING = @"Logging";
NSString *const FT_DATA_TYPE_OBJECT = @"Object";
NSString *const FT_NETWORKING_API_METRICS = @"/v1/write/metric";
NSString *const FT_NETWORKING_API_LOGGING = @"/v1/write/logging";
NSString *const FT_NETWORKING_API_CHECK_TOKEN  = @"/v1/check/token/";
NSString *const FT_NETWORKING_API_RUM = @"/v1/write/rum";
NSString *const FT_NETWORKING_API_OBJECT = @"/v1/write/object";

#pragma mark ========== logging key ==========
NSString *const FT_KEY_SOURCE = @"__source";
NSString *const FT_KEY_SERVICENAME = @"__serviceName";
NSString *const FT_KEY_STATUS = @"__status";
NSString *const FT_KEY_CONTENT = @"__content";
NSString *const FT_KEY_OPERATIONNAME = @"__operationName";
NSString *const FT_KEY_CLASS = @"__class";
NSString *const FT_KEY_ISERROR = @"__isError";
NSString *const FT_KEY_SPANTYPE = @"__spanType";
NSString *const FT_KEY_DURATION  = @"__duration";
NSString *const FT_FLOW_TRACEID  = @"__traceID";
NSString *const FT_KEY_SPANID = @"__spanID";
#pragma mark ========== logging network trace key==========
NSString *const FT_APPLICATION_UUID = @"application_UUID";
NSString *const FT_NETWORK_ZIPKIN_TRACEID = @"X-B3-TraceId";
NSString *const FT_NETWORK_ZIPKIN_SPANID = @"X-B3-SpanId";
NSString *const FT_NETWORK_ZIPKIN_SAMPLED =@"X-B3-Sampled";
NSString *const FT_NETWORK_JAEGER_TRACEID = @"uber-trace-id";
NSString *const FT_NETWORK_SKYWALKING_V3 = @"sw8";
NSString *const FT_NETWORK_SKYWALKING_V2 = @"sw6";
NSString *const FT_NETWORK_HEADERS = @"headers";
NSString *const FT_NETWORK_BODY = @"body";
NSString *const FT_LOGGING_CLASS_TRACING = @"tracing";
NSString *const FT_SPANTYPE_ENTRY = @"entry";
NSString *const FT_NETWORK_REQUEST_CONTENT = @"requestContent";
NSString *const FT_NETWORK_RESPONSE_CONTENT = @"responseContent";
NSString *const FT_NETWORK_CODE = @"code";
NSString *const FT_NETWORK_ERROR = @"error";
NSString *const FT_KEY_TRUE = @"true";
NSString *const FT_KET_FALSE = @"false";

NSUInteger const FT_LOGGING_CONTENT_SIZE = 30720;
NSUInteger const FT_DB_CONTENT_MAX_COUNT = 5000;
NSUInteger const MXRMonitorRunloopOneStandstillMillisecond = 1000;
NSUInteger const MXRMonitorRunloopStandstillCount = 5;
