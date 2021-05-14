import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scrollview_manager/scrollview_manager.dart';
import 'scrollview_manager_demo.dart';

void main() => runApp(ScrollViewDemo()/**SimpleScrollViewDemo()**/);

class SimpleScrollViewDemo extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SimpleScrollViewDemoState();
}

class _SimpleScrollViewDemoState extends State<SimpleScrollViewDemo> {
  double _height = 360;
  Axis _axis = Axis.vertical;
  Random _random = Random();

  RxInt _first = RxInt(-1);
  RxInt _center = RxInt(-1);
  RxInt _last = RxInt(-1);

  ScrollViewManager _scrollViewManager = ScrollViewManager();

  ScrollController _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    _scrollViewManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: _buildTitle(),
        ),
        body: Column(
          children: [
            _buildListView(),
            _buildBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Obx(() {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "first: ${_first.value}  "),
            TextSpan(text: "center: ${_center.value}  "),
            TextSpan(text: "last: ${_last.value}"),
          ],
        ),
        style: TextStyle(
          fontSize: 14,
        ),
      );
    });
  }

  Widget _buildBtn() {
    return Row(
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              _height = _random.nextInt(100) + 120.0;
            });
          },
          child: Text("Resize"),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _axis =
                  _axis == Axis.horizontal ? Axis.vertical : Axis.horizontal;
            });
          },
          child: Text("Change Direction"),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return Container(
      color: Colors.black12,
      height: _height,
      width: double.infinity,
      child: _scrollViewManager.buildScrollView(
        child: ListView.builder(
          scrollDirection: _axis,
          controller: _controller,
          itemBuilder: (_, index) {
            return _scrollViewManager.buildChild(
              index: index,
              child: Container(
                color: Colors.primaries[index % Colors.primaries.length],
                height: _axis == Axis.vertical ? (_random.nextDouble() * 80 + 20) : null,
                width: _axis == Axis.horizontal ? (_random.nextDouble() * 80 + 20) : null,
                alignment: Alignment.center,
                child: Text("$index"),
              ),
            );
          },
        ),
        onUpdate: _updateIndex,
        onScrollUpdate: _updateIndex,
      ),
    );
  }

  /*final List<int> _dataList = List.generate(1000, (index) => index);

  Widget _buildListView2() {
    return Container(
      color: Colors.black12,
      height: _height,
      width: double.infinity,
      child: _scrollViewManager.buildScrollView(
        child: ListView(
          scrollDirection: _axis,
          controller: _controller,
          children: _dataList.map((index) {
            return _scrollViewManager.buildChild(
              index: index,
              child: Container(
                color: Colors.primaries[index % Colors.primaries.length],
                height: _axis == Axis.vertical ? (_random.nextDouble() * 80 + 20) : null,
                width: _axis == Axis.horizontal ? (_random.nextDouble() * 80 + 20) : null,
                alignment: Alignment.center,
                child: Text("$index"),
              ),
            );
          }).toList(),
        ),
        onUpdate: _updateIndex,
        onScrollUpdate: _updateIndex,
      ),
    );
  }*/

  void _updateIndex(IScrollDataInterface scrollDataInterface) {
    if (!scrollDataInterface.hasVisibleChild) return;
    _first.value = scrollDataInterface.firstVisibleIndex;
    _center.value = scrollDataInterface.nearCenterVisibleIndex;
    _last.value = scrollDataInterface.lastVisibleIndex;
  }
}
