//
//  CrashViewController.m
//  Example
//
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

#import "CrashViewController.h"
#import "Crasher.h"

@interface CrashViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSArray<NSString *> *crashItems;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) Crasher *crasher;

@end

@implementation CrashViewController

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 800)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.crashItems = @[
        @"throwUncaughtNSException",
        @"dereferenceBadPointer",
        @"dereferenceNullPointer",
        @"useCorruptObject",
        @"spinRunloop",
        @"causeStackOverflow",
        @"doAbort",
        @"doDiv0",
        @"accessDeallocatedObject",
        @"accessDeallocatedPtrProxy",
        @"zombieNSException",
        @"corruptMemory",
        @"anr",
        @"deadlock",
        @"pthreadAPICrash",
        @"throwUncaughtCPPException",
        @"userException",
    ];
    [self createUI];
}

- (void)createUI {
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;

    self.tableView = [[NSTableView alloc] init];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.target = self;
    self.tableView.action = @selector(clickRow:);

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"Crash"];
    column.title = @"Crash";
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:column];

    scrollView.documentView = self.tableView;
    [self.view addSubview:scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.crashItems.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"CrashCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = @"CrashCell";

        NSTextField *textField = [NSTextField labelWithString:@""];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        cell.textField = textField;
        [cell addSubview:textField];
        [NSLayoutConstraint activateConstraints:@[
            [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
            [textField.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-8],
        ]];
    }
    cell.textField.stringValue = self.crashItems[row];
    return cell;
}

- (void)clickRow:(NSTableView *)tableView {
    NSInteger row = tableView.clickedRow;
    if (row < 0 || row >= self.crashItems.count) {
        return;
    }

    switch (row) {
        case 0:
            [self.crasher throwUncaughtNSException];
            break;
        case 1:
            [self.crasher dereferenceBadPointer];
            break;
        case 2:
            [self.crasher dereferenceNullPointer];
            break;
        case 3:
            [self.crasher useCorruptObject];
            break;
        case 4:
            [self.crasher spinRunloop];
            break;
        case 5:
            [self.crasher causeStackOverflow];
            break;
        case 6:
            [self.crasher doAbort];
            break;
        case 7:
            [self.crasher doDiv0];
            break;
        case 8:
            [self.crasher accessDeallocatedObject];
            break;
        case 9:
            [self.crasher accessDeallocatedPtrProxy];
            break;
        case 10:
            [self.crasher zombieNSException];
            break;
        case 11:
            [self.crasher corruptMemory];
            break;
        case 12:
            [self.crasher anr];
            break;
        case 13:
            [self.crasher deadlock];
            break;
        case 14:
            [self.crasher pthreadAPICrash];
            break;
        case 15:
            [self.crasher throwUncaughtCPPException];
            break;
        case 16:
            [self.crasher userException];
            break;
        default:
            break;
    }
}

- (Crasher *)crasher {
    if (!_crasher) {
        _crasher = [[Crasher alloc] init];
    }
    return _crasher;
}

@end
