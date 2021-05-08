import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:scrollview_manager/scrollview_manager.dart';

class ScrollViewDemo extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ScrollViewDemoState();
}

class IndexInfo {
  bool first;
  bool center;
  bool last;
  double nearCenterRatio;
  double firstVisibleRatio;
  double lastVisibleRatio;

  IndexInfo(
      {this.first = false,
      this.center = false,
      this.last = false,
      this.nearCenterRatio = 0,
      this.firstVisibleRatio = 0,
      this.lastVisibleRatio = 0});

  @override
  int get hashCode => hashValues(first, center, last, nearCenterRatio,
      firstVisibleRatio, lastVisibleRatio);

  IndexInfo copyWith(
      {bool? first,
      bool? center,
      bool? last,
      double? nearCenterRatio,
      double? firstVisibleRatio,
      double? lastVisibleRatio}) {
    return IndexInfo(
        first: first ?? this.first,
        center: center ?? this.center,
        last: last ?? this.last,
        nearCenterRatio: nearCenterRatio ?? this.nearCenterRatio,
        firstVisibleRatio: firstVisibleRatio ?? this.firstVisibleRatio,
        lastVisibleRatio: lastVisibleRatio ?? this.lastVisibleRatio);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is IndexInfo &&
        other.first == first &&
        other.center == center &&
        other.last == last &&
        other.nearCenterRatio == nearCenterRatio &&
        other.firstVisibleRatio == firstVisibleRatio &&
        other.lastVisibleRatio == lastVisibleRatio;
  }
}

class StateController extends GetxController {
  final List<Rx<IndexInfo>> testStates;

  StateController.fill(int length)
      : testStates =
            List.filled(length, false).map((e) => IndexInfo().obs).toList();

  void updateIndexInfo(int index, IndexInfo indexInfo) {
    if (indexInfo != testStates[index].value) {
      testStates[index].update((val) {
        val!.first = indexInfo.first;
        val.center = indexInfo.center;
        val.last = indexInfo.last;
        val.nearCenterRatio = indexInfo.nearCenterRatio;
        val.firstVisibleRatio = indexInfo.firstVisibleRatio;
        val.lastVisibleRatio = indexInfo.lastVisibleRatio;
      });
    }
  }

  IndexInfo getIndexInfo(int index) {
    return testStates[index].value;
  }
}

class _ScrollViewDemoState extends State<ScrollViewDemo> {
  List<double>? _initHeights;

  ScrollViewManager _scrollViewManager = ScrollViewManager();

  late StateController _stateController;
  int? _nearCenterIndex;
  int? _firstVisibleIndex, _lastVisibleIndex;
  double? _nearCenterRatio, _firstVisibleRatio, _lastVisibleRatio;

  late ScrollController _scrollController;
  double _listSize = 450;

  bool _childFixHeight = false;

  Axis _axis = Axis.vertical;
  bool _reverse = true;

  final Random rd = Random();

  void updateHeights() {
    final int count = _initHeights?.length ?? rd.nextInt(20) + 10000;
    _initHeights = List.generate(count, (index) => rd.nextDouble() * 100 + 40);
    print("_initHeights length => ${_initHeights!.length}");
  }

  void _resetListSize() {
    _listSize = rd.nextDouble() * 350 + 100;
  }

  @override
  void initState() {
    super.initState();
    updateHeights();
    _stateController = Get.put(StateController.fill(_initHeights!.length));
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollViewManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildText(int index, IndexInfo indexInfo) {
    final Widget child = Text(
      indexInfo.center
          ? "$index => center ## ratio: ${indexInfo.nearCenterRatio}"
          : (indexInfo.first
              ? "$index => first ## visible: ${indexInfo.firstVisibleRatio}"
              : (indexInfo.last
                  ? "$index => last ## visible: ${indexInfo.lastVisibleRatio}"
                  : "$index => ${_initHeights![index]}")),
      style: TextStyle(
        fontSize: indexInfo.center
            ? 16
            : (indexInfo.first || indexInfo.last ? 12 : 14),
        color: indexInfo.center ? Colors.black : Colors.white,
        fontWeight: indexInfo.first || indexInfo.last
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: indexInfo.center ? FontStyle.italic : FontStyle.normal,
      ),
    );
    return RotatedBox(
      quarterTurns: _axis == Axis.horizontal ? 1 : 0,
      child: child,
    );
  }

  Widget _buildListView(context) {
    return Container(
      height: _axis == Axis.horizontal
          ? MediaQuery.of(context).size.height - 220
          : _listSize,
      width: _axis == Axis.horizontal ? _listSize : double.infinity,
      color: Colors.black12,
      child: _scrollViewManager.buildScrollView(
          keepScrollPosition: true,
          child: ListView.builder(
            scrollDirection: _axis,
            physics: BouncingScrollPhysics(),
            controller: _scrollController,
            reverse: _reverse,
            itemBuilder: (context, index) {
              return _scrollViewManager.buildChild(
                index: index,
                child: Obx(() {
                  final IndexInfo indexInfo =
                      _stateController.testStates[index].value;
                  return Container(
                    height: _axis == Axis.horizontal
                        ? double.infinity
                        : (!_childFixHeight || !indexInfo.center
                            ? _initHeights![index]
                            : 40),
                    width: _axis == Axis.horizontal
                        ? (!_childFixHeight || !indexInfo.center
                            ? _initHeights![index]
                            : 40)
                        : double.infinity,
                    color: indexInfo.center
                        ? Colors.white
                        : (indexInfo.first || indexInfo.last
                            ? Colors.black
                            : Colors
                                .primaries[index % Colors.primaries.length]),
                    alignment: indexInfo.center
                        ? Alignment.center
                        : (indexInfo.first
                            ? (_reverse
                                ? (_axis == Axis.horizontal
                                    ? Alignment.centerLeft
                                    : Alignment.topCenter)
                                : (_axis == Axis.horizontal
                                    ? Alignment.centerRight
                                    : Alignment.bottomCenter))
                            : (indexInfo.last
                                ? (_reverse
                                    ? (_axis == Axis.horizontal
                                        ? Alignment.centerRight
                                        : Alignment.bottomCenter)
                                    : (_axis == Axis.horizontal
                                        ? Alignment.centerLeft
                                        : Alignment.topCenter))
                                : Alignment.center)),
                    child: _buildText(index, indexInfo),
                  );
                }),
              );
            },
            itemCount: _initHeights!.length,
          ),
          onUpdate: (IScrollDataInterface scrollDataInterface) {
            print(
                "onUpdate => pixels: ${scrollDataInterface.scrollMetrics.pixels}}, firstVisibleIndex: ${scrollDataInterface.firstVisibleIndex}, lastVisibleIndex: ${scrollDataInterface.lastVisibleIndex}, centerVisibleIndex: ${scrollDataInterface.nearCenterVisibleIndex}");
            _updateState(scrollDataInterface);
          },
          onScrollStart: (IScrollDataInterface scrollDataInterface) {
            print(
                "onScrollStart => pixels: ${scrollDataInterface.scrollMetrics.pixels}}, firstVisibleIndex: ${scrollDataInterface.firstVisibleIndex}, lastVisibleIndex: ${scrollDataInterface.lastVisibleIndex}, centerVisibleIndex: ${scrollDataInterface.nearCenterVisibleIndex}");
          },
          onScrollEnd: (IScrollDataInterface scrollDataInterface) {
            print(
                "onScrollEnd => pixels: ${scrollDataInterface.scrollMetrics.pixels}}, firstVisibleIndex: ${scrollDataInterface.firstVisibleIndex}, lastVisibleIndex: ${scrollDataInterface.lastVisibleIndex}, centerVisibleIndex: ${scrollDataInterface.nearCenterVisibleIndex}");
          },
          onScrollUpdate: (IScrollDataInterface scrollDataInterface) {
            print(
                "onScrollUpdate => pixels: ${scrollDataInterface.scrollMetrics.pixels}}, firstVisibleIndex: ${scrollDataInterface.firstVisibleIndex}, lastVisibleIndex: ${scrollDataInterface.lastVisibleIndex}, centerVisibleIndex: ${scrollDataInterface.nearCenterVisibleIndex}");
            _updateState(scrollDataInterface);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ObxValue(
              (RxInt position) {
                print("obxValue position => ${position.value}");
                return RawChip(
                  onPressed: () {
                    _scrollViewManager.jumpTo(position.value * 1.0);
                    position.value = rd.nextInt(10000);
                  },
                  label: Text(
                    "position to ${position.value}",
                  ),
                );
              },
              rd.nextInt(10000).obs,
            ),
            /*Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: ObxValue(
                (RxInt index) {
                  return RawChip(
                    onPressed: () {
                      _scrollViewManager.jumpToIndex(index.value);
                      index.value = rd.nextInt(_initHeights!.length);
                    },
                    label: Text(
                      "index to ${index.value}",
                    ),
                  );
                },
                rd.nextInt(_initHeights!.length).obs,
              ),
            ),*/
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Stack(
                  children: [
                    Builder(builder: (context) {
                      return _buildListView(context);
                    }),
                    Positioned(
                      child: Center(
                        child: Transform.rotate(
                          angle: _axis == Axis.horizontal ? math.pi / 2 : 0,
                          child: Text(
                            "center",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                    ),
                    Positioned(
                      child: Offstage(
                        offstage: _axis != Axis.horizontal,
                        child: VerticalDivider(
                          color: Colors.black,
                          width: 2.0,
                        ),
                      ),
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                    ),
                    Positioned(
                      child: Offstage(
                        offstage: _axis != Axis.vertical,
                        child: Divider(
                          height: 2.0,
                          color: Colors.black,
                        ),
                      ),
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 24,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _resetListSize();
                        });
                      },
                      child: Text("Resize"),
                    ),
                    ChoiceChip(
                      label: Text('Fix Height'),
                      selected: _childFixHeight,
                      onSelected: (v) {
                        setState(() {
                          _childFixHeight = v;
                        });
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          updateHeights();
                        });
                      },
                      child: Text("Update Data"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _axis = _axis == Axis.horizontal
                              ? Axis.vertical
                              : Axis.horizontal;
                        });
                      },
                      child: Text("Change Direction"),
                    ),
                    ChoiceChip(
                      label: Text('Reverse Order'),
                      selected: _reverse,
                      onSelected: (v) {
                        setState(() {
                          _reverse = v;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateIndex(int newIndex, int? oldIndex,
      {bool? first, bool? center, bool? last}) {
    _stateController.updateIndexInfo(
        newIndex,
        _stateController
            .getIndexInfo(newIndex)
            .copyWith(first: first, center: center, last: last));
    if (oldIndex != null) {
      _stateController.updateIndexInfo(
          oldIndex,
          _stateController.getIndexInfo(oldIndex).copyWith(
              first: first != null ? false : null,
              center: center != null ? false : null,
              last: last != null ? false : null));
    }
  }

  void _updateRatio(int index,
      {double? centerRatio, double? firstRatio, double? lastRatio}) {
    _stateController.updateIndexInfo(
        index,
        _stateController.getIndexInfo(index).copyWith(
            nearCenterRatio: centerRatio,
            firstVisibleRatio: firstRatio,
            lastVisibleRatio: lastRatio));
  }

  void _updateState(IScrollDataInterface scrollDataInterface) {
    /*if (scrollDataInterface.nearCenterVisibleIndex < 0) {
      print(
          "===>nearCenterVisibleIndex: ${scrollDataInterface.nearCenterVisibleIndex}, firstVisibleIndex: ${scrollDataInterface.firstVisibleIndex}, lastVisibleIndex: ${scrollDataInterface.lastVisibleIndex}");
    }*/
    if (!scrollDataInterface.hasVisibleChild) return;

    if (scrollDataInterface.firstVisibleIndex != _firstVisibleIndex ||
        scrollDataInterface.firstVisibleRatio != _firstVisibleRatio) {
      if (scrollDataInterface.firstVisibleIndex != _firstVisibleIndex) {
        _updateIndex(scrollDataInterface.firstVisibleIndex, _firstVisibleIndex,
            first: true);
        _firstVisibleIndex = scrollDataInterface.firstVisibleIndex;
      }

      _updateRatio(scrollDataInterface.firstVisibleIndex,
          firstRatio: scrollDataInterface.firstVisibleRatio);
      _firstVisibleRatio = scrollDataInterface.firstVisibleRatio;
    }

    if (scrollDataInterface.lastVisibleIndex != _lastVisibleIndex ||
        scrollDataInterface.lastVisibleRatio != _lastVisibleRatio) {
      if (scrollDataInterface.lastVisibleIndex != _lastVisibleIndex) {
        _updateIndex(scrollDataInterface.lastVisibleIndex, _lastVisibleIndex,
            last: true);
        _lastVisibleIndex = scrollDataInterface.lastVisibleIndex;
      }

      _updateRatio(scrollDataInterface.lastVisibleIndex,
          lastRatio: scrollDataInterface.lastVisibleRatio);
      _lastVisibleRatio = scrollDataInterface.lastVisibleRatio;
    }

    if (scrollDataInterface.nearCenterVisibleIndex != _nearCenterIndex ||
        scrollDataInterface.nearCenterRatio != _nearCenterRatio) {
      if (scrollDataInterface.nearCenterVisibleIndex != _nearCenterIndex) {
        _updateIndex(
            scrollDataInterface.nearCenterVisibleIndex, _nearCenterIndex,
            center: true);
        _nearCenterIndex = scrollDataInterface.nearCenterVisibleIndex;
      }

      _updateRatio(scrollDataInterface.nearCenterVisibleIndex,
          centerRatio: scrollDataInterface.nearCenterRatio);
      _nearCenterRatio = scrollDataInterface.nearCenterRatio;
    }
  }
}
