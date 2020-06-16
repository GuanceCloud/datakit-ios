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

NSString * const FT_NULL_VALUE  = @"N/A";

NSString * const FT_FLOW_CHART_PRODUCT  = @"__flow_mobile_activity";
NSString * const FT_KEY_DURATION  = @"__duration";
NSString * const FT_FLOW_TRACEID  = @"__traceId";
NSString * const FT_KEY_NAME  = @"__name";
NSString * const FT_FLOW_PARENT  = @"__parent";


#pragma mark ========== AUTOTRACK  ==========
NSString * const FT_AUTOTRACK_MEASUREMENT  = @"mobile_tracker";
NSString * const FT_AUTO_TRACK_OP_ENTER  = @"enter";
NSString * const FT_AUTO_TRACK_OP_LEAVE  = @"leave";
NSString * const FT_AUTO_TRACK_OP_CLICK  = @"click";
NSString * const FT_AUTO_TRACK_OP_LAUNCH = @"launch";
NSString * const FT_AUTO_TRACK_OP_OPEN  = @"open";
NSString * const FT_AUTO_TRACK_EVENT_ID = @"event_id";
NSString * const FT_AUTO_TRACK_EVENT = @"event";
NSString * const FT_AUTO_TRACK_ROOT_PAGE_NAME = @"root_page_name";
NSString * const FT_AUTO_TRACK_CURRENT_PAGE_NAME = @"current_page_name";
NSString * const FT_AUTO_TRACK_VTP = @"vtp";
NSString * const FT_AUTO_TRACK_VTP_ID = @"vtp_id";
NSString * const FT_AUTO_TRACK_VTP_DESC = @"vtp_desc";
NSString * const FT_AUTO_TRACK_PAGE_DESC = @"page_desc";

#pragma mark ========== comon ==========
NSString * const FT_COMMON_PROPERTY_DEVICE_UUID = @"device_uuid";
NSString * const FT_COMMON_PROPERTY_APPLICATION_IDENTIFIER = @"application_identifier";
NSString * const FT_COMMON_PROPERTY_APPLICATION_NAME = @"application_name";
NSString * const FT_COMMON_PROPERTY_OS = @"os";
NSString * const FT_COMMON_PROPERTY_OS_VERSION = @"os_version";
NSString * const FT_COMMON_PROPERTY_DEVICE_BAND = @"device_band";
NSString * const FT_COMMON_PROPERTY_LOCALE = @"locale";
NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL = @"device_model";
NSString * const FT_COMMON_PROPERTY_DISPLAY = @"display";
NSString * const FT_COMMON_PROPERTY_CARRIER = @"carrier";
NSString * const FT_COMMON_PROPERTY_AGENT = @"agent";
NSString * const FT_COMMON_PROPERTY_AUTOTRACK = @"autoTrack";

#pragma mark ========== MONTION ==========

NSString * const FT_MONITOR_BATTERY_TOTAL  = @"battery_total";
NSString * const FT_MONITOR_BATTERY_USE  = @"battery_use";
NSString * const FT_MONITOR_BATTERY_STATUS  = @"battery_status";

NSString * const FT_MONITOR_MEMORY_TOTAL  = @"memory_total";
NSString * const FT_MONITOR_MEMORY_USE  = @"memory_use";


NSString * const FT_MONITOR_CPU_NO  = @"cpu_no";
NSString * const FT_MONITOR_CPU_HZ  = @"cpu_hz";
NSString * const FT_MONITOR_CPU_USE  = @"cpu_use";


NSString * const FT_MONITOR_GPU_MODEL  = @"gpu_model";
NSString * const FT_MONITOR_GPU_RATE  = @"gpu_rate";

NSString * const FT_MONITOR_CAMERA_FRONT_PX  = @"camera_front_px";
NSString * const FT_MONITOR_CAMERA_BACK_PX  = @"camera_back_px";

NSString * const FT_MONITOR_DEVICE_NAME  = @"device_name";
NSString * const FT_MONITOR_DEVICE_OPEN_TIME  = @"device_open_time";

NSString * const FT_MONITOR_PROVINCE  = @"province";
NSString * const FT_MONITOR_CITY  = @"city";
NSString * const FT_MONITOR_COUNTRY  = @"country";
NSString * const FT_MONITOR_LATITUDE  = @"latitude";
NSString * const FT_MONITOR_LONGITUDE  = @"longitude";


NSString * const FT_MONITOR_WITF_IP  = @"wifi_ip";
NSString * const FT_MONITOR_WITF_SSID  = @"wifi_ssid";
NSString * const FT_MONITOR_NETWORK_TYPE  = @"network_type";
NSString * const FT_MONITOR_NETWORK_STRENGTH  = @"network_strength";
NSString * const FT_MONITOR_NETWORK_IN_RATE  = @"network_in_rate";
NSString * const FT_MONITOR_NETWORK_OUT_RATE  = @"network_out_rate";
NSString * const FT_MONITOR_NETWORK_DNS_TIME  = @"network_dns_time";
NSString * const FT_MONITOR_NETWORK_TCP_TIME  = @"network_tcp_time";
NSString * const FT_MONITOR_NETWORK_RESPONSE_TIME  = @"network_response_time";

NSString * const FT_NETWORK_CONNECT_TIME = @"connectTime";
NSString * const FT_NETWORK_DURATION_TIME =@"duration";

NSString * const FT_MONITOR_FT_NETWORK_DNS_TIME  = @"_network_dns_time";
NSString * const FT_MONITOR_FT_NETWORK_TCP_TIME  = @"_network_tcp_time";
NSString * const FT_MONITOR_FT_NETWORK_RESPONSE_TIME  = @"_network_response_time";
NSString * const FT_MONITOR_NETWORK_ERROR_RATE  = @"network_error_rate";
NSString * const FT_MONITOR_NETWORK_PROXY  = @"network_proxy";
NSString * const FT_NETWORK_REQUEST_URL  = @"url";
NSString * const FT_NETWORK_REQUEST_CONTENT =@"requestContent";
NSString * const FT_NETWORK_RESPONSE_CONTENT =@"responseContent";

NSString * const FT_MONITOR_ROTATION_X  = @"rotation_x";
NSString * const FT_MONITOR_ROTATION_Y  = @"rotation_y";
NSString * const FT_MONITOR_ROTATION_Z  = @"rotation_z";

NSString * const FT_MONITOR_ACCELERATION_X  = @"acceleration_x";
NSString * const FT_MONITOR_ACCELERATION_Y  = @"acceleration_y";
NSString * const FT_MONITOR_ACCELERATION_Z  = @"acceleration_z";

NSString * const FT_MONITOR_MAGNETIC_X  = @"magnetic_x";
NSString * const FT_MONITOR_MAGNETIC_Y  = @"magnetic_y";
NSString * const FT_MONITOR_MAGNETIC_Z  = @"magnetic_z";

NSString * const FT_MONITOR_STEPS  = @"steps";
NSString * const FT_MONITOR_LIGHT  = @"light";
NSString * const FT_MONITOR_ROAM  = @"roam";
NSString * const FT_MONITOR_GPS_OPEN  = @"gps_open";
NSString * const FT_MONITOR_SCREEN_BRIGHTNESS  = @"screen_brightness";
NSString * const FT_MONITOR_PROXIMITY  = @"proximity";
NSString * const FT_MONITOR_FPS  = @"fps";
NSString * const FT_MONITOR_BT_OPEN  = @"bt_open";
NSString * const FT_MONITOR_TORCH  = @"torch";

NSString *const FTBaseInfoHanderDeviceType = @"FTBaseInfoHanderDeviceType";
NSString *const FTBaseInfoHanderDeviceCPUType = @"FTBaseInfoHanderDeviceCPUType";
NSString *const FTBaseInfoHanderDeviceCPUClock = @"FTBaseInfoHanderDeviceCPUClock";
NSString *const FTBaseInfoHanderBatteryTotal = @"FTBaseInfoHanderBatteryTotal";
NSString *const FTBaseInfoHanderDeviceGPUType = @"FTBaseInfoHanderDeviceGPUType";

#pragma mark ========== API ==========
NSString *const FTNetworkingTypeMetrics = @"metrics";
NSString *const FTNetworkingTypeObject = @"object";
NSString *const FTNetworkingTypeKeyevent = @"keyevent";
NSString *const FTNetworkingTypeLogging = @"logging";

NSString *const FT_NETWORKING_API_METRICS = @"/v1/write/metrics";
NSString *const FT_NETWORKING_API_OBJECT = @"/v1/write/object";
NSString *const FT_NETWORKING_API_KEYEVENT = @"/v1/write/keyevent";
NSString *const FT_NETWORKING_API_LOGGING = @"/v1/write/logging";
NSString *const FT_NETWORKING_API_CHECK_TOKEN  = @"/v1/check/token/";
#pragma mark ========== object、keyevent ==========
NSString *const FT_KEYEVENT_MEASUREMENT = @"__keyevent";
NSString *const FT_KEY_EVENTID = @"__eventId";
NSString *const FT_KEY_SOURCE = @"__source";
NSString *const FT_KEY_STATUS = @"__status";
NSString *const FT_KEY_TAGS = @"__tags";
NSString *const FT_KEY_CLASS = @"__class";
NSString *const FT_KEY_CONTENT = @"__content";
NSString *const FT_KEY_SERVICENAME = @"__serviceName";
NSString *const FT_KEY_PARENTID = @"__parentID";
NSString *const FT_KEY_OPERATIONNAME = @"__operationName";
NSString *const FT_KEY_SPANID = @"__spanID";
NSString *const FT_KEY_ISERROR = @"__isError";
NSString *const FT_KEY_RULEID = @"__ruleId";
NSString *const FT_KEY_RULENAME = @"__ruleName";
NSString *const FT_KEY_TYPE = @"__type";
NSString *const FT_KEY_ACTIONTYPE = @"__actionType";
NSString *const FT_KEY_TITLE = @"__title";
NSString *const FT_KEY_SUGGESTION = @"__suggestion";
NSString *const FT_KEY_DISMENSIONS = @"__dimensions";






