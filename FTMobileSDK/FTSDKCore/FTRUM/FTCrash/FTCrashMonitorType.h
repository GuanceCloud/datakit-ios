//
//  FTCrashMonitorType.h
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#ifndef FTCrashMonitorType_h
#define FTCrashMonitorType_h

#ifdef __cplusplus
extern "C" {
#endif


typedef enum
{
    /** Monitor Mach kernel exceptions. */
    FTCrashMonitorTypeMachException      = 0x01,
    
    /** Monitor fatal signals. */
    FTCrashMonitorTypeSignal             = 0x02,
    
    /** Monitor uncaught C++ exceptions. */
    FTCrashMonitorTypeCPPException       = 0x04,
    
    /** Monitor uncaught Objective-C NSExceptions. */
    FTCrashMonitorTypeNSException        = 0x08,
    
    /** Track and inject system information. */
    FTCrashMonitorTypeSystem             = 0x40,
    
    /** Track and inject application state information. */
    FTCrashMonitorTypeApplicationState   = 0x80,
    
}FTCrashMonitorType;

#define FTCrashMonitorTypeAll                                                                  \
    (FTCrashMonitorTypeMachException | FTCrashMonitorTypeSignal                            \
        | FTCrashMonitorTypeCPPException | FTCrashMonitorTypeNSException                   \
        | FTCrashMonitorTypeApplicationState | FTCrashMonitorTypeSystem)


#define FTCrashMonitorTypeHighCompatibility                                                          \
    (FTCrashMonitorTypeAll & (~FTCrashMonitorTypeMachException))


#ifdef __cplusplus
}
#endif

#endif /* FTCrashMonitorType_h */
