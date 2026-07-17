//
//  SecondViewController.m
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

#import "SecondViewController.h"

@interface SecondViewController ()
@property (weak) IBOutlet NSTextField *lable;
@property (weak) IBOutlet NSImageView *imageView;
@property (strong) IBOutlet NSStepper *stepper;
@property (strong) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation SecondViewController
-(void)viewWillAppear{
    [super viewWillAppear];
    NSLog(@"SecondViewController viewWillAppear");
}
- (void)viewDidAppear{
    [super viewDidAppear];
    NSLog(@"SecondViewController viewDidAppear");

}
- (void)viewDidLoad {
    [super viewDidLoad];
   
    // Do view setup here.
    NSLog(@"SecondViewController viewDidAppear");
    NSClickGestureRecognizer *tap = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(lableTap:)];
    tap.numberOfClicksRequired = 1;
    self.lable.enabled = YES;
    [self.lable addGestureRecognizer:tap];
    // Set background color
    self.imageView.wantsLayer = YES;
    self.imageView.layer.backgroundColor = NSColor.redColor.CGColor;
    // Set corner radius
    self.imageView.layer.cornerRadius = 10;
    // Set border
    self.imageView.layer.borderColor = NSColor.redColor.CGColor;
    self.imageView.layer.borderWidth = 5;
  
    NSClickGestureRecognizer *gesture = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewClick:)];
    gesture.numberOfClicksRequired = 1;
    [self.imageView addGestureRecognizer:gesture];
    self.stepper.maxValue = 100;
    self.stepper.minValue = 0;
    self.stepper.increment = 2;
}
- (void)lableTap:(NSClickGestureRecognizer *)ges{
    NSLog(@"lableTap NSGestureRecognizer set action");
}
- (void)imageViewClick:(NSClickGestureRecognizer *)ges{
    NSLog(@"imageTap NSGestureRecognizer init action");
}
- (IBAction)slider:(id)sender {
    NSLog(@"slider = %@",sender);
}
- (void)viewDidDisappear{
    [super viewDidDisappear];
    NSLog(@"SecondViewController viewDidDisappear");

}
@end
