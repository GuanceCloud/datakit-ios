//
//  FTRUMResourceHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class FTRUMViewHandler;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTResourceEventSent)(BOOL);
typedef void(^FTErrorEventSent)(void);

/// RUM Resource data processor
@interface FTRUMResourceHandler : FTRUMHandler
/// resource unique identifier
@property (nonatomic, copy,readonly) NSString *identifier;
/// rum context
@property (nonatomic, strong) FTRUMContext *context;
/// resource data processing completion callback
@property (nonatomic, copy) FTResourceEventSent resourceHandler;
/// resource error processing completion callback
@property (nonatomic, copy) FTErrorEventSent errorHandler;
/// Initialization method
/// - Parameters:
///   - model: rum data model
///   - context: rum context
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context dependencies:(FTRUMDependencies *)dependencies;
@end

NS_ASSUME_NONNULL_END
