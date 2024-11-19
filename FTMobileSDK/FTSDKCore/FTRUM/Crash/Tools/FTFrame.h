//
//  FTFrame.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTFrame : NSObject
/**
 * SymbolAddress of the frame
 */
@property (nonatomic, copy) NSString *_Nullable symbolAddress;

/**
 * Filename is used only for reporting JS frames
 */
@property (nonatomic, copy) NSString *_Nullable fileName;

/**
 * Function name of the frame
 */
@property (nonatomic, copy) NSString *_Nullable function;

/**
 * Module of the frame, mostly unused
 */
@property (nonatomic, copy) NSString *_Nullable module;

/**
 * Corresponding package
 */
@property (nonatomic, copy) NSString *_Nullable package;

/**
 * ImageAddress if the image related to the frame
 */
@property (nonatomic, copy) NSString *_Nullable imageAddress;

/**
 * Set the platform for the individual frame, will use platform of the event.
 * Mostly used for react native crashes.
 */
@property (nonatomic, copy) NSString *_Nullable platform;

/**
 * InstructionAddress of the frame hex format
 */
@property (nonatomic, copy) NSString *_Nullable instructionAddress;

/**
 * InstructionAddress of the frame
 */
@property (nonatomic) NSUInteger instruction;

/**
 * User for react native, will be ignored for cocoa frames
 */
@property (nonatomic, copy) NSNumber *_Nullable lineNumber;

/**
 * User for react native, will be ignored for cocoa frames
 */
@property (nonatomic, copy) NSNumber *_Nullable columnNumber;

/**
 * Determines if the Frame is the base of an async continuation.
 */
@property (nonatomic, copy) NSNumber *_Nullable stackStart;

- (instancetype)init;
@end

NS_ASSUME_NONNULL_END
