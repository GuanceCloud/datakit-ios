//
//  RecordModel.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordModel : NSObject
@property (nonatomic, strong) NSString *cpn;//current page name，当前页面名称
@property (nonatomic, strong) NSString *rpn;//root page name，根部页面名称
@property (nonatomic, strong) NSString *op; //operation，操作 lanc\open\cls\clk
@property (nonatomic, strong) NSDictionary *opdata; //@{@"vtp":@""} //

@property (nonatomic, assign) long _id;
@property (nonatomic, assign) long tm;
@property (nonatomic, strong) NSString *data;


@end

NS_ASSUME_NONNULL_END
