//
//  TestCCrash.cpp
//  SampleApp
//
//  Created by 胡蕾蕾 on 2020/9/27.
//  Copyright © 2020 hll. All rights reserved.
//

#include "TestCCrash.hpp"
void MyCppClass::testCrash(){
     char *s = "hello world";
       *s = 'H';
}
