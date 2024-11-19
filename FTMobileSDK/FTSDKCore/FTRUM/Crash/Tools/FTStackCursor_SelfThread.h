//
//  FTStackCursor_SelfThread.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTStackCursor_SelfThread_h
#define FTStackCursor_SelfThread_h

#include "FTStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Initialize a stack cursor for the current thread.
 *  You may want to skip some entries to account for the trace immediately leading
 *  up to this init function.
 *
 * @param cursor The stack cursor to initialize.
 *
 * @param skipEntries The number of stack entries to skip.
 */
void ftsc_initSelfThread(FTStackCursor *cursor, int skipEntries);

#ifdef __cplusplus
}
#endif


#endif /* FTStackCursor_SelfThread_h */
