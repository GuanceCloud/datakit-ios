//
//  TestBluetoothList.m
//  AppDev
//
//  Created by 胡蕾蕾 on 2020/5/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestBluetoothList.h"
#import <CoreBluetooth/CoreBluetooth.h>
@interface TestBluetoothList ()<CBCentralManagerDelegate,CBPeripheralDelegate,UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *devicesListArray;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation TestBluetoothList

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BluetoothList";
    self.devicesListArray = [NSMutableArray new];

    [self createUI];
    [self bluteeh];

}
- (void)createUI{
    self.tableView.frame = CGRectMake(0, 5, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200);
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.bounces = YES;
    self.tableView.rowHeight = 60;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.tableView reloadData];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    [self.view addSubview:self.tableView];
}
- (UITableView *)tableView
{
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.showsVerticalScrollIndicator = NO;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _tableView.estimatedRowHeight = 50;
        _tableView.rowHeight = UITableViewAutomaticDimension;
  
        _tableView.scrollsToTop = YES;
        _tableView.backgroundColor = [UIColor whiteColor];
         _tableView.tableFooterView = [[UIView alloc] init];
    }
    return _tableView;
}
-(void)headerRefreshing{
    [self.devicesListArray removeAllObjects];
    [self.tableView reloadData];
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}
- (void)goConnectesVC:(UIButton *)button{
    if(button.tag == 1){
        NSArray *device =  [self.centralManager retrievePeripheralsWithIdentifiers:@[[[NSUUID alloc] initWithUUIDString:@"6E61AEFD-4504-F4F3-840F-614F9E41E0FF"]]];
           NSLog(@"device:%@",device);
        CBPeripheral *per = device[0];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:per.state==2?@"已连接":@"未连接" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
- (void)bluteeh{
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *strMessage = nil;
    switch (central.state) {
        case CBManagerStatePoweredOn: {
            //周边外设扫描
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            
            return;
        }
            break;
        case CBManagerStateUnknown: {
            strMessage = @"手机没有识别到蓝牙，请检查手机。";
        }
            break;
        case CBManagerStateResetting: {
            strMessage = @"手机蓝牙已断开连接，重置中...";
        }
            break;
        case CBManagerStateUnsupported: {
            strMessage = @"手机不支持蓝牙功能，请更换手机。";
        }
            break;
        case CBManagerStatePoweredOff: {
            strMessage = @"手机蓝牙功能关闭，请前往设置打开蓝牙及控制中心打开蓝牙。";
        }
            break;
        case CBManagerStateUnauthorized: {
            strMessage = @"手机蓝牙功能没有权限，请前往设置。";
        }
            break;
        default: { }
            break;
    }
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral.name.length == 0) {
        return;
    }
    if(![self.devicesListArray containsObject:peripheral] && peripheral.name>0){
        [self.devicesListArray addObject:peripheral];
    [self.tableView reloadData];
    NSLog(@"%@", peripheral.identifier);
    NSLog(@"%@", RSSI);
    }
    // RSSI 是设备信号强度
    // 一般把新扫描到的设备添加到一个数组中，并更新列表
}
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
  
    [self.tableView reloadData];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    [self.tableView reloadData];
}

#pragma mark ========== UITableViewDelegate ==========
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.devicesListArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"UITableViewCell"];
    CBPeripheral *peripheral = self.devicesListArray[indexPath.row];
    NSString *state = peripheral.state == CBPeripheralStateConnected? @"connected":@"";
    cell.textLabel.text = peripheral.name;
   
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",state,[self.devicesListArray[indexPath.row].identifier UUIDString]];
    
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.centralManager connectPeripheral:self.devicesListArray[indexPath.row] options:nil];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
