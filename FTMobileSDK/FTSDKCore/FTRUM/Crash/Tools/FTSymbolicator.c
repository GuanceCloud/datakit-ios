//
//  FTSymbolicator.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTSymbolicator.h"
#include "FTDynamicLinker.h"

#if defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#elif defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#else
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#endif

#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)


bool ftsymbolicator_symbolicate(FTStackCursor *cursor){
    Dl_info symbolsBuffer;
    if (ftdl_dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(cursor->stackEntry.address),&symbolsBuffer)) {
        cursor->stackEntry.imageAddress = (uintptr_t)symbolsBuffer.dli_fbase;
        cursor->stackEntry.imageName = symbolsBuffer.dli_fname;
        cursor->stackEntry.symbolAddress = (uintptr_t)symbolsBuffer.dli_saddr;
        cursor->stackEntry.symbolName = symbolsBuffer.dli_sname;
        return true;
    }
    
    cursor->stackEntry.imageAddress = 0;
    cursor->stackEntry.imageName = 0;
    cursor->stackEntry.symbolAddress = 0;
    cursor->stackEntry.symbolName = 0;
    return false;
}
