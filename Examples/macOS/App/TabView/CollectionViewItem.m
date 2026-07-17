//
//  CollectionViewItem.m
//  Example
//
//  Created by hulilei on 2021/9/14.
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

#import "CollectionViewItem.h"

@interface CollectionViewItem ()
@property (weak) IBOutlet NSImageView *icon;
@property (weak) IBOutlet NSTextField *lable;

@end

@implementation CollectionViewItem

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}
-(void)setRepresentedObject:(id)representedObject{
    [super setRepresentedObject:representedObject];
    if(representedObject){
        NSDictionary *data = representedObject;
        NSString *image = data[@"image"];
        self.icon.image = [NSImage imageNamed:image];
        self.icon.tag = [data[@"tag"] integerValue];
        NSString *title = data[@"title"];
        self.lable.stringValue = title;
//        NSClickGestureRecognizer *tap = [[NSClickGestureRecognizer alloc]init];
//        tap.action = @selector(lableTap);
//        tap.target = self;
//        [self.lable addGestureRecognizer:tap];
//        
//        
//        NSClickGestureRecognizer *gesture = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewClick:)];
//        gesture.numberOfClicksRequired = 1;
//        [self.icon addGestureRecognizer:gesture];
    }
    [self updateStatus];
}
- (void)lableTap{
    NSLog(@"lableTap NSGestureRecognizer set action");
}
- (void)imageViewClick:(NSClickGestureRecognizer *)ges{
    NSLog(@"imageTap NSGestureRecognizer init action");
}
-(void)updateStatus{
    if (self.selected) {
        self.view.layer.backgroundColor = [NSColor lightGrayColor ].CGColor;
    }else{
        self.view.layer.backgroundColor = [NSColor clearColor ].CGColor;
    }
}
@end
