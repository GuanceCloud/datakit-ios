//
//  FTSymbolicator.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTSymbolicator_h
#define FTSymbolicator_h

#include <stdbool.h>

#include "FTStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

bool ftsymbolicator_symbolicate(FTStackCursor *cursor);


#ifdef __cplusplus
}
#endif


#endif /* FTSymbolicator_h */
