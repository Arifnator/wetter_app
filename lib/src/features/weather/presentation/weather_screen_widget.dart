import "package:flutter/material.dart";
import "package:flutter_sficon/flutter_sficon.dart";
import "package:http/http.dart" as http;
import "package:video_player/video_player.dart";
import "package:wetter_app/src/features/weather/application/convert_iso8601.dart";
import "dart:convert";
import "package:wetter_app/src/features/weather/application/get_current_condition.dart";
import "package:wetter_app/src/features/weather/application/get_day_from_int.dart";
import "package:wetter_app/src/features/weather/application/get_image_path_hourly.dart";
import "package:wetter_app/src/features/weather/application/get_image_path_weekly.dart";
import "package:wetter_app/src/features/weather/application/get_indication_colors.dart";
import "package:wetter_app/src/features/weather/application/get_indicator_position.dart";
import "package:wetter_app/src/features/weather/application/get_todays_description.dart";
import "package:wetter_app/src/features/weather/presentation/hourly_weather_widget.dart";
import "package:wetter_app/src/features/weather/presentation/show_description_alert.dart";
import "package:wetter_app/src/features/weather/presentation/weekly_weather_widget.dart";

class WeatherScreenWidget extends StatefulWidget {
  const WeatherScreenWidget(
      {super.key,
      required this.name,
      required this.admin1AndCountry,
      required this.latitude,
      required this.longitude,
      required this.bottombarColor});
  final String name;
  final String admin1AndCountry;
  final double latitude;
  final double longitude;
  final ValueNotifier<Color> bottombarColor;

  @override
  State<WeatherScreenWidget> createState() => _WeatherScreenWidgetState();
}

class _WeatherScreenWidgetState extends State<WeatherScreenWidget> {
  late VideoPlayerController _sunnyController;
  late VideoPlayerController _rainyController;
  late VideoPlayerController _rainyNightController;
  late VideoPlayerController _cloudyDayController;
  late VideoPlayerController _cloudyNightController;

  late VideoPlayerController _currentVideoController;
  late Color _widgetColor;

  String? _errorMessage;
  String? _descriptionText;
  double? _currentTemp;
  double? _currentPrecipitation;
  int? _currentCloudCover;
  String? _currentCondition;
  int? _todayPrecipitation;
  double? _todayMaxTemp;
  double? _todayMinTemp;
  String? _todaySunriseTime;
  String? _todaySunsetTime;
  Map<int, Map<String, dynamic>> _hourlyWeatherData = {};
  Map<String, Map<String, dynamic>> _dailyWeatherData = {};

  bool _isWeatherDataLoading = true;

  @override
  void initState() {
    super.initState();

    requestWeatherData();

    _sunnyController = VideoPlayerController.asset("assets/videos/sunny.mp4")
      ..initialize().then((value) => {setState(() {})});
    _sunnyController.setLooping(true);
    _sunnyController.setVolume(0.0);
    _sunnyController.play();

    _rainyController = VideoPlayerController.asset("assets/videos/regentag.mp4")
      ..initialize().then((value) => {setState(() {})});
    _rainyController.setLooping(true);
    _rainyController.setVolume(0.0);
    _rainyController.play();

    _rainyNightController =
        VideoPlayerController.asset("assets/videos/rainynight.mov")
          ..initialize().then((value) => {setState(() {})});
    _rainyNightController.setLooping(true);
    _rainyNightController.setVolume(0.0);
    _rainyNightController.play();

    _cloudyDayController =
        VideoPlayerController.asset("assets/videos/bewolkt.mp4")
          ..initialize().then((value) => {setState(() {})});
    _cloudyDayController.setLooping(true);
    _cloudyDayController.setVolume(0.0);
    _cloudyDayController.play();

    _cloudyNightController =
        VideoPlayerController.asset("assets/videos/cloudynight.mp4")
          ..initialize().then((value) => {setState(() {})});
    _cloudyNightController.setLooping(true);
    _cloudyNightController.setVolume(0.0);
    _cloudyNightController.play();

    _currentVideoController = _sunnyController;
    _widgetColor = Colors.blue;
  }

  Future<void> requestWeatherData() async {
    setState(() {
      _isWeatherDataLoading = true;
    });

    var headersList = {
      "Accept": "*/*",
      "User-Agent": "Thunder Client (https://www.thunderclient.com)"
    };
    var url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=${widget.latitude.toString()}&longitude=${widget.longitude.toString()}&current=temperature_2m%2Cprecipitation%2Ccloud_cover&hourly=temperature_2m%2Cprecipitation_probability%2Cprecipitation%2Ccloud_cover&daily=temperature_2m_max%2Ctemperature_2m_min%2Csunrise%2Csunset%2Cprecipitation_sum%2Cprecipitation_probability_max&timezone=auto");

    try {
      var req = http.Request("GET", url);
      req.headers.addAll(headersList);

      var res = await req.send();
      final resBody = await res.stream.bytesToString();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> data = json.decode(resBody);
        setState(() {
          _isWeatherDataLoading = false;

          _todaySunriseTime = convertIso8601ToTime(data["daily"]["sunrise"][0]);
          _todaySunsetTime = convertIso8601ToTime(data["daily"]["sunset"][0]);

          _currentTemp = data["current"]["temperature_2m"];
          _currentPrecipitation = data["current"]["precipitation"];
          _currentCloudCover = data["current"]["cloud_cover"];
          _currentCondition = getCurrentCondition(
              _currentPrecipitation!,
              _currentCloudCover!,
              _todaySunriseTime!,
              _todaySunsetTime!,
              DateTime.now().hour);

          updateVideoController(_currentPrecipitation!, _currentCloudCover!,
              _todaySunriseTime!, _todaySunsetTime!, DateTime.now().hour);

          // var tempList = data["hourly"]["temperature_2m"];

          // var findMax = tempList[0];
          // for (var i = 0; i < tempList.length; i++) {
          //   if (tempList[i] > findMax) {
          //     findMax = tempList[i];
          //   }
          // }
          _todayMaxTemp = data["daily"]["temperature_2m_max"][0];

          // var findMin = tempList[0];
          // for (var i = 0; i < tempList.length; i++) {
          //   if (tempList[i] < findMin) {
          //     findMin = tempList[i];
          //   }
          // }
          _todayMinTemp = data["daily"]["temperature_2m_min"][0];

          final hourlyWeatherMap = <int, Map<String, dynamic>>{};

          for (int i = DateTime.now().hour + 1;
              i <= (DateTime.now().hour + 24);
              i++) {
            hourlyWeatherMap[i] = {
              "temperature": data["hourly"]["temperature_2m"][i],
              "precipitationprobability": data["hourly"]
                  ["precipitation_probability"][i],
              "precipitation": data["hourly"]["precipitation"][i],
              "cloudcover": data["hourly"]["cloud_cover"][i],
            };
          }
          _hourlyWeatherData = hourlyWeatherMap;
          _descriptionText = getTodaysDescription(_hourlyWeatherData);

          final dailyWeatherMap = <String, Map<String, dynamic>>{};

          for (int i = 1; i <= 6; i++) {
            int dayInt = DateTime.now().weekday + i;
            String day = getDayFromInt(dayInt > 7 ? dayInt - 7 : dayInt);
            dailyWeatherMap[day] = {
              "temperature_2m_max": data["daily"]["temperature_2m_max"][i],
              "temperature_2m_min": data["daily"]["temperature_2m_min"][i],
              "precipitation_probability_max": data["daily"]
                  ["precipitation_probability_max"][i],
            };
          }

          _dailyWeatherData = dailyWeatherMap;

          _todayPrecipitation =
              data["daily"]["precipitation_probability_max"][0];
        });
      } else {
        setState(() {
          _isWeatherDataLoading = false;
          _errorMessage = "Error: ${res.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        _isWeatherDataLoading = false;
        _errorMessage = "Exception: $e";
      });
    }
  }

  void updateVideoController(double precipitation, int cloudCover,
      String sunriseTime, String sunsetTime, int hour) {
    final int sunriseHour = int.tryParse(sunriseTime.split(':')[0])!;
    final int sunsetHour = int.tryParse(sunsetTime.split(':')[0])!;
    final bool isDayTime = hour >= sunriseHour && hour < sunsetHour;

    VideoPlayerController newController;
    Color newWidgetColor = Colors.transparent;

    if (precipitation > 0) {
      newController = isDayTime
          ? (cloudCover > 75 ? _rainyController : _sunnyController)
          : _rainyNightController;
      newWidgetColor = isDayTime
          ? (cloudCover > 75 ? Colors.blueGrey : Colors.blue)
          : Colors.black;
    } else if (cloudCover > 75) {
      newController = isDayTime ? _cloudyDayController : _cloudyNightController;
      newWidgetColor = isDayTime ? Colors.blueGrey : Colors.black;
    } else if (cloudCover > 25) {
      newController = isDayTime ? _sunnyController : _cloudyNightController;
      newWidgetColor = isDayTime ? Colors.blue : Colors.black;
    } else {
      newController = isDayTime ? _sunnyController : _cloudyNightController;
      newWidgetColor = isDayTime ? Colors.blue : Colors.black;
    }

    setState(() {
      _currentVideoController = newController;
      _currentVideoController.play();
      _widgetColor = newWidgetColor;
      widget.bottombarColor.value = newWidgetColor;
    });
  }

  @override
  void dispose() {
    _sunnyController.dispose();
    _rainyController.dispose();
    _rainyNightController.dispose();
    _cloudyDayController.dispose();
    _cloudyNightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _currentVideoController.value.size.width,
              height: _currentVideoController.value.size.height,
              child: _currentVideoController.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _currentVideoController.value.aspectRatio,
                      child: VideoPlayer(_currentVideoController),
                    )
                  : Container(),
            ),
          ),
        ),
        SizedBox.expand(
          child: RefreshIndicator(
            backgroundColor: Colors.transparent,
            color: Colors.white,
            onRefresh: requestWeatherData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 87),
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 25.5, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                      height: 20,
                      child: Text(
                        widget.admin1AndCountry,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      )),
                  SizedBox(
                    height: 90,
                    child: _isWeatherDataLoading
                        ? const SizedBox(
                            height: 90,
                            width: 90,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                        : Text(
                            _currentTemp != null
                                ? "  ${_currentTemp?.toStringAsFixed(0)}°"
                                : "N/A",
                            style: const TextStyle(
                                fontSize: 90,
                                fontWeight: FontWeight.w200,
                                color: Colors.white,
                                height: 1),
                          ),
                  ),
                  SizedBox(
                    height: 23,
                    child: _isWeatherDataLoading
                        ? const SizedBox()
                        : Text(
                            _currentCondition ?? "N/A",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  SizedBox(
                    height: 16,
                    child: _isWeatherDataLoading
                        ? const SizedBox()
                        : Text(
                            _currentTemp != null
                                ? "H: ${_todayMaxTemp?.toStringAsFixed(0)}° T: ${_todayMinTemp?.toStringAsFixed(0)}°"
                                : "N/A",
                            style: const TextStyle(
                                fontSize: 16,
                                height: 0,
                                letterSpacing: 0,
                                color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    height: 30,
                    child: _isWeatherDataLoading
                        ? const SizedBox()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 17,
                                child: Image.asset(
                                  "assets/images/sunrise.png",
                                ),
                              ),
                              Text(
                                "  $_todaySunriseTime",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(
                                width: 70,
                              ),
                              SizedBox(
                                height: 17,
                                child: Image.asset(
                                  "assets/images/sunset.png",
                                ),
                              ),
                              Text(
                                "  $_todaySunsetTime",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(
                    height: 29,
                    child: _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.red),
                          )
                        : const SizedBox(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    child: Container(
                      height: 136,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: _widgetColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(13)),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 30,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 13.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _isWeatherDataLoading
                                    ? const SizedBox()
                                    : GestureDetector(
                                        onTap: () {
                                          showDescriptionAlert(context,
                                              _widgetColor, _descriptionText!);
                                        },
                                        child: Text(
                                          _descriptionText!,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.2,
                                              height: 0,
                                              fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const Divider(
                            indent: 13,
                            thickness: 0.4,
                          ),
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: _isWeatherDataLoading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          HourlyWeather(
                                            time: "Jetzt",
                                            imagePath:
                                                getImagePathWeatherConditions(
                                                    _currentPrecipitation!,
                                                    _currentCloudCover!,
                                                    _todaySunriseTime ?? "6:00",
                                                    _todaySunsetTime ?? "20:00",
                                                    DateTime.now().hour),
                                            temperature: _currentTemp != null
                                                ? "  ${_currentTemp?.toStringAsFixed(0)}°"
                                                : "N/A",
                                          ),
                                          ..._hourlyWeatherData.entries.map(
                                            (entry) {
                                              final hour = entry.key > 24
                                                  ? entry.key - 24
                                                  : entry.key;
                                              final data = entry.value;
                                              return HourlyWeather(
                                                time:
                                                    "${hour == 24 ? "00" : hour} Uhr",
                                                imagePath:
                                                    getImagePathWeatherConditions(
                                                  data["precipitationprobability"]
                                                      .toDouble(),
                                                  data["cloudcover"],
                                                  _todaySunriseTime!,
                                                  _todaySunsetTime!,
                                                  hour,
                                                ),
                                                temperature:
                                                    "${data["temperature"]?.toStringAsFixed(0)}°",
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    child: Container(
                      height: 312,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: _widgetColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(13)),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 6,
                          ),
                          const SizedBox(
                            width: double.infinity,
                            height: 21,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 13.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    SFIcon(
                                      SFIcons.sf_calendar,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      " 7-TAGE-VORHERSAGE",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          height: 0,
                                          fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(
                            indent: 13,
                            thickness: 0.4,
                            endIndent: 13,
                          ),
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: _isWeatherDataLoading
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 13.0),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const SizedBox(
                                                  width: 46,
                                                  child: Text(
                                                    "Heute",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15.4,
                                                        height: 0,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                ),
                                                Image.asset(
                                                  getImagePathWeekly(
                                                      _todayPrecipitation!),
                                                ),
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        "${_todayMinTemp?.toStringAsFixed(0)}°  ",
                                                        style: TextStyle(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.5),
                                                            fontSize: 15.4,
                                                            height: 0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                      ),
                                                    ),
                                                    Stack(
                                                      children: [
                                                        Container(
                                                          width: 91,
                                                          height: 2.5,
                                                          decoration:
                                                              BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  gradient:
                                                                      LinearGradient(
                                                                          colors: [
                                                                        ...getIndicationColors(
                                                                            _todayMinTemp!,
                                                                            _todayMaxTemp!),
                                                                      ])),
                                                        ),
                                                        Positioned(
                                                          left: getIndicatorPosition(
                                                              _currentTemp!,
                                                              _todayMinTemp!,
                                                              _todayMaxTemp!,
                                                              88),
                                                          child: Container(
                                                            width: 3,
                                                            height: 2.5,
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              border:
                                                                  Border.all(
                                                                strokeAlign:
                                                                    BorderSide
                                                                        .strokeAlignOutside,
                                                                color:
                                                                    _widgetColor,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        "${_todayMaxTemp?.toStringAsFixed(0)}°",
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 15.4,
                                                            height: 0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          ..._dailyWeatherData.entries.map(
                                            (entry) {
                                              final day = entry.key;
                                              final data = entry.value;
                                              return WeeklyWeatherWidget(
                                                day: day,
                                                imagePath: getImagePathWeekly(data[
                                                    "precipitation_probability_max"]),
                                                minTemp:
                                                    data["temperature_2m_min"],
                                                indicationColors:
                                                    getIndicationColors(
                                                        data[
                                                            "temperature_2m_min"],
                                                        data[
                                                            "temperature_2m_max"]),
                                                widgetColor: _widgetColor,
                                                maxTemp:
                                                    data["temperature_2m_max"],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
