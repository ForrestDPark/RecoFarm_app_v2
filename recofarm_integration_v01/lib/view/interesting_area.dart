import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/route_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:new_recofarm_app/view/my_area_list.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/*
  Description : Google map 나의 관심 소재지 등록하기 페이지 
  Date        : 2024.04.21 Sun
  Author      : Forrest DongGeun Park. (PDG)
  Updates     : 
	  2024.04.21 Sun by pdg
		  - google map 추가 및 ios minimum version 14 로 변환 
      - footter 디자인 + 내 관심 경작지로 이동하기 ( 우선 엘리베이트 버튼으로 구현 )
      - 내위치 권한 인증 및 내위치로 첫 지도 카메라 위치 이동 시키기 
      - 위치 권한이 없을 경우 앱을 사용하지 못하는 쪽으로 설계를 하자. 
      - 특정 위치 마커 그리기 
      - 특정 위치 를 기준으로 나의 경작지 면적 을 반경으로 지도위에 표시 하기 
      - geo coding package 를 활용하여 주소 검색 을 해보자. 
        -> json 형태로 주소를 받아오기때문에 http 가 필요함. 
      - 소재지 주소 검색하여 경작지 위치로 이동하는것 완료
      - 소재지에서 관심 작물을 키울때 예측 생산량 보여주는 버튼을 만들어야함. 
      - 지도에서 클릭 했을때 마커 위치 변경하고 해당위치에서의 경작지 면적을 입력받아 반경그림 추가하고 위치경작정보를 누르면
      - 페이지 이동

      2024.04.22 by pdg
        - 처음 페이지 가 현재 내 위치로 나오게 수정?
        - 내 관심 농작지 List view 로 보여주는 기능 필요 ?
        - 내 관심 농작지 페이지 list view 로 보여주는 페이지 를 제작 <- db 조회 필요..
        - sql db 에서 가져와서 listview 로 플랏 해주고 
  Detail      : - 

*/
class InterestingAreaPage extends StatefulWidget {
  const InterestingAreaPage({super.key});

  @override
  State<InterestingAreaPage> createState() => _InterestingAreaPageState();
}

class _InterestingAreaPageState extends State<InterestingAreaPage> {
  // properties
  late TextEditingController locationTfController;
  late LatLng interestLoc;
  late bool islocationEnable;
  late Marker myloc1;
  late Circle myAreaCircle;
  late double myAreaMeterSquare;
  late double myAreaRadius;
  late double distance1;
  late String searchedAddress;
  // google map 컨트롤러!!
  late GoogleMapController mapController;

  // markers
  late List markers;

  // myarea
  late List myareaData;
  @override
  void initState() {
    super.initState();
    locationTfController = TextEditingController(text: "");
    interestLoc = const LatLng(36.595086846, 128.9351767475763);
    //print(interestLoc);
    // 경작지 위치  마커
    myloc1 = Marker(
      markerId: const MarkerId("경작지1"),
      position: interestLoc,
      infoWindow: const InfoWindow(
        title: "내 경작지1",
        snippet: "배추밭, 10000제곱 미터",
      ),
    );
    markers = [myloc1];
    myAreaMeterSquare = 10000; // 100 m^2 -> 3.14 * r^2 =100 ->
    myAreaRadius = sqrt(myAreaMeterSquare / 3.14);
    // 경작지 반경
    myAreaCircle = Circle(
      circleId: CircleId('myloc1'),
      center: interestLoc,
      fillColor: Colors.blue.withOpacity(0.4),
      radius: myAreaRadius,
      strokeColor: Colors.blue,
      strokeWidth: 1,
    );

    // 경작지1 과 현재 위치 간 거리 계산
    distance1 = 0;
    getPlaceAddress(interestLoc.latitude, interestLoc.longitude);

    //
    searchedAddress = "";
    getPlaceAddress(interestLoc.latitude, interestLoc.longitude);
    //searchPlace();
    //
    myareaData = [];
    get_myarea_JSONData("pulpilisory");
  }


  get_myarea_JSONData(userId) async {
      //String userId ;
      String url_address ="http://localhost:8080/myarea?userId=$userId";
      var url =Uri.parse(url_address); 
      var response = await http.get(url);
      print(response.body);
      var dataConvertedJSON = json.decode(utf8.decode(response.bodyBytes));
      List result = dataConvertedJSON;
      myareaData.addAll(result);
      setState(() {});
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber[100],
        actions: [
          IconButton(
              onPressed: () {
                // 소재지 검색 함수
                searchPlace();
              },
              icon: Icon(Icons.search_outlined))
        ],
        title: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 100,
            child: TextField(
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                  // alignLabelWithHint: true,
                  floatingLabelAlignment: FloatingLabelAlignment.start,
                  labelText: "소재지 주소 검색",
                  labelStyle: TextStyle(color: Colors.green[300])),
              controller: locationTfController,
            ),
          ),
        ),
      ),

      // check permission 함수는 future 함수이므로 future builder 를 사용하는 것이 좋다.
      body: FutureBuilder<String>(
        future: checkPermission(),
        builder: (context, snapshot) {
          // 권한 정보가 스냅샷에 없을때  혹은 커넥션을 기다리고 있을때
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.data == "위치 권한이 허가 되었습니다.") {
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: interestLoc,
                        zoom: 14.4746,
                      ),
                      myLocationButtonEnabled: true,
                      markers: Set.from(markers),
                      circles: Set.from([myAreaCircle]),

                      // controller setting
                      onMapCreated: _onMapCreated),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //const Text("내 관심 경작지 리스트(combo box)"),
                      Text(searchedAddress),
                      Text("현위치에서 거리 : ${distance1.toStringAsFixed(2)} km"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // google map 이동
                              
                              // Get.toNamed("/MyAreaList");
                              _showMyAreaActionSheet();
                            },
                            child: Text("내경작지리스트"),
                            
                          ),
                          SizedBox(
                            width: 20,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // 관심농지 추가 하여 마커 색이 변한다. 
                              _addMyAreaActionSheet();
                            },
                            child: Text("관심농지추가"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            );
          } // If end
          // 권한 설정이 안되어있을 때
          return Center(
            child: Text(
              snapshot.data.toString(),
            ),
          );
        },
      ),
    );
  }

  // Function
  // 2024.04.22 추가한 함수 
  _showMyAreaActionSheet(){
    showCupertinoModalPopup(
      semanticsDismissible: true,
      context: context, 
      builder: (context) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CupertinoActionSheet(
            title: const Text("내경작지 리스트"),
            actions: 
              List.generate(
                myareaData.length, (index) => 
                CupertinoActionSheetAction(
                  onPressed: (){
                    print("clicked");
                  },
                  child:Text('''${index+1} . ${myareaData[index]['area_address']}(${myareaData[index]['area_product']})'''
                  ,
                    style: TextStyle(
                      fontSize: 20
                    ),
                  ) ,
                )
                
                )
              
            ,
          )
        );

        //MyAreaList();
        
        },
      barrierDismissible: true,
      
      
      
      );

  }

  _addMyAreaActionSheet() {
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => SizedBox(
        height: 500,
        child: CupertinoActionSheet(
          
          
          title: const Text("관심농지 추가 "),
          message: const Text("관심농지로 추가하시겠습니까?"),
          actions: [
            CupertinoActionSheetAction(
                onPressed: () {
                  print('action is pressed');
                  //면적 입력 받기, 검색한 장소의 위도 경도 , 소재지 이름  넘길 것. 
                  },
                child: const Text("예")),
            CupertinoActionSheetAction(
                onPressed: () {
                  print('action is pressed');
                  Get.back();
                },
                child: const Text("아니오")),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Get.back(),
            child: const Text("Exit"),
          ),
        ),
      ),
    );
  }

  // 2024.04.21 추가한 함수들 
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  searchPlace() async {
    String textsearchUrl =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=";
    String key = "AIzaSyDslR-okT6JXHWhMmrOXaNxXhA6C0LxJHo";
    textsearchUrl += "${locationTfController.text}&language=ko&key=$key";
    var findAddressUri = Uri.parse(textsearchUrl);
    var responsePlace = await http.get(findAddressUri);
    //print(responsePlace.body);
    var dataCovertedJSON = json.decode(utf8.decode(responsePlace.bodyBytes));
    List address_result = dataCovertedJSON['results'];
    searchedAddress = address_result[0]['formatted_address'];
    interestLoc = LatLng(address_result[0]['geometry']['location']['lat'],
        address_result[0]['geometry']['location']['lng']);
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: interestLoc,
          zoom: 14.4746,
        ),
      ),
    );
    var findMarker = Marker(
      markerId: MarkerId(searchedAddress),
      position: interestLoc,
    );

    markers.add(findMarker);
    // 거리계산
    curPos_to_myArea();

    setState(() {});
  }

  // 내가 입력한 주소의 위도경도를 아웃풋.
  getPlaceAddress(double lat, double lng) async {
    //var findLatlngUri =Uri.parse("https:/maps.googleapis.com/maps/api/geocode/json?address=${locationTfController.text}&key=AIzaSyDslR-okT6JXHWhMmrOXaNxXhA6C0LxJHo");
    var findAddressUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ko&key=AIzaSyDslR-okT6JXHWhMmrOXaNxXhA6C0LxJHo');
    //var responseFLU = await http.get(findLatlngUri);
    var responseFAU = await http.get(findAddressUri);

    //print(responseFAU.body);
    var dataCovertedJSON = json.decode(utf8.decode(responseFAU.bodyBytes));
    List address_result = dataCovertedJSON['results'];
    searchedAddress = address_result[0]['formatted_address'];

    // data.addAll(result);
    setState(() {});
  }

  // 내 위치와 관심 경작지 위치의 거리를 계산해줌.
  curPos_to_myArea() async {
    // 현재 위치 파악
    var curPosition = await Geolocator.getCurrentPosition();
    // 내 관심경작지와의 거리 파악
    distance1 = Geolocator.distanceBetween(curPosition.latitude,
        curPosition.longitude, interestLoc.latitude, interestLoc.longitude)/1000.0;
    setState(() {});
    // return LatLng(curPosition.latitude, curPosition.longitude);
  }

  // 내위치  파악 및 권한 설정 함수
  Future<String> checkPermission() async {
    islocationEnable = await Geolocator.isLocationServiceEnabled();

    if (!islocationEnable) {
      return "위치 서비스를 활성화 해주세요.";
    }
    // 위치 권한 확인
    LocationPermission checkedPermission = await Geolocator.checkPermission();

    if (checkedPermission == LocationPermission.denied) {
      // 권한 요청
      checkedPermission = await Geolocator.requestPermission();
      if (checkedPermission == LocationPermission.denied) {
        return "위치 권한을 허가해주세요";
      }
    }
    // 위치 권한 거절됨 ( 앱에서 재요청 불가 )
    if (checkedPermission == LocationPermission.deniedForever) {
      return "앱의 위치 권한을 설정에서 허가해주세요.";
    }

    // 위의 모든 조건이 통과되면 위치 권한 허가 가 완료 된것임.
    return "위치 권한이 허가 되었습니다.";
  }
} // END
