//
//  FirstViewController.m
//  Example
//
//  Created by hulilei on 2021/9/10.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "FirstViewController.h"

@interface FirstViewController ()<NSComboBoxDelegate>
@property (strong) IBOutlet NSComboBox *comboBox;
@property (strong) IBOutlet NSPopUpButton *item;

@end

@implementation FirstViewController
-(void)viewWillAppear{
    [super viewWillAppear];
    NSLog(@"FirstViewController viewWillAppear");

}
- (void)viewDidAppear{
    [super viewDidAppear];
    NSLog(@"FirstViewController viewDidAppear");
    NSLog(@"keyWindow = %@",[NSApplication sharedApplication].keyWindow);
    self.comboBox.delegate = self;
}

- (void)viewClick:(NSGestureRecognizer *)gesture {
    NSLog(@"touch view");
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do view setup here.
}
- (void)comboBoxWillPopUp:(NSNotification *)notification{
    NSLog(@"keyWindow = %@",[NSApplication sharedApplication].keyWindow);
}
- (void)viewDidDisappear{
    [super viewDidDisappear];
    NSLog(@"FirstViewController viewDidDisappear");

}
@end
