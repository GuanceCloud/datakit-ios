//
//  LoggingViewController.m
//  Example
//
//  Created by hulilei on 2023/4/3.
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

#import "LoggingViewController.h"
#import "../GuanceSDKExampleImports.h"
@interface LoggingViewController ()<NSTableViewDataSource,NSTableViewDelegate>
@property (strong) IBOutlet NSTableView *mTableView;
@property (nonatomic, strong) NSArray *datas;

@end
@implementation LoggingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self createUI];
}
- (void)createUI{
    self.datas = @[@{@"Logging":@"Log Status: info"},
                   @{@"Logging":@"Log Status: warning"},
                   @{@"Logging":@"Log Status: error"},
                   @{@"Logging":@"Log Status: critical"},
                   @{@"Logging":@"Log Status: ok"},
    ];
    self.mTableView.usesAlternatingRowBackgroundColors = YES;
    [self.mTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
    self.mTableView.dataSource = self;
    self.mTableView.delegate = self;
    [self.mTableView reloadData];
    
}
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    return  self.datas.count;
}
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSDictionary *data = self.datas[row];
    NSString *key = tableColumn.identifier;
    // Cell data
    NSString *value = [NSString stringWithFormat:@"%@", data[key]];
    
    // Create cell view based on table column identifier
    NSView *view = [tableView makeViewWithIdentifier:key owner:self];
   
    if (view == nil) {
    
        NSTableCellView *cellView = [NSTableCellView alloc].init;
        view = cellView;
        
        NSTextField *textField =  [NSTextField alloc].init;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [textField setBezeled:NO];
        textField.maximumNumberOfLines = 3;
        textField.drawsBackground = NO;

        [cellView addSubview:textField];
        
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

    if (value != nil) {
        textField.stringValue = value;
    }
    
    return view;

}

-(void)tableViewSelectionDidChange:(NSNotification *)notification{
    switch (self.mTableView.selectedRow) {
        case 0:
            [[FTMobileAgent sharedInstance] logging:@"info log content" status:FTStatusInfo];
            break;
        case 1:
            [[FTMobileAgent sharedInstance] logging:@"warning log content" status:FTStatusWarning];

            break;
        case 2:
            [[FTMobileAgent sharedInstance] logging:@"error log content" status:FTStatusError];
            break;
        case 3:
            [[FTMobileAgent sharedInstance] logging:@"critical log content" status:FTStatusCritical];

            break;
        case 4:
            [[FTLogger sharedInstance] ok:@"ok log content" property:nil];

            break;
        default:
            break;
    }
}

@end
