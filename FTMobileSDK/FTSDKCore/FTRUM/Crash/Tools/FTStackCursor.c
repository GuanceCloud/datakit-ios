//
//  FTStackCursor.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTStackCursor.h"
#include "FTSymbolicator.h"

static bool g_advanceCursor(__unused FTStackCursor *cursor)
{
//    (
//        "No stack cursor has been set. For C++, this means that hooking __cxa_throw() failed for some reason. Embedded "
//        "frameworks can cause this: https://github.com/kstenerud/KSCrash/issues/205");
    return false;
}
void ftsc_resetCursor(FTStackCursor *cursor)
{
    cursor->state.currentDepth = 0;
    cursor->state.hasGivenUp = false;
    cursor->stackEntry.address = 0;
    cursor->stackEntry.imageAddress = 0;
    cursor->stackEntry.imageName = NULL;
    cursor->stackEntry.symbolAddress = 0;
    cursor->stackEntry.symbolName = NULL;
}

void ftsc_initCursor(FTStackCursor *cursor, void (*resetCursor)(FTStackCursor *),
                     bool (*advanceCursor)(FTStackCursor *)){
    cursor->symbolicate = ftsymbolicator_symbolicate;
    cursor->advanceCursor = advanceCursor != NULL ? advanceCursor : g_advanceCursor;
    cursor->resetCursor = resetCursor != NULL ? resetCursor : ftsc_resetCursor;
    cursor->resetCursor(cursor);
}


