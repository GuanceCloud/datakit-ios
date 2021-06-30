//
//  TableViewCellItem.h
//  SampleApp
//
//  Created by 胡蕾蕾 on 2021/2/19.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void(^Handler)(void);
NS_ASSUME_NONNULL_BEGIN

@interface TableViewCellItem : NSObject
@property (nonatomic,copy) NSString *title;
@property (nonatomic,copy) Handler handler;
-(instancetype)initWithTitle:(NSString *)title handler:(Handler)handler;
@end

NS_ASSUME_NONNULL_END
