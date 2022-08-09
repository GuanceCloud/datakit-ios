//
//  FTConstants.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>



#pragma mark ========== agent ==========
extern NSString * const FT_DATA_TYPE_RUM;
extern NSString * const FT_DATA_TYPE_LOGGING;
extern NSString * const FT_DATA_TYPE_TRACING;
extern NSString * const FT_DATA_TYPE_OBJECT;

extern NSString * const FT_MEASUREMENT;
extern NSString * const FT_FIELDS;
extern NSString * const FT_TAGS;
extern NSString * const FT_AGENT_OPDATA;
extern NSString * const FT_AGENT_OP;
extern NSString * const FT_USER_AGENT;
extern NSString * const FT_DEFAULT_SERVICE_NAME;
extern NSString * const FT_LOGGER_SOURCE;
extern NSString * const FT_NULL_VALUE;
extern NSString * const FT_TYPE;
extern NSString * const FT_AUTO_TRACK_OP_LAUNCH;

extern NSString * const FT_TYPE_JS;
extern NSString * const FT_MEASUREMENT_RUM_RESOURCE;
extern NSString * const FT_MEASUREMENT_RUM_ERROR;
extern NSString * const FT_MEASUREMENT_RUM_ACTION ;
extern NSString * const FT_MEASUREMENT_RUM_LONG_TASK;
extern NSString * const FT_MEASUREMENT_RUM_VIEW;

extern NSString * const FT_RUM_KEY_SESSION_ID;
extern NSString * const FT_RUM_KEY_SESSION_TYPE;

extern NSString * const FT_RUM_KEY_LOADING_TIME;
extern NSString * const FT_KEY_TIME_SPEND;
extern NSString * const FT_KEY_VIEW_ERROR_COUNT;
extern NSString * const FT_KEY_VIEW_RESOURCE_COUNT;
extern NSString * const FT_KEY_VIEW_LONG_TASK_COUNT;
extern NSString * const FT_KEY_VIEW_ACTION_COUNT;

//Monitor
extern NSString * const FT_CPU_TICK_COUNT_PER_SECOND;
extern NSString * const FT_CPU_TICK_COUNT;
extern NSString * const FT_MEMORY_AVG;
extern NSString * const FT_MEMORY_MAX;
extern NSString * const FT_FPS_MINI;
extern NSString * const FT_FPS_AVG;

extern NSString * const FT_KEY_VIEW_ID;
extern NSString * const FT_KEY_IS_ACTIVE;
extern NSString * const FT_KEY_VIEW_REFERRER;
extern NSString * const FT_KEY_VIEW_NAME;

extern NSString * const FT_RUM_KEY_RESOURCE_SIZE;
extern NSString * const FT_RUM_KEY_RESOURCE_DNS;
extern NSString * const FT_RUM_KEY_RESOURCE_TCP;
extern NSString * const FT_RUM_KEY_RESOURCE_SSL;
extern NSString * const FT_RUM_KEY_RESOURCE_TTFB;
extern NSString * const FT_RUM_KEY_RESOURCE_TRANS;
extern NSString * const FT_RUM_KEY_RESOURCE_FIRST_BYTE;
extern NSString * const FT_RUM_KEY_RESOURCE_URL;
extern NSString * const FT_RUM_KEY_RESOURCE_URL_HOST;
extern NSString * const FT_RUM_KEY_RESOURCE_URL_PATH;
extern NSString * const FT_RUM_KEY_RESOURCE_URL_QUERY;
extern NSString * const FT_RUM_KEY_RESOURCE_URL_PATH_GROUP;
extern NSString * const FT_RUM_KEY_RESOURCE_TYPE;
extern NSString * const FT_RUM_KEY_RESOURCE_METHOD;
extern NSString * const FT_RUM_KEY_RESOURCE_STATUS;
extern NSString * const FT_RUM_KEY_RESOURCE_STATUS_GROUP;

extern NSString * const FT_RUM_KEY_ERROR_MESSAGE;
extern NSString * const FT_RUM_KEY_ERROR_STACK;
extern NSString * const FT_RUM_KEY_ERROR_SOURCE;
extern NSString * const FT_RUM_KEY_ERROR_TYPE;
extern NSString * const FT_RUM_KEY_ERROR_SITUATION;
extern NSString * const FT_RUM_KEY_NETWORK;

extern NSString * const FT_RUM_KEY_LONG_TASK_STACK;

extern NSString * const FT_RUM_KEY_ACTION_LONG_TASK_COUNT;
extern NSString * const FT_RUM_KEY_ACTION_RESOURCE_COUNT;
extern NSString * const FT_RUM_KEY_ACTION_ERROR_COUNT;
extern NSString * const FT_RUM_KEY_ACTION_ID;
extern NSString * const FT_RUM_KEY_ACTION_NAME;
extern NSString * const FT_RUM_KEY_ACTION_TYPE;

extern NSString * const FT_TERMINAL_APP;
extern NSString * const FT_TERMINAL_MINIPROGRA;

#pragma mark ========== logging key ==========
extern NSString * const FT_KEY_STATUS;
extern NSString * const FT_KEY_SOURCE;
extern NSString * const FT_KEY_CONTENT;
extern NSString * const FT_KEY_MESSAGE;
extern NSString * const FT_KEY_SPANTYPE;
extern NSString * const FT_DURATION;

extern NSString * const FT_AUTOTRACK_MEASUREMENT;
extern NSString * const FT_KEY_EVENT;

extern NSString * const FT_MONITOR_MEMORY_TOTAL;
extern NSString * const FT_MONITOR_MEMORY_USE;
extern NSString * const FT_MONITOR_CPU_USAGE;
extern NSString * const FT_MONITOR_MEM_USAGE;
extern NSString * const FT_MONITOR_POWER;
extern NSString * const FT_MONITOR_CAMERA_FRONT_PX;
extern NSString * const FT_MONITOR_CAMERA_BACK_PX;
extern NSString * const FT_MONITOR_DEVICE_NAME;
extern NSString * const FT_MONITOR_PROVINCE;
extern NSString * const FT_MONITOR_CITY;
extern NSString * const FT_MONITOR_COUNTRY;
#pragma mark ------ NETWORK -------
extern NSString * const FT_KEY_TRACEID;
extern NSString * const FT_KEY_SPANID;
extern NSString * const FT_MONITOR_WITF_SSID;
extern NSString * const FT_MONITOR_NETWORK_STRENGTH;
extern NSString * const FT_MONITOR_NETWORK_ERROR_RATE;
extern NSString * const FT_MONITOR_NETWORK_PROXY;
extern NSString * const FT_TRACING_STATUS;
extern NSString * const FT_KEY_SERVICE;
extern NSString * const FT_KEY_OPERATION;
extern NSString * const FT_NETWORK_REQUEST_URL;
extern NSString * const FT_NETWORK_CONNECT_TIME;
extern NSString * const FT_KEY_HOST;
extern NSString * const FT_ISERROR;
extern NSString * const FT_MONITOR_GPS_OPEN;
extern NSString * const FT_MONITOR_FPS;
extern NSString * const FT_MONITOR_BT_OPEN;

#pragma mark ========== logging network trace key ==========
extern NSString * const FT_APPLICATION_UUID;
extern NSString * const FT_NETWORK_ZIPKIN_TRACEID;
extern NSString * const FT_NETWORK_ZIPKIN_SPANID;
extern NSString * const FT_NETWORK_ZIPKIN_PARENTSPANID;
extern NSString * const FT_NETWORK_ZIPKIN_SAMPLED;
extern NSString * const FT_NETWORK_SKYWALKING_V3;
extern NSString * const FT_NETWORK_SKYWALKING_V2;
extern NSString * const FT_NETWORK_JAEGER_TRACEID;
extern NSString * const FT_NETWORK_REQUEST_CONTENT;
extern NSString * const FT_NETWORK_RESPONSE_CONTENT;
extern NSString * const FT_NETWORK_DDTRACE_TRACEID;
extern NSString * const FT_NETWORK_DDTRACE_SPANID;
extern NSString * const FT_NETWORK_DDTRACE_ORIGIN;
extern NSString * const FT_NETWORK_DDTRACE_SAMPLED;
extern NSString * const FT_NETWORK_DDTRACE_SAMPLING_PRIORITY;
extern NSString * const FT_NETWORK_TRACEPARENT_KEY;
extern NSString * const FT_NETWORK_ZIPKIN_SINGLE_KEY;

extern NSString * const FT_NETWORK_HEADERS;
extern NSString * const FT_NETWORK_BODY;
extern NSString * const FT_LOGGING_CLASS_TRACING;
extern NSString * const FT_KEY_TRUE;
extern NSString * const FT_KEY_FALSE;
extern NSString * const FT_NETWORK_CODE;
extern NSString * const FT_NETWORK_ERROR;
extern NSString * const FT_SPANTYPE_ENTRY;
extern NSUInteger const FT_LOGGING_CONTENT_SIZE;
extern NSUInteger const FT_DB_CONTENT_MAX_COUNT;

#pragma mark ========== user info key ==========
extern NSString * const FT_USER_INFO;
extern NSString * const FT_USER_ID;
extern NSString * const FT_USER_NAME;
extern NSString * const FT_USER_EXTRA;

// default 5s 记录一次ANR
// 超过多少毫秒为一次卡顿
extern NSUInteger const MXRMonitorRunloopOneStandstillMillisecond;
// 多少次卡顿纪录为一次有效卡顿
extern NSUInteger const  MXRMonitorRunloopStandstillCount;
extern NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME;

