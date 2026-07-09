//
//  FTExternalDataManager+Private.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/9/20.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


#import "FTExternalDataManager.h"
#import "FTRumDatasProtocol.h"
#import "FTExternalResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTExternalDataManager (Private)<FTRumDatasProtocol,FTExternalResourceProtocol>
@property (nonatomic, weak, nullable) id <FTRumDatasProtocol> delegate;
@property (nonatomic, weak, nullable) id <FTExternalResourceProtocol> resourceDelegate;

@end

NS_ASSUME_NONNULL_END
