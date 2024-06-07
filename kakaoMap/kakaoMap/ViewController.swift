//
//  ViewController.swift
//  kakaoMap
//
//  Created by 차지용 on 5/31/24.
//

import UIKit
import KakaoMapsSDK
import CoreLocation

extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 24) & 0xff) / 255.0
        let green = CGFloat((hex >> 16) & 0xff) / 255.0
        let blue = CGFloat((hex >> 8) & 0xff) / 255.0
        let alpha = CGFloat(hex & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}


class ViewController: UIViewController, MapControllerDelegate, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager!
    var mapContainer: KMViewContainer?
    var mapController: KMController?
    var _observerAdded: Bool
    var _auth: Bool
    var _appear: Bool
    
    var latitude: Double?
    var longitude: Double?
    
    var resultLis = [Place]()
    
    
    

    required init?(coder aDecoder: NSCoder) {
        _observerAdded = false
        _auth = false
        _appear = false
        super.init(coder: aDecoder)
        SDKInitializer.InitSDK(appKey: "57508ed70cf99d7a7f29859b737d471e")
    }
    
    deinit {
        mapController?.pauseEngine()
        mapController?.resetEngine()
        
        print("deinit")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let kakaoSearch = UISearchBar()
        kakaoSearch.translatesAutoresizingMaskIntoConstraints = false
        kakaoSearch.placeholder = "장소를 입력해주세요"
//        self.navigationItem.titleView = kakaoSearch
        view.addSubview(kakaoSearch)
        
        mapContainer = self.view as? KMViewContainer
        
        //KMController 생성.
        mapController = KMController(viewContainer: mapContainer!)
        mapController!.delegate = self
        
        mapController?.prepareEngine() //엔진 초기화. 엔진 내부 객체 생성 및 초기화가 진행된다.
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization() //앱 사용 중에 위치 서비스를 사용할 수 있도록 사용자의 권한을 요청
        locationManager.startUpdatingLocation() //사용자의 현재위치를 알려주는 메소드
        
        latitude = locationManager.location?.coordinate.latitude
        longitude = locationManager.location?.coordinate.longitude
        
        NSLayoutConstraint.activate([
            kakaoSearch.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            kakaoSearch.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            kakaoSearch.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            kakaoSearch.heightAnchor.constraint(equalToConstant: 44)
        ])
       

    }
    
    //검색URL
    func fetchGetUrl() {
        guard let url = URL(string: "kakaomap://open?page=placeSearch") else {
            print("nil!!")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        addObservers()
        _appear = true
        
        if mapController?.isEngineActive == false {
            mapController?.activateEngine()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        _appear = false
        mapController?.pauseEngine()  //렌더링 중지.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        removeObservers()
        mapController?.resetEngine()     //엔진 정지. 추가되었던 ViewBase들이 삭제된다.
    }
    
    // 인증 실패시 호출.
    func authenticationFailed(_ errorCode: Int, desc: String) {
        print("error code: \(errorCode)")
        print("desc: \(desc)")
        _auth = false
        switch errorCode {
        case 400:
            showToast(self.view, message: "지도 종료(API인증 파라미터 오류)")
            break;
        case 401:
            showToast(self.view, message: "지도 종료(API인증 키 오류)")
            break;
        case 403:
            showToast(self.view, message: "지도 종료(API인증 권한 오류)")
            break;
        case 429:
            showToast(self.view, message: "지도 종료(API 사용쿼터 초과)")
            break;
        case 499:
            showToast(self.view, message: "지도 종료(네트워크 오류) 5초 후 재시도..")
            
            // 인증 실패 delegate 호출 이후 5초뒤에 재인증 시도..
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("retry auth...")
                
                self.mapController?.prepareEngine()
            }
            break;
        default:
            break;
        }
    }
    
    func addViews() {
        //여기에서 그릴 View(KakaoMap, Roadview)들을 추가한다.
        let defaultPosition: MapPoint = MapPoint(longitude: 126.826153, latitude: 37.493912)
        //지도(KakaoMap)를 그리기 위한 viewInfo를 생성
        let mapviewInfo: MapviewInfo = MapviewInfo(viewName: "mapview", viewInfoName: "map", defaultPosition: defaultPosition, defaultLevel: 13)
        
        //KakaoMap 추가.
        mapController?.addView(mapviewInfo)
    }
    
    //addView 성공 이벤트 delegate. 추가적으로 수행할 작업을 진행한다.
    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
        print("OK") //추가 성공. 성공시 추가적으로 수행할 작업을 진행한다.
        createLabelLay() // 라벨 레이어 생성
        createPoiStyle() // POI 스타일 생성
        createPois() // POI 생성
        
        createRouteStyleSet()
        createRouteline()
    }
    
    //addView 실패 이벤트 delegate. 실패에 대한 오류 처리를 진행한다.
    func addViewFailed(_ viewName: String, viewInfoName: String) {
        print("Failed")
    }
    
    //Container 뷰가 리사이즈 되었을때 호출된다. 변경된 크기에 맞게 ViewBase들의 크기를 조절할 필요가 있는 경우 여기에서 수행한다.
    func containerDidResized(_ size: CGSize) {
        let mapView: KakaoMap = mapController?.getView("mapView") as! KakaoMap
        mapView.changeViewInfo(appName: "open", viewInfoName: "cadastral_map")
    }
    
    func viewWillDestroyed(_ view: ViewBase) {
        
    }
    
    func addObservers(){
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        _observerAdded = true
    }
    
    func removeObservers(){
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        
        _observerAdded = false
    }
    
    @objc func willResignActive(){
        mapController?.pauseEngine()  //뷰가 inactive 상태로 전환되는 경우 렌더링 중인 경우 렌더링을 중단.
    }
    
    @objc func didBecomeActive(){
        mapController?.activateEngine() //뷰가 active 상태가 되면 렌더링 시작. 엔진은 미리 시작된 상태여야 함.
    }
    
    func showToast(_ view: UIView, message: String, duration: TimeInterval = 2.0) {
        let toastLabel = UILabel(frame: CGRect(x: view.frame.size.width/2 - 150, y: view.frame.size.height-100, width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = NSTextAlignment.center;
        view.addSubview(toastLabel)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        
        UIView.animate(withDuration: 0.4,
                       delay: duration - 0.4,
                       options: UIView.AnimationOptions.curveEaseOut,
                       animations: {
            toastLabel.alpha = 0.0
        },
                       completion: { (finished) in
            toastLabel.removeFromSuperview()
        })
    }
    
    //권한설정 하는 함수
    func getLcoationUsagePermission() {
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        //authorizedAlways: 사용자는 언제든지 위치 서비스를 시작하도록 앱을 승인, authorizedWhenInUse: 사용자가 앱을 사용하는 동안 위치 서비스를 시작하도록 앱을 승인했습니다.
        case.authorizedAlways, .authorizedWhenInUse:
            print("GPS 권한 설정")
        //restricted: 해당 앱은 위치서비를 사용할 권한이 없음 ,notDetermined: 사용자가 앱에서 위치 서비스를 사용할 수 있는지 여부를 선택하지 않음
        case.restricted, .notDetermined:
            print("GPS 권한 설정되지 않음")
            getLcoationUsagePermission()
        //사용자가 앱의 위치 서비스 사용을 거부했거나 설정에서 전체적으로 비활성화됨
        case .denied:
            print("GPS 권한 요청 거부됨")
            getLcoationUsagePermission()
        default:
            print("GPS: Default")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location: CLLocation = locations[locations.count - 1]
        let longtitude: CLLocationDegrees = location.coordinate.longitude //경도
        let latitude: CLLocationDegrees = location.coordinate.latitude // 위도
        
    }
    
    //Poi생셩을 위한 LabelLayer
    func createLabelLay() {
        let view = mapController?.getView("mapview") as! KakaoMap
        let manager = view.getLabelManager()
        let layerOption = LabelLayerOptions(layerID: "PoiLayer", competitionType: .none, competitionUnit: .symbolFirst, orderType: .rank, zOrder: 0)
        let _ = manager.addLabelLayer(option: layerOption)
    }
    
    //Poi 표시 스타일 생성
    func createPoiStyle() {
        let view = mapController?.getView("mapview") as! KakaoMap
        let manager = view.getLabelManager()
        
        // PoiBadge는 스타일에도 추가될 수 있다. 이렇게 추가된 Badge는 해당 스타일이 적용될 때 함께 그려진다.
        let noti1 = PoiBadge(badgeID: "badge1", image: UIImage(systemName: "message.fill"), offset: CGPoint(x: 0.9, y: 0.1), zOrder: 0)
        let iconStyle1 = PoiIconStyle(symbol: UIImage(systemName: "message"), anchorPoint: CGPoint(x: 0.0, y: 0.5), badges: [noti1])
        let poiStyle = PoiStyle(styleID: "PerLevelStyle", styles: [
            PerLevelPoiStyle(iconStyle: iconStyle1, level: 13)
        ])

    }
    
    func createPois() {
        if let view = mapController?.getView("mapview") as? KakaoMap {
            let manager = view.getLabelManager()
            let layer = manager.getLabelLayer(layerID: "PoiLayer")
            let poiOption = PoiOptions(styleID: "PerLevelStyle")
            poiOption.rank = 0
            
            if let poi1 = layer?.addPoi(option: poiOption, at: MapPoint(longitude: 126.826153, latitude: 37.493912)) {
                let badge = PoiBadge(badgeID: "noti", image: UIImage(systemName: "message.fill"), offset: CGPoint(x: 0, y: 0), zOrder: 1)
                poi1.addBadge(badge)
                poi1.show()
                poi1.showBadge(badgeID: "noti")
            } else {
                print("Poi 생성 실패")
            }
        } else {
            print("KakaoMap 뷰를 가져오지 못했습니다.")
        }
    }
    
    // RouteStyleSet을 생성합니다.
    func createRouteStyleSet() {
        let mapView = mapController?.getView("mapview") as? KakaoMap
        let manager = mapView?.getRouteManager()
        let _ = manager?.addRouteLayer(layerID: "RouteLayer", zOrder: 0)
        let patternImages = [
            UIImage(named: "route_pattern_arrow.png"),
            UIImage(named: "route_pattern_walk.png"),
            UIImage(named: "route_pattern_long_dot.png")
        ]

        // StyleSet에 pattern을 추가합니다.
        let styleSet = RouteStyleSet(styleID: "routeStyleSet1")
        styleSet.addPattern(RoutePattern(pattern: patternImages[0]!, distance: 60, symbol: nil, pinStart: false, pinEnd: false))
        styleSet.addPattern(RoutePattern(pattern: patternImages[1]!, distance: 6, symbol: nil, pinStart: true, pinEnd: true))
        styleSet.addPattern(RoutePattern(pattern: patternImages[2]!, distance: 6, symbol: UIImage(named: "route_pattern_long_airplane.png")!, pinStart: true, pinEnd: true))

        let colors = [
            UIColor(hex: 0x7796ffff),
            UIColor(hex: 0x343434ff),
            UIColor(hex: 0x3396ff00),
            UIColor(hex: 0xee63ae00)
        ]

        let strokeColors = [
            UIColor(hex: 0xffffffff),
            UIColor(hex: 0xffffffff),
            UIColor(hex: 0xffffff00),
            UIColor(hex: 0xffffff00)
        ]

        let patternIndex = [-1, 0, 1, 2]

        // 총 4개의 스타일을 생성합니다.
        for index in 0 ..< colors.count {
            let perLevelStyle = PerLevelRouteStyle(
                width: 18,
                color: colors[index],
                strokeWidth: 4,
                strokeColor: strokeColors[index],
                level: 0,
                patternIndex: patternIndex[index]
            )
            let routeStyle = RouteStyle(styles: [perLevelStyle])
            styleSet.addStyle(routeStyle)
        }

        manager?.addRouteStyleSet(styleSet)
        
        print("Creating route style set...")
    }
    // 예시로 사용할 경로 점 배열을 반환하는 함수입니다.
    func routeSegmentPoints() -> [[MapPoint]] {
        return [
            [MapPoint(longitude: 126.826153, latitude: 37.493912), MapPoint(longitude: 126.9816413, latitude: 37.5703772)],
            [MapPoint(longitude: 126.826153, latitude: 37.493912), MapPoint(longitude: 126.824218, latitude: 37.495744)],
            [MapPoint(longitude: 126.824218, latitude: 37.495744), MapPoint(longitude: 126.822228, latitude: 37.498853)],
            [MapPoint(longitude: 126.822228, latitude: 37.498853), MapPoint(longitude: 126.8201086, latitude: 37.5026084)],
        ]
    }
    
    func createRouteline() {
        let mapView = mapController?.getView("mapview") as! KakaoMap
        let manager = mapView.getRouteManager()

        // Route 생성을 위해 RouteLayer를 생성한다.
        let layer = manager.addRouteLayer(layerID: "RouteLayer", zOrder: 0)

        // Route 생성을 위한 RouteSegment 생성
        let segmentPoints = routeSegmentPoints()
        var segments: [RouteSegment] = []
        var styleIndex: UInt = 0

        for points in segmentPoints {
            // 경로 포인트로 RouteSegment 생성. 사용할 스타일 인덱스도 지정.
            let seg = RouteSegment(points: points, styleIndex: styleIndex)
            segments.append(seg)
            styleIndex = (styleIndex + 1) % 4
        }

        // RouteOptions 생성
        let routeOptions = RouteOptions(styleID: "routeStyleSet1", zOrder: 0)

        // RouteLayer에 Route 추가
        let route = layer?.addRoute(option: routeOptions, callback: { route in
            guard let route = route else { return }
            // Route 객체에 세그먼트를 설정
            route.changeStyleAndData(styleID: "routeStyleSet1", segments: segments)
            route.show()
        })
    }




}

