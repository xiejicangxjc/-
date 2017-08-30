//
//  ViewController.m
//  高德地图定位
//
//  Created by 驿路梨花 on 2017/8/28.
//  Copyright © 2017年 驿路梨花. All rights reserved.
//

#import "ViewController.h"
#import "NaviViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import "TableCell.h"


#import "DriveNaviViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SpeechSynthesizer.h"
#import <AMapNaviKit/AMapNaviKit.h>
#import "QuickStartAnnotationView.h"


@interface ViewController ()<MAMapViewDelegate,AMapLocationManagerDelegate,AMapSearchDelegate,UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource,AMapNaviDriveManagerDelegate,DriveNaviViewControllerDelegate>
@property (nonatomic,strong)MAMapView *mapView;
@property (nonatomic,strong)AMapLocationManager *locationManger;
@property (nonatomic,strong)AMapSearchAPI *search;

@property (nonatomic,copy)NSString *cityName;
@property (nonatomic,copy)NSString *cityAddress;

@property (nonatomic,strong)UITextField *searchTextField;//搜索框
@property (nonatomic,strong)UITableView *resultTableView;//搜索结果展示用
@property (nonatomic,strong)NSMutableArray *nameDatasource;//搜索结果名字展示数据源
@property (nonatomic,strong)NSMutableArray *addressDatasoure;//搜索地址展示数据源
@property (nonatomic,strong)NSMutableArray *locationDatasource;//存放经纬度的数据源

@property (nonatomic,strong)MAPointAnnotation *pointAnnotation2;//点击搜索结果展示定位的点使用
@property (nonatomic,strong) CLLocation *startLocation;//起始点 latitude, location.longitude
@property (nonatomic,assign)double destionlatitude;//结束点经度
@property (nonatomic,assign)double destionlongitude;//结束点纬度

@property (nonatomic, strong) AMapNaviDriveManager *driveManager;
@property (nonatomic,strong)NSMutableArray *pointDatasource;
@property (nonatomic,strong)AMapNaviPoint *endPoint;

@end

@implementation ViewController
- (NSMutableArray *)pointDatasource{
    if (!_pointDatasource) {
        self.pointDatasource =[NSMutableArray array];
    }
    return _pointDatasource;
}
- (NSMutableArray *)nameDatasource{
    if (!_nameDatasource) {
        self.nameDatasource =[NSMutableArray array];
    }
    return _nameDatasource;
}
- (NSMutableArray *)addressDatasoure{
    if (!_addressDatasoure) {
        self.addressDatasoure =[NSMutableArray array];
    }
    return _addressDatasoure;
}
- (NSMutableArray *)locationDatasource{
    if (!_locationDatasource) {
        self.locationDatasource =[NSMutableArray array];
    }
    return _locationDatasource;
}
#define screenWidth  [UIScreen mainScreen].bounds.size.width
#define screenHeight  [UIScreen mainScreen].bounds.size.height
- (UITableView *)resultTableView{
    if (!_resultTableView) {
        self.resultTableView =[[UITableView alloc] initWithFrame:CGRectMake(0, screenWidth-30, screenWidth, screenHeight- screenWidth+30) style:UITableViewStylePlain];
        [self.view addSubview:_resultTableView];
    }
    return _resultTableView;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = YES;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [AMapServices sharedServices].apiKey = @"b3a89ce44857b1628e52f416c3318ba1";
    //初始化，显示地图
    self.mapView =[[MAMapView alloc] initWithFrame:CGRectMake(0, 0,screenWidth, screenWidth-30)];
    _mapView.delegate = self;
    [self.view addSubview:self.mapView];
    //后台定位
    _mapView.pausesLocationUpdatesAutomatically = NO;
    _mapView.allowsBackgroundLocationUpdates = YES;
    //开始定位,需要添加下面两句话//此时就会显示 定位到自己，并显示蓝点，但是此时显示的是整个是市。想要显示自己周边的街道，超市，精确显示，就要添加--
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MAUserTrackingModeFollow;
    //--这句话，哈哈
    [_mapView setZoomLevel:17.5 animated:YES];
    //设置精确定位
   _mapView.desiredAccuracy = kCLLocationAccuracyKilometer;
    //定位自己的图片更换成自己的图片
    [self setUserLocationRePresention];
   
    self.locationManger = [[AMapLocationManager alloc] init];
    self.locationManger.delegate = self;
    self.locationManger.distanceFilter =  200;
    //持续定位返回逆地理编码
    self.locationManger.locatingWithReGeocode = YES;
     [self.locationManger startUpdatingLocation];
 
    self.search =[[AMapSearchAPI alloc] init];
    self.search.delegate = self;
    
    self.searchTextField = [[UITextField alloc] initWithFrame:CGRectMake(30, 30, screenWidth-60-30, 40)];
    self.searchTextField.delegate = self;
    self.searchTextField.backgroundColor =[[UIColor whiteColor] colorWithAlphaComponent:0.5];
    self.searchTextField.placeholder = @"搜索附近的餐厅";
    [self.view addSubview:self.searchTextField];
    
    UIButton *searchBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    searchBtn.frame = CGRectMake(screenWidth-60, 30, 60, 40);
    
    [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
    [searchBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    searchBtn.titleLabel.font =[UIFont systemFontOfSize:13];
    [searchBtn addTarget:self action:@selector(searchBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:searchBtn];
    
    UIButton *driveBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    driveBtn.frame = CGRectMake(0, screenWidth-60, screenWidth/4, 30);
    [driveBtn setTitle:@"驾车" forState:UIControlStateNormal];
    [driveBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [driveBtn addTarget:self action:@selector(driveCar) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:driveBtn];
    
    [self.resultTableView registerNib:[UINib nibWithNibName:@"TableCell" bundle:nil] forCellReuseIdentifier:@"cell"];
//    self.resultTableView.delegate = self;
//    self.resultTableView.dataSource = self;
    
    self.pointAnnotation2 = [[MAPointAnnotation alloc] init];
    
    //这是点击驾驶导航使用的，，，，
    
        self.driveManager =[[AMapNaviDriveManager alloc] init];
        
        self.driveManager.delegate = self;
        
        self.driveManager.updateTrafficInfo = YES;
        
        [self.driveManager setAllowsBackgroundLocationUpdates:YES];
        [self.driveManager setPausesLocationUpdatesAutomatically:NO];

}
#pragma mark 把系统的图标设置成自己的图标
- (void)setUserLocationRePresention{
    MAUserLocationRepresentation *r =[[MAUserLocationRepresentation alloc] init];
    r.showsAccuracyRing = NO;//设置精度圈是否显示默认yes
    r.image =[UIImage imageNamed:@"定位自己"];//定位图标，设置成自己的图片
    [self.mapView updateUserLocationRepresentation:r];
}
#pragma mark 这是添加坐标点的
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id <MAAnnotation>)annotation{
    if ([annotation isKindOfClass:[MAUserLocation class]] ) {
        static NSString *reuse = @"r";
        
        MAAnnotationView *view =[[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuse];
        view.canShowCallout = YES;
        view.frame = CGRectMake(0, 0, 50, 50);
        view.image = [UIImage imageNamed:@"定位自己"];
 
//        UIImageView *img =[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"001"]];
//        img.frame = CGRectMake(0, 0, 30, 50);
//        view.leftCalloutAccessoryView =img;
 
//        UIButton *btn =[UIButton buttonWithType:UIButtonTypeCustom];
//        [btn setTitle:@"导航" forState:UIControlStateNormal];
//        btn.backgroundColor =[UIColor lightGrayColor];
//        btn.frame = CGRectMake(30, 0, 40, 50);
//        view.rightCalloutAccessoryView = btn;
        
        annotation.title = self.cityName;
        annotation.subtitle =  self.cityAddress;
        return  view;
        
    }else{
        //这个方法是自定义的显示的，需要添加QuickStartAnnotationView 这个类，
        static NSString *pointReuseIndetifier = @"QuickStartAnnotationView";
        QuickStartAnnotationView *annotationView = (QuickStartAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        
        if (annotationView == nil)
        {
            annotationView = [[QuickStartAnnotationView alloc] initWithAnnotation:annotation
                                                                  reuseIdentifier:pointReuseIndetifier];
        }
        
        annotationView.canShowCallout = YES;
        annotationView.draggable = NO;
        
        return annotationView;
        //这个方法是用的系统的方法，不是自定义方法
        /*
        static NSString *pointReuseIndentifier = @"pointReuseIndentifier";
        MAPinAnnotationView*annotationView = (MAPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndentifier];
        if (annotationView == nil)
        {
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
        }
        annotationView.canShowCallout= YES;       //设置气泡可以弹出，默认为NO
        annotationView.animatesDrop = YES;        //设置标注动画显示，默认为NO
        annotationView.draggable = NO;        //设置标注可以拖动，默认为NO
        annotationView.pinColor = MAPinAnnotationColorPurple;
        return annotationView;
        */
        
    }
    return  nil;
}
#pragma mark 拖拽方法
- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate{
    
    NSLog(@"newCoordinate::%f,,,,%f",newCoordinate.latitude,newCoordinate.longitude);
}
#pragma mark 这是点击方法.点击每一个图标，会弹出一个view，显示这个图标的具体位置信息
- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view{
    if ([view.annotation isKindOfClass:[MAUserLocation class]] ) {
    
        view.annotation.title = self.cityName;
        view.annotation.subtitle = self.cityAddress;
    }else{
        //这个地方不用实现任何方法，因为在返回地理坐标时重写了- (id)initWithAnnotation:(id <MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier 方法。在这个方法里已经实现了将要展示的view赋值给 leftCalloutAccessoryView 了，在QuickStartAnnotationView类，最后一个方法就是重写的方法
    }
 
}
/*
   此方法会持续定位，通过设置  _mapView.delegate = self; 会不断调用此方法，
   通过此方法也能得到经纬度，通过 CLGeocoder 可以获取具体地理位置信息，如果需要持续定位，可以将 viewdidload 方法里 的 AMapLocationManager 注释掉，以及代理删除掉，
    amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode

    amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location
    这两个代理方法也不再需要了，
 */

#pragma mark 这是定位时走这个方法, 在这里可以得到自己的地址，经纬度，
- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation{
    CLLocation *lo = userLocation.location;
    //把自己的定位赋值给全局变量
    self.startLocation = lo;
    CLLocationCoordinate2D coor = lo.coordinate;
    NSLog(@"得到经纬度:::::%f==%f",coor.latitude,coor.longitude);
    
    CLGeocoder *g =[[CLGeocoder alloc] init];
    
    [g reverseGeocodeLocation:lo completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        CLPlacemark *mark = placemarks.lastObject;
        self.cityName = mark.locality;
        self.cityAddress = mark.subThoroughfare;
        NSLog(@"得到城市名字 ::%@,%@,", self.cityName,self.cityAddress);
    }];
}

/*
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location
{
     [self.locationManger stopUpdatingLocation];
    NSLog(@"5555location:{lat:%f; lon:%f; accuracy:%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
}*/

/*
   调用此方法，上面的方法amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location 将不会再调用了。
 
   此方法通过设置属性 self.locationManger.locatingWithReGeocode = YES; 在定位时返回逆地理编码，不然为空。此方法返回经纬度，据悉地理位置信息。
 */
/*
- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode
{
    NSLog(@"location:{lat:%f; lon:%f; accuracy:%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    if (reGeocode) {
        NSLog(@"reGeocode:%@", reGeocode);
    }
}
*/



#pragma mark 搜索方法
- (void)searchBtn{
    [self.view endEditing:YES];
    [self.addressDatasoure removeAllObjects];
    [self.nameDatasource removeAllObjects];
    [self.locationDatasource removeAllObjects];
    AMapPOIKeywordsSearchRequest *request = [[AMapPOIKeywordsSearchRequest alloc] init];
    
    request.keywords            = self.searchTextField.text;
    request.city                =@"西安";
    request.types               = @"";
    request.requireExtension    = YES;
    
    /*  搜索SDK 3.2.0 中新增加的功能，只搜索本城市的POI。*/
    request.cityLimit           = YES;
    request.requireSubPOIs      = YES;
    //发起搜索请求
    [self.search AMapPOIKeywordsSearch:request];
}
/**  此方法是当你输入时，实现联想搜索，并返回数据，可能不是你需要的，只是一个提示你的，单独实现此方法程序并不调用，需要实现textfield的代理方法 - (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string 每输入一次就会掉用一次这个方法，下面的方法也会掉用一次，返回联想搜索数据。和点击按钮搜索实现方法不一样，返回数据也不一样。
 
 * @brief 输入提示查询回调函数
 * @param request  发起的请求，具体字段参考 AMapInputTipsSearchRequest 。
 * @param response 响应结果，具体字段参考 AMapInputTipsSearchResponse 。
 */
#pragma mark 联想搜索--结果--
- (void)onInputTipsSearchDone:(AMapInputTipsSearchRequest *)request response:(AMapInputTipsSearchResponse *)response{
    if(response.tips.count == 0)
    {
        return;
    }
    //通过AMapInputTipsSearchResponse对象处理搜索结果
    //先清空数组
    [self.nameDatasource removeAllObjects];
    [self.addressDatasoure removeAllObjects];
    [self.locationDatasource removeAllObjects];
    for (AMapTip *p in response.tips) {
        //把搜索结果存在数组
        [self.nameDatasource addObject:p.name];
        [self.addressDatasoure addObject:p.address];
        NSLog(@"%@",p.location);
//        [self.locationDatasource addObject:p.location];
    }
    
    //刷新表视图
    [self.resultTableView reloadData];
}
#pragma mark -搜索按钮点击方法-搜索成功
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response
{
    
     if (response.pois.count == 0){ //查询不到数据
 
    }else{
        [self.mapView removeAnnotations:_pointDatasource];
        [_pointDatasource removeAllObjects];
        [response.pois enumerateObjectsUsingBlock:^(AMapPOI *obj, NSUInteger idx, BOOL *stop) {
            
            MAPointAnnotation *annotation = [[MAPointAnnotation alloc] init];
            [annotation setCoordinate:CLLocationCoordinate2DMake(obj.location.latitude, obj.location.longitude)];
            [annotation setTitle:obj.name];
            [annotation setSubtitle:obj.address];
            [self.pointDatasource addObject:annotation];
         }];
        //下面是展示在tableview上的，点击每一个弹出一个地址的定位，属于单个定位，上面的方法是搜索出来全部展示在mapview上，把上面的方法注释掉，打开下面的，并打开代理就可以使用了。
//        NSArray *array = response.pois;
//        for (int i = 0 ; i < array.count; i ++ ) {
//            AMapPOI *poi = array[i];
//            NSLog(@"名字：%@===地址：%@==电话：%@===距离:%ld",poi.name,poi.address,poi.tel,(long)poi.distance);
//            [self.nameDatasource addObject:poi.name];
//            [self.addressDatasoure addObject:poi.address];
//            //AMapGeoPoint *location;
//            [self.locationDatasource addObject:poi.location];
//        }
        
    }
    [self showPOIAnnotations];
    //在此处刷新界面
    [self.resultTableView reloadData];
}
#pragma mark 掉用这个方法，才会展示在mapview上
- (void)showPOIAnnotations
{
    [self.mapView addAnnotations:_pointDatasource];
    if (self.pointDatasource.count == 1){
        self.mapView.centerCoordinate = [(MAPointAnnotation *)_pointDatasource[0] coordinate];
    }else{
        [self.mapView showAnnotations:_pointDatasource animated:NO];
    }
}
- (BOOL)driveManagerIsNaviSoundPlaying:(AMapNaviDriveManager *)driveManager
{
    return [[SpeechSynthesizer sharedSpeechSynthesizer] isSpeaking];
}

- (void)mapView:(MAMapView *)mapView annotationView:(MAAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if ([view.annotation isKindOfClass:[MAPointAnnotation class]])
    {
        MAPointAnnotation *annotation = (MAPointAnnotation *)view.annotation;
        
        _endPoint = [AMapNaviPoint locationWithLatitude:annotation.coordinate.latitude
                                              longitude:annotation.coordinate.longitude];
        
        [self routePlanAction];
    }
}
- (void)routePlanAction
{
    [self.driveManager calculateDriveRouteWithEndPoints:@[_endPoint]
                                              wayPoints:nil
                                        drivingStrategy:AMapNaviDrivingStrategySingleDefault];
}

- (void)driveManager:(AMapNaviDriveManager *)driveManager playNaviSoundString:(NSString *)soundString soundStringType:(AMapNaviSoundType)soundStringType
{
    NSLog(@"playNaviSoundString:{%ld:%@}", (long)soundStringType, soundString);
    
    [[SpeechSynthesizer sharedSpeechSynthesizer] speakString:soundString];
}

- (void)driveNaviViewCloseButtonClicked
{
    //停止导航
    [self.driveManager stopNavi];
    
    //停止语音
    [[SpeechSynthesizer sharedSpeechSynthesizer] stopSpeak];
    
    [self.navigationController popViewControllerAnimated:NO];
}

















#pragma mark 驾车方法
- (void)driveCar{
//    self.startAnnotation.coordinate = self.startCoordinate;
//    self.destinationAnnotation.coordinate = self.destinationCoordinate;
    
    AMapDrivingRouteSearchRequest *navi = [[AMapDrivingRouteSearchRequest alloc] init];
    
    navi.requireExtension = YES;
    navi.strategy = 5;
    /* 出发点. */
   CLLocationCoordinate2D coordinate = self.startLocation.coordinate;
    navi.origin = [AMapGeoPoint locationWithLatitude:coordinate.latitude
                                           longitude:coordinate.longitude];
    /* 目的地. */
    navi.destination = [AMapGeoPoint locationWithLatitude:self.destionlatitude
                                                longitude:self.destionlongitude];
    
    [self.search AMapDrivingRouteSearch:navi];
}
/* 路径规划搜索回调. */
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response{
    NSLog(@"onRouteSearchDone:=======:%@",response);
    if (response.route == nil){
        return;
    }else{
        NSLog(@"onRouteSearchDone::%@",response);
    }
    //解析response获取路径信息，具体解析见 Demo
}
- (void)driveManagerOnCalculateRouteSuccess:(AMapNaviDriveManager *)driveManager
{
    NSLog(@"onCalculateRouteSuccess");
    
    DriveNaviViewController *driveVC = [[DriveNaviViewController alloc] init];
    [driveVC setDelegate:self];
    
    //将driveView添加为导航数据的Representative，使其可以接收到导航诱导数据
    [self.driveManager addDataRepresentative:driveVC.driveView];
    
    [self.navigationController pushViewController:driveVC animated:NO];
    [self.driveManager startGPSNavi];
}

/***************************************下面是tableView的代理方法********************************************************
************************************************************
**************************************************************
***************************************************************
*************************************************************/
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return  self.nameDatasource.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return  45;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
     TableCell *cell =[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.nameLable.text = self.nameDatasource[indexPath.row];
    cell.addressLable.text = self.addressDatasoure[indexPath.row];
    return  cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.view endEditing:YES];
    AMapGeoPoint *location = self.locationDatasource[indexPath.row];
    
    _pointAnnotation2.coordinate = CLLocationCoordinate2DMake(location.latitude, location.longitude);
    _pointAnnotation2.title = self.nameDatasource[indexPath.row];
    _pointAnnotation2.subtitle = self.addressDatasoure[indexPath.row];
    
    [_mapView addAnnotation:_pointAnnotation2];
    [_mapView setZoomLevel:10.5 animated:YES];

    self.destionlatitude = location.latitude;
    self.destionlongitude = location.longitude;

     // 你可以点击地址的时候 把地址的经纬度赋给
    _mapView.centerCoordinate = CLLocationCoordinate2DMake(location.latitude, location.longitude);
    //这样你点击哪个地址 哪个地址就会显示在地图中间全
 /*
 level: 距离(米)
 22: 2;
 21: 5;
 20: 10;
 19: 20;
 18: 50;
 17: 100;
 16: 200;
 15: 500;
 14: 1000;
 13: 2000;
 12: 5000;
 11: 10000;
 10: 20000;
 9: 25000;
 8: 50000;
 7: 100000;
 6: 200000;
 5: 500000;
 4: 1000000;
 3: 2000000;
 
 */
}







- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return  YES;
}
 
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    AMapInputTipsSearchRequest *tipsRequest = [[AMapInputTipsSearchRequest alloc] init];
    //关键字
    tipsRequest.keywords = self.searchTextField.text;
    //城市
    tipsRequest.city = @"西安";
    
    //执行搜索
    [_search AMapInputTipsSearch: tipsRequest];
    
    NSLog(@"textFieldDidBeginEditing==================");
    return YES;
}
@end
