//
//  FTConstants.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

///事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
typedef NS_ENUM(NSInteger, FTStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
#pragma mark ========== agent ==========
extern NSString * const FT_AGENT_MEASUREMENT;
extern NSString * const FT_AGENT_FIELD;
extern NSString * const FT_AGENT_TAGS;
extern NSString * const FT_AGENT_OPDATA;
extern NSString * const FT_AGENT_OP;
extern NSString * const FT_USER_AGENT;
extern NSString * const FT_DEFAULT_SERVICE_NAME;
extern NSString * const FT_NULL_VALUE;
extern NSString * const FT_HTTP_MEASUREMENT;
extern NSString * const FT_WEB_HTTP_MEASUREMENT;
extern NSString * const FT_WEB_TIMECOST_MEASUREMENT;
extern NSString * const FT_MOBILE_CLIENT_TIMECOST_MEASUREMENT;
extern NSString * const FT_EVENT_ACTIVATED;
extern NSString * const FT_TYPE;


extern NSString * const FT_RUM_WEB_PAGE_PERFORMANCE;
extern NSString * const FT_RUM_WEB_RESOURCE_PERFORMANCE;
extern NSString * const FT_RUM_APP_STARTUP;
extern NSString * const FT_RUM_APP_VIEW;
extern NSString * const FT_RUM_APP_FREEZE;
extern NSString * const FT_RUM_APP_RESOURCE_PERFORMANCE;
extern NSString * const FT_TYPE_JS;
extern NSString * const FT_TYPE_PAGE;
extern NSString * const FT_TYPE_RESOURCE;
extern NSString * const FT_TYPE_CRASH;
extern NSString * const FT_TYPE_FREEZE;
extern NSString * const FT_TYPE_VIEW;

#pragma mark ========== flow ==========
extern NSString * const FT_KEY_DURATION;
extern NSString * const FT_FLOW_TRACEID;
extern NSString * const FT_KEY_NAME;

#pragma mark ========== autotrack  ==========

extern NSString * const FT_AUTO_TRACK_OP_LAUNCH;
extern NSString * const FT_AUTO_TRACK_OP_VIEW;
extern NSString * const FT_TRACK_OP_CUSTOM;
extern NSString * const FT_AUTO_TRACK_OP_OPEN;
extern NSString * const FT_TRACK_LOGGING_EXCEPTION;
extern NSString * const FT_TRACK_LOGGING_CONSOLELOG;
extern NSString * const FT_AUTOTRACK_MEASUREMENT;
extern NSString * const FT_AUTO_TRACK_EVENT_ID;
extern NSString * const FT_KEY_EVENT;
extern NSString * const FT_AUTO_TRACK_CURRENT_PAGE_NAME;
extern NSString * const FT_AUTO_TRACK_VTP;
extern NSString * const FT_AUTO_TRACK_VTP_ID;
extern NSString * const FT_AUTO_TRACK_VTP_DESC;
extern NSString * const FT_AUTO_TRACK_PAGE_DESC;
extern NSString * const FT_AUTO_TRACK_VTP_TREE_PATH;

#pragma mark ========== monitor  ==========
extern NSString * const FT_MONITOR_BATTERY_TOTAL;
extern NSString * const FT_MONITOR_BATTERY_USE;
extern NSString * const FT_MONITOR_BATTERY_STATUS;

extern NSString * const FT_MONITOR_MEMORY_TOTAL;
extern NSString * const FT_MONITOR_MEMORY_USE;

extern NSString * const FT_MONITOR_GPU_MODEL;
extern NSString * const FT_MONITOR_GPU_RATE;

extern NSString * const FT_MONITOR_CAMERA_FRONT_PX;
extern NSString * const FT_MONITOR_CAMERA_BACK_PX;

extern NSString * const FT_MONITOR_DEVICE_NAME;


extern NSString * const FT_MONITOR_PROVINCE;
extern NSString * const FT_MONITOR_CITY;
extern NSString * const FT_MONITOR_COUNTRY;
extern NSString * const FT_MONITOR_LATITUDE;
extern NSString * const FT_MONITOR_LONGITUDE;

#pragma mark ------ NETWORK -------
extern NSString * const FT_MONITOR_WITF_SSID;
extern NSString * const FT_MONITOR_NETWORK_TYPE;
extern NSString * const FT_MONITOR_NETWORK_STRENGTH;
extern NSString * const FT_MONITOR_NETWORK_IN_RATE;
extern NSString * const FT_MONITOR_NETWORK_OUT_RATE;
extern NSString * const FT_MONITOR_NETWORK_DNS_TIME;
extern NSString * const FT_MONITOR_NETWORK_TCP_TIME;
extern NSString * const FT_MONITOR_NETWORK_RESPONSE_TIME;
extern NSString * const FT_MONITOR_NETWORK_ERROR_RATE;
extern NSString * const FT_MONITOR_NETWORK_PROXY;

extern NSString * const FT_MONITOR_FT_NETWORK_DNS_TIME;
extern NSString * const FT_MONITOR_FT_NETWORK_TCP_TIME;
extern NSString * const FT_MONITOR_FT_NETWORK_RESPONSE_TIME;
extern NSString * const FT_NETWORK_REQUEST_URL;
extern NSString * const FT_NETWORK_REQUEST_CONTENT;
extern NSString * const FT_NETWORK_RESPONSE_CONTENT;
extern NSString * const FT_NETWORK_CONNECT_TIME;
extern NSString * const FT_DURATION_TIME;
extern NSString * const FT_KEY_HOST;
extern NSString * const FT_ISERROR;

extern NSString * const FT_MONITOR_STEPS;
extern NSString * const FT_MONITOR_LIGHT;
extern NSString * const FT_MONITOR_ROAM;
extern NSString * const FT_MONITOR_GPS_OPEN;
extern NSString * const FT_MONITOR_SCREEN_BRIGHTNESS;
extern NSString * const FT_MONITOR_PROXIMITY;
extern NSString * const FT_MONITOR_FPS;
extern NSString * const FT_MONITOR_BT_OPEN;
extern NSString * const FT_MONITOR_TORCH;

#pragma mark ========== device info ==========
extern NSString *  const FTBaseInfoHanderDeviceCPUType;
extern NSString *  const FTBaseInfoHanderDeviceCPUClock;
extern NSString *  const FTBaseInfoHanderBatteryTotal;
extern NSString *  const FTBaseInfoHanderDeviceGPUType;
#pragma mark ========== api ==========
extern NSString *  const FT_DATA_TYPE_ES;
extern NSString *  const FT_DATA_TYPE_INFLUXDB;

extern NSString *  const FT_NETWORKING_API_METRICS;
extern NSString *  const FT_NETWORKING_API_OBJECT;
extern NSString *  const FT_NETWORKING_API_KEYEVENT;
extern NSString *  const FT_NETWORKING_API_LOGGING;
extern NSString *  const FT_NETWORKING_API_CHECK_TOKEN;

#pragma mark ========== object、keyevent ==========
extern NSString *  const FT_KEY_STATUS;
extern NSString *  const FT_KEY_TAGS;
extern NSString *  const FT_KEY_CLASS;
extern NSString *  const FT_KEY_CONTENT;
extern NSString *  const FT_KEY_SERVICENAME;
extern NSString *  const FT_KEY_OPERATIONNAME;
extern NSString *  const FT_KEY_SPANID;
extern NSString *  const FT_KEY_ISERROR;
extern NSString *  const FT_KEY_TYPE;
extern NSString *  const FT_KEY_TITLE;
extern NSString *  const FT_KEY_SPANTYPE;
extern NSString *  const FT_APPLICATION_UUID;
extern NSString *  const FT_NETWORK_ZIPKIN_TRACEID;
extern NSString *  const FT_NETWORK_ZIPKIN_SPANID;
extern NSString *  const FT_NETWORK_ZIPKIN_SAMPLED;
extern NSString *  const FT_NETWORK_SKYWALKING_V3;
extern NSString *  const FT_NETWORK_SKYWALKING_V2;
extern NSString *  const FT_NETWORK_JAEGER_TRACEID;

extern NSString *  const FT_NETWORK_HEADERS;
extern NSString *  const FT_NETWORK_BODY;
extern NSString *  const FT_LOGGING_CLASS_TRACING;
extern NSString *  const FT_KEY_TRUE;
extern NSString *  const FT_KET_FALSE;
extern NSString *  const FT_NETWORK_CODE;
extern NSString *  const FT_NETWORK_ERROR;
extern NSString *  const FT_SPANTYPE_ENTRY;
extern NSUInteger  const FT_LOGGING_CONTENT_SIZE;
extern NSUInteger  const FT_DB_CONTENT_MAX_COUNT;
