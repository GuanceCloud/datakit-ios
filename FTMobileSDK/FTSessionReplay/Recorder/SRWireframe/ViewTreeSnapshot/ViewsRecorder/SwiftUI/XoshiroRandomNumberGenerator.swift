//
//  XoshiroRandomNumberGenerator.swift
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/8.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#if os(iOS)

import Foundation

struct FTXoshiroRandomNumberGenerator: RandomNumberGenerator {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    init<T>(seed: T) where T: FixedWidthInteger {
        let value = UInt64(seed)
        state = (value, value, value, value)
    }

    mutating func next() -> UInt64 {
        let x = state.1 &* 5
        let result = ((x &<< 7) | (x &>> 57)) &* 9
        let t = state.1 &<< 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = (state.3 &<< 45) | (state.3 &>> 19)
        return result
    }
}

#endif
