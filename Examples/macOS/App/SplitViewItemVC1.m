//
//  SplitViewItemVC1.m
//  Example
//
//  Created by hulilei on 2021/9/26.
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

#import "SplitViewItemVC1.h"
#import "SplitViewVC.h"
#import "GuanceSDKExampleImports.h"
#import "macOS_App-Swift.h"
@interface SplitViewItemVC1 ()<NSTableViewDelegate,NSTableViewDataSource>
@property (weak) IBOutlet NSTableView *mTableview;
@property (nonatomic, strong) NSArray *datas;

@end

@implementation SplitViewItemVC1

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
}
- (void)createUI{
    SplitViewVC *parent = (SplitViewVC *)self.parentViewController;
    self.delegate = parent;
    self.datas = @[@"AutoTrack Click",@"RUM Data Collection",@"Log Output",@"Network Link Tracing",@"WebViewBridge",@"Bind User",@"Unbind User"];
    //@"Console Log Collection"
    self.mTableview.backgroundColor = [NSColor whiteColor];
    self.mTableview.usesAlternatingRowBackgroundColors = YES;
    [self.mTableview setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
    self.mTableview.dataSource = self;
    self.mTableview.delegate = self;
    self.mTableview.allowsMultipleSelection = NO;
    [self.mTableview reloadData];
}
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    return  self.datas.count;
}
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSString *data = self.datas[row];
    NSString *key = tableColumn.identifier;
    // Cell data
    
    // Create cell view based on table column identifier
    NSView *view = [tableView makeViewWithIdentifier:key owner:self];
   
    if (view == nil) {
    
        NSTableCellView *cellView = [NSTableCellView alloc].init;
        
        view = cellView;
        NSTextField *textField =  [NSTextField alloc].init;
        textField.tag = 200+row;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [textField setBezeled:NO];
        textField.drawsBackground = NO;

//        [cellView addSubview:textField];
        cellView.textField = textField;

        NSLayoutConstraint *topAnchor = [textField.topAnchor constraintEqualToAnchor:cellView.topAnchor constant:0];
        NSLayoutConstraint *bottomAnchor = [textField.bottomAnchor constraintEqualToAnchor:cellView.bottomAnchor constant:0];

        NSLayoutConstraint *leftAnchor = [textField.leftAnchor constraintEqualToAnchor:cellView.leftAnchor constant:0];

        NSLayoutConstraint *rightAnchor = [textField.rightAnchor constraintEqualToAnchor:cellView.rightAnchor constant:0];

        [NSLayoutConstraint activateConstraints:@[topAnchor,bottomAnchor,leftAnchor, rightAnchor]];
    }
    
    NSArray *subviews = view.subviews;
    if (subviews.count <= 0){
        return nil;
    }
    
    NSTextField *textField = subviews[0];
    textField.tag = 200+row;
    if (data != nil) {
        textField.stringValue = data;
    }
    
    return view;
}
-(void)tableViewSelectionDidChange:(NSNotification *)notification{
    NSInteger row = [notification.object selectedRow];
    if(row == 5){
        [[FTMobileAgent sharedInstance] bindUserWithUserID:@"macosid01" userName:@"macos_user" userEmail:@"macos_user@123.com" extra:@{@"user_extra":@"user_extra_demo"}];
        return;
    }else if(row == 6){
        [[FTMobileAgent sharedInstance] unbindUser];
        return;
    }else if(row == 7){
        NSLog(@"NSLog Console log");
        LogTest *test = [[LogTest alloc]init];
        [test show];
    }
    if (self.delegate&&[self.delegate respondsToSelector:@selector(tableViewSelectionDidSelect:)]) {
        [self.delegate tableViewSelectionDidSelect:row];
    }
}

@end
