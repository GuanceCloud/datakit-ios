//
//  FTConstants.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
/// SDK 常量声明
#pragma mark ========== agent ==========
extern NSString * const FT_DATA_TYPE_RUM;
extern NSString * const FT_DATA_TYPE_LOGGING;
extern NSString * const FT_DATA_TYPE_RUM_CACHE;
extern NSString * const FT_KEY_SERVICE;
extern NSString * const FT_MEASUREMENT;
extern NSString * const FT_FIELDS;
extern NSString * const FT_TAGS;
extern NSString * const FT_OPDATA;
extern NSString * const FT_OP;
extern NSString * const FT_TIME;
extern NSString * const FT_DEFAULT_SERVICE_NAME;
extern NSString * const FT_TVOS_SERVICE_NAME;
extern NSString * const FT_IOS_SDK_NAME;
extern NSString * const FT_SDK_NAME_VALUE;
extern NSString * const FT_USER_AGENT_NAME;
extern NSString * const FT_MACOS_SDK_NAME;
extern NSString * const FT_IS_WEBVIEW;
extern NSString * const FT_NULL_VALUE;
extern NSString * const FT_TYPE;
#pragma mark ----- data source
extern NSString * const FT_KEY_SOURCE;
extern NSString * const FT_LOGGER_TVOS_SOURCE;
extern NSString * const FT_LOGGER_SOURCE;
extern NSString * const FT_LOGGER_MACOS_SOURCE;
extern NSString * const FT_RUM_SOURCE_RESOURCE;
extern NSString * const FT_RUM_SOURCE_ERROR;
extern NSString * const FT_RUM_SOURCE_ACTION ;
extern NSString * const FT_RUM_SOURCE_LONG_TASK;
extern NSString * const FT_RUM_SOURCE_VIEW;
extern NSString * const FT_SDK_VERSION;
extern NSString * const FT_SDK_NAME;
extern NSString * const FT_SDK_PKG_INFO;
#pragma mark ========== BASE PROPERTY ==========
//应用名称
extern NSString * const FT_COMMON_PROPERTY_APP_NAME;
//系统版本
extern NSString * const FT_COMMON_PROPERTY_OS_VERSION;
//操作系统主要版本
extern NSString * const FT_COMMON_PROPERTY_OS_VERSION_MAJOR;
//是否是注册用户，属性值：True / False
extern NSString * const FT_IS_SIGNIN;
//操作系统
extern NSString * const FT_COMMON_PROPERTY_OS;
//设备提供商
extern NSString * const FT_COMMON_PROPERTY_DEVICE;
//分辨率，格式 height * width，例子：1920*1080
extern NSString * const FT_COMMON_PROPERTY_DISPLAY;
//设备机型
extern NSString * const FT_COMMON_PROPERTY_DEVICE_MODEL;
//屏幕宽度
extern NSString * const FT_SCREEN_SIZE;
//CPU ARCH
extern NSString * const FT_CPU_ARCH;
//设备 UUID
extern NSString * const FT_COMMON_PROPERTY_DEVICE_UUID;
//应用 ID
extern NSString * const FT_APPLICATION_UUID;
//环境
extern NSString * const FT_ENV;
//版本号
extern NSString * const FT_VERSION;
#pragma mark ========== rum ==========
extern NSString * const FT_DURATION;
extern NSString * const FT_TERMINAL_APP;
extern NSString * const FT_APP_ID;

#pragma mark ---------- session ----------
// rum global tag
extern NSString * const FT_RUM_KEY_SESSION_ID;
extern NSString * const FT_RUM_KEY_SESSION_TYPE;
extern NSString * const FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION;
extern NSString * const FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE;
extern NSString * const FT_RUM_SESSION_SAMPLE_RATE;
extern NSString * const FT_SESSION_ERROR_TIMESTAMP;
#pragma mark ---------- view ----------
#pragma mark --- tag
extern NSString * const FT_KEY_IS_ACTIVE;
// rum global view tag
extern NSString * const FT_KEY_VIEW_ID;
extern NSString * const FT_KEY_VIEW_REFERRER;
extern NSString * const FT_KEY_VIEW_NAME;
#pragma mark --- field
extern NSString * const FT_KEY_LOADING_TIME;
extern NSString * const FT_KEY_TIME_SPENT;
extern NSString * const FT_KEY_VIEW_ERROR_COUNT;
extern NSString * const FT_KEY_VIEW_UPDATE_TIME;
extern NSString * const FT_KEY_VIEW_RESOURCE_COUNT;
extern NSString * const FT_KEY_VIEW_LONG_TASK_COUNT;
extern NSString * const FT_KEY_VIEW_ACTION_COUNT;
#pragma mark --- monitor field
/// View 页面 每秒平均 CPU 跳动次数
extern NSString * const FT_CPU_TICK_COUNT_PER_SECOND;
/// View 页面 CPU 跳动次数
extern NSString * const FT_CPU_TICK_COUNT;
/// 页面内存使用平均值
extern NSString * const FT_MEMORY_AVG;
/// 页面内存峰值
extern NSString * const FT_MEMORY_MAX;
/// 页面最小每秒帧数
extern NSString * const FT_FPS_MINI;
/// 页面平均每秒帧数
extern NSString * const FT_FPS_AVG;

#pragma mark ---------- resource ----------
#pragma mark --- tag
extern NSString * const FT_KEY_RESOURCE_URL;
extern NSString * const FT_KEY_RESOURCE_URL_HOST;
extern NSString * const FT_KEY_RESOURCE_URL_PATH;
extern NSString * const FT_KEY_RESOURCE_URL_QUERY;
extern NSString * const FT_KEY_RESOURCE_URL_PATH_GROUP;
extern NSString * const FT_KEY_RESOURCE_TYPE;
extern NSString * const FT_KEY_RESOURCE_METHOD;
extern NSString * const FT_KEY_RESOURCE_STATUS;
extern NSString * const FT_KEY_RESOURCE_STATUS_GROUP;
extern NSString * const FT_KEY_RESPONSE_CONNECTION;
extern NSString * const FT_KEY_RESPONSE_CONTENT_TYPE;
extern NSString * const FT_KEY_RESPONSE_CONTENT_ENCODING;
extern NSString * const FT_KEY_RESOURCE_HOST_IP;
#pragma mark --- field
extern NSString * const FT_KEY_RESOURCE_SIZE;
extern NSString * const FT_KEY_RESOURCE_DNS;
extern NSString * const FT_KEY_RESOURCE_TCP;
extern NSString * const FT_KEY_RESOURCE_SSL;
extern NSString * const FT_KEY_RESOURCE_TTFB;
extern NSString * const FT_KEY_RESOURCE_TRANS;
extern NSString * const FT_KEY_RESOURCE_FIRST_BYTE;
extern NSString * const FT_KEY_RESPONSE_HEADER;
extern NSString * const FT_KEY_REQUEST_HEADER;
extern NSString * const FT_KEY_START;
extern NSString * const FT_KEY_RESOURCE_DNS_TIME;
extern NSString * const FT_KEY_RESOURCE_SSL_TIME;
extern NSString * const FT_KEY_RESOURCE_DOWNLOAD_TIME;
extern NSString * const FT_KEY_RESOURCE_FIRST_BYTE_TIME;
extern NSString * const FT_KEY_RESOURCE_CONNECT_TIME;
extern NSString * const FT_KEY_RESOURCE_REDIRECT_TIME;
#pragma mark --- trace link tag
extern NSString * const FT_KEY_TRACEID;
extern NSString * const FT_KEY_SPANID;

#pragma mark ---------- error ----------
#pragma mark --- tag
extern NSString * const FT_KEY_ERROR_SOURCE;
extern NSString * const FT_KEY_ERROR_TYPE;
extern NSString * const FT_KEY_ERROR_SITUATION;
#pragma mark --- field
extern NSString * const FT_KEY_ERROR_MESSAGE;
extern NSString * const FT_KEY_ERROR_STACK;
#pragma mark --- error monitor tag
extern NSString * const FT_MEMORY_TOTAL;
extern NSString * const FT_MEMORY_USE;
extern NSString * const FT_CPU_USE;
extern NSString * const FT_BATTERY_USE;
extern NSString * const FT_KEY_CARRIER;
extern NSString * const FT_KEY_LOCALE;

// error source value
extern NSString * const FT_LOGGER;
extern NSString * const FT_NETWORK;
extern NSString * const FT_NETWORK_ERROR;
#pragma mark ---------- long task ----------
extern NSString * const FT_KEY_LONG_TASK_STACK;
#pragma mark ---------- action ----------
#pragma mark --- tag
extern NSString * const FT_KEY_ACTION_ID;
extern NSString * const FT_KEY_ACTION_NAME;
extern NSString * const FT_KEY_ACTION_TYPE;
extern NSString * const FT_KEY_ACTION_TYPE_CLICK;
extern NSString * const FT_LAUNCH_HOT;
extern NSString * const FT_LAUNCH_COLD;
extern NSString * const FT_LAUNCH_WARM;

#pragma mark --- field
extern NSString * const FT_KEY_ACTION_LONG_TASK_COUNT;
extern NSString * const FT_KEY_ACTION_RESOURCE_COUNT;
extern NSString * const FT_KEY_ACTION_ERROR_COUNT;

#pragma mark ========== logging ==========
extern NSString * const FT_KEY_STATUS;
extern NSString * const FT_KEY_CONTENT;
extern NSString * const FT_KEY_MESSAGE;

extern NSString * const FT_RUM_CUSTOM_KEYS;
#pragma mark ========== tracing ==========
extern NSString * const FT_NETWORK_ZIPKIN_TRACEID;
extern NSString * const FT_NETWORK_ZIPKIN_SPANID;
extern NSString * const FT_NETWORK_ZIPKIN_PARENTSPANID;
extern NSString * const FT_NETWORK_ZIPKIN_SAMPLED;
extern NSString * const FT_NETWORK_SKYWALKING_V3;
extern NSString * const FT_NETWORK_SKYWALKING_V2;
extern NSString * const FT_NETWORK_JAEGER_TRACEID;
extern NSString * const FT_NETWORK_DDTRACE_TRACEID;
extern NSString * const FT_NETWORK_DDTRACE_SPANID;
extern NSString * const FT_NETWORK_DDTRACE_ORIGIN;
extern NSString * const FT_NETWORK_DDTRACE_SAMPLED;
extern NSString * const FT_NETWORK_DDTRACE_SAMPLING_PRIORITY;
extern NSString * const FT_NETWORK_TRACEPARENT_KEY;
extern NSString * const FT_NETWORK_ZIPKIN_SINGLE_KEY;

#pragma mark ========== user info key ==========
extern NSString * const FT_USER_INFO;
extern NSString * const FT_USER_ID;
extern NSString * const FT_USER_EMAIL;
extern NSString * const FT_USER_NAME;
extern NSString * const FT_USER_EXTRA;

#pragma mark ========== inner use ==========
extern NSUInteger const FT_LOGGING_CONTENT_SIZE;

extern int const FT_DB_LOG_MAX_COUNT;
extern int const FT_DB_LOG_MIN_COUNT;

extern int const FT_DB_RUM_MAX_COUNT;
extern int const FT_DB_RUM_MIN_COUNT;

extern long const FT_DEFAULT_DB_SIZE_LIMIT;
extern long const FT_MIN_DB_SIZE_LIMIT;

extern NSString * const FT_SCRIPT_MESSAGE_HANDLER_NAME;
extern NSUInteger const FT_TIME_INTERVAL;
/// 超过多少毫秒为一次卡顿,default 250ms
extern long const FT_DEFAULT_BLOCK_DURATIONS_MS;
/// 卡顿最小时长 100 ms
extern long const FT_MIN_DEFAULT_BLOCK_DURATIONS_MS;

extern long long const FT_ANR_THRESHOLD_NS;
extern long const FT_ANR_THRESHOLD_MS;

extern NSString * const FT_BLACK_LIST_VIEW;
extern NSString * const FT_BLACK_LIST_VIEW_ACTION;


