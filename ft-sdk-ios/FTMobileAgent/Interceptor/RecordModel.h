//
//  RecordModel.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#define set_ft_sessionid(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"ft_sessionid"]
#define get_ft_sessionid      [[NSUserDefaults standardUserDefaults] valueForKey:@"ft_sessionid"]
@interface RecordModel : NSObject

@property (nonatomic, assign) long _id;
@property (nonatomic, assign) long tm;
@property (nonatomic, strong) NSString *sessionid;
@property (nonatomic, strong) NSString *data;


@end

NS_ASSUME_NONNULL_END
