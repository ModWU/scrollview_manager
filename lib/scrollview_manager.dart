import 'package:flutter/cupertino.dart';
import 'layout_callback_builder.dart';
import 'dart:math';
import "dart:collection";

// ScrollView子组件管理器:
//  - 自动管理子组件的位置
//  - IScrollDataInterface：
//       对外接口。
//  - OnScrollStart:
//       滚动开始。
//  - OnScrollUpdate:
//       滚动更新。
//  - OnScrollEnd:
//       滚动结束。
//  - OnUpdate:
//       Widget重建后更新。

typedef OnScrollStart = void Function(IScrollDataInterface scrollDataInterface);
typedef OnScrollUpdate = void Function(
    IScrollDataInterface scrollDataInterface);
typedef OnScrollEnd = void Function(IScrollDataInterface scrollDataInterface);
typedef OnUpdate = void Function(IScrollDataInterface scrollDataInterface);

abstract class IScrollDataInterface {
  ///viewport视图内第一个子组件的下标
  int get firstVisibleIndex;

  ///viewport视图内最后一个子组件的下标
  int get lastVisibleIndex;

  ///viewport视图内接近中心位置的子组件的下标
  int get nearCenterVisibleIndex;

  ///viewport视图内是否存在子组件
  bool get hasVisibleChild;

  ///滚动信息
  ScrollMetrics get scrollMetrics;

  ///当滚动更新时有效，手势拖动的方向
  GestureDirection? get gestureDirection;

  ///下标为index位置上子组件的尺寸信息实体类
  ComputedSize? getComputedSize(int index);

  ///下标为index位置上子组件是否已经测量过
  bool isMeasuredSize(int index);

  ///下标为index位置上子组件是否在viewport视图内
  bool isVisibleAt(int index);

  ///下标为index位置上子组件在viewport视图内的比例
  double visibleRaTioAt(int index);

  ///viewport视图内第一个子组件在视图内的比例
  double get firstVisibleRatio;

  ///viewport视图内最后一个子组件在视图内的比例
  double get lastVisibleRatio;

  ///viewport视图内接近中心位置的子组件距离视图中心基线的比例
  double get nearCenterRatio;

  ///viewport视图内所有存在的尺寸信息实体类集合
  List<ComputedSize> get visibleComputedSizes;
}

class _ImplScrollDataInterface implements IScrollDataInterface {
  _VisibleManager? _visibleManager;

  _ImplScrollDataInterface._(this._visibleManager);

  @override
  int get firstVisibleIndex => _visibleManager!._firstVisibleIndex!;

  @override
  int get lastVisibleIndex => _visibleManager!._lastVisibleIndex!;

  @override
  int get nearCenterVisibleIndex => _visibleManager!._nearCenterVisibleIndex!;

  @override
  ScrollMetrics get scrollMetrics => _visibleManager!._scrollMetrics!;

  @override
  GestureDirection? get gestureDirection => _visibleManager!._gestureDirection;

  @override
  ComputedSize? getComputedSize(int index) =>
      _visibleManager!._getComputedSize(index);

  @override
  List<ComputedSize> get visibleComputedSizes =>
      _visibleManager!._visibleComputedSizes;

  void _dispose() {
    _visibleManager = null;
  }

  @override
  bool get hasVisibleChild => _visibleManager!._hasVisibleChild;

  @override
  bool isMeasuredSize(int index) => _visibleManager!._isMeasuredSize(index);

  @override
  bool isVisibleAt(int index) => _visibleManager!._isVisibleAt(index);

  @override
  double visibleRaTioAt(int index) => _visibleManager!._visibleRaTioAt(index);

  @override
  double get firstVisibleRatio => _visibleManager!._firstVisibleRatio;

  @override
  double get lastVisibleRatio => _visibleManager!._lastVisibleRatio;

  @override
  double get nearCenterRatio => _visibleManager!._nearCenterRatio;
}

enum GestureDirection {
  forward,
  backward,
}

class ScrollViewManager with _SizeManager, _VisibleManager {

  Widget buildScrollView(
          {required ScrollView child,
          bool keepScrollPosition = true,
          OnUpdate? onUpdate,
          OnScrollStart? onScrollStart,
          OnScrollUpdate? onScrollUpdate,
          OnScrollEnd? onScrollEnd}) =>
      super.buildScrollView(
        child: child,
        keepScrollPosition: keepScrollPosition,
        onUpdate: onUpdate,
        onScrollStart: onScrollStart,
        onScrollUpdate: onScrollUpdate,
        onScrollEnd: onScrollEnd,
      );

  Widget buildChild({required int index, required Widget child}) =>
      super.buildChild(index: index, child: child);

  @override
  void dispose() {
    super.dispose();
  }
}

mixin _VisibleManager on _SizeManager {
  Axis _axis = Axis.vertical;
  bool _reverse = false;

  //update
  GestureDirection? _gestureDirection;
  int? _firstVisibleIndex, _lastVisibleIndex; //可能为-1，都看不见
  int? _nearCenterVisibleIndex;
  double? _currentPosition;
  ScrollMetrics? _scrollMetrics;
  ScrollController? _scrollController;

  bool _updateMetricsFlag = false;
  bool _markUpdateFlag = false;
  OnUpdate? _onUpdate;

  int? _minBuildIndex, _maxBuildIndex;

  GlobalKey? _scrollViewKey; //key一旦改变了整个ListView位置都会归0

  late IScrollDataInterface? _scrollDataInterface =
      _ImplScrollDataInterface._(this);

  Widget buildScrollView(
      {required ScrollView child,
      bool keepScrollPosition = true,
      OnUpdate? onUpdate,
      OnScrollStart? onScrollStart,
      OnScrollUpdate? onScrollUpdate,
      OnScrollEnd? onScrollEnd}) {
    print("buildScrollView => ${child.runtimeType}");
    assert(child.controller != null,
        "You have to set the controller with ${child.runtimeType}.");
    _clearData();

    _scrollController = child.controller;

    if (_axis != child.scrollDirection) {
      _axis = child.scrollDirection;
    }

    if (_reverse != child.reverse) {
      _reverse = child.reverse;
    }

    if (!keepScrollPosition) {
      _scrollViewKey = null;
    }

    _onUpdate = onUpdate;
    return NotificationListener(
      onNotification: (Notification notification) {
        if (notification is ScrollStartNotification) {
          _updateScrollData(notification.metrics);
          onScrollStart?.call(_scrollDataInterface!);
        } else if (notification is ScrollUpdateNotification) {
          _updateScrollData(notification.metrics);
          onScrollUpdate?.call(_scrollDataInterface!);
        } else if (notification is ScrollEndNotification) {
          _updateScrollData(notification.metrics);
          onScrollEnd?.call(_scrollDataInterface!);
        }
        return false;
      },
      child: KeyedSubtree(key: _scrollViewKey ??= GlobalKey(), child: child),
    );
  }

  Widget buildChild({required int index, required Widget child}) {
    return LayoutCallbackBuilder(
        layoutCallback: (Size childSize) {
          print("layout => $index");
          _markUpdateAfterBuild(index);
        },
        builder: (_, _$) =>
            _DisposeSizeWidget(_createChildKey(index), child, this, index));
  }

  void _update(ScrollMetrics scrollMetrics, {bool sync = false}) {
    if (_onUpdate == null || _updateMetricsFlag) return;
    _updateMetricsFlag = true;

    final updater = _onUpdate!;

    void syncUpdate(_) {
      _updateMetricsFlag = false;
      _updateScrollData(scrollMetrics);
      updater(_scrollDataInterface!);
    }

    if (sync) {
      syncUpdate('sync');
    } else {
      WidgetsBinding.instance!.addPostFrameCallback(syncUpdate);
    }
  }

  ComputedSize _computeSize(int index) {
    assert(_scrollMetrics != null);
    assert(_childrenKeys!.containsKey(index));
    final GlobalKey key = _childrenKeys![index]!;
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox listRenderBox =
        _scrollViewKey!.currentContext!.findRenderObject() as RenderBox;

    final _size =
        _axis == Axis.horizontal ? renderBox.size.width : renderBox.size.height;
    final offset = _axis == Axis.horizontal
        ? renderBox.globalToLocal(Offset.zero, ancestor: listRenderBox).dx
        : renderBox.globalToLocal(Offset.zero, ancestor: listRenderBox).dy;
    // final position = _scrollMetrics!.pixels - offset;//reserve = false
    //print("_computeSize=>_scrollMetrics!.pixels: ${_scrollMetrics!.pixels}");
    final position = _reverse
        ? _scrollMetrics!.pixels +
            _scrollMetrics!.viewportDimension +
            offset -
            _size
        : _scrollMetrics!.pixels - offset;
    return ComputedSize._(index, _size, position);
  }

  bool _isNeedComputeSize(int position) {
    return _computeSize(position) != _getComputedSize(position);
  }

  //在每次构建完成后计算，有可能存在刚构建完成马上销毁的情况
  void _markUpdateAfterBuild(int index) {
    _minBuildIndex ??= index;
    _maxBuildIndex ??= index;

    _minBuildIndex = min(index, _minBuildIndex!);
    _maxBuildIndex = max(index, _maxBuildIndex!);
    if (_markUpdateFlag) return;

    _markUpdateFlag = true;

    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      _markUpdateFlag = false;

      assert(_minBuildIndex != null);
      assert(_maxBuildIndex != null);

      _scrollMetrics = _scrollController?.position ?? _scrollMetrics!;

      int minBuildIndex = _minBuildIndex!;
      final int maxBuildIndex = _maxBuildIndex!;

      print(
          "_markUpdateAfterBuild => minBuildIndex: $minBuildIndex, maxBuildIndex: $maxBuildIndex");

      bool isAlign = false;

      int? startSearchIndex;

      do {
        if (_isDisposed(minBuildIndex)) continue;

        startSearchIndex ??= minBuildIndex;

        if (isAlign || _isNeedComputeSize(minBuildIndex)) {
          final computedSize = _computeSize(minBuildIndex);
          _updateComputedSize(computedSize);
          isAlign = true;
        }
      } while (++minBuildIndex <= maxBuildIndex);

      if (isAlign) {
        int? maxIndex = _getMaxIndex();
        if (maxIndex != null) {
          while (minBuildIndex <= maxIndex) {
            _updateComputedSize(_computeSize(minBuildIndex));
            minBuildIndex++;
          }
        }
      }

      //确保每次都更新
      //需要重新计算位置
      _initVisibleIndex(_scrollMetrics!, startSearchIndex: startSearchIndex!);
      _update(_scrollMetrics!, sync: true);

      _minBuildIndex = null;
      _maxBuildIndex = null;
    });
  }

  _getNearCenterIndexComputer(double pixels, double viewportDimension) {
    double? bestNearPosition;
    return (int index) {
      final centerBaselinePosition = pixels + viewportDimension / 2;
      final ComputedSize computedSize = _getComputedSize(index)!;
      final nearPosition =
          (computedSize.centerPosition - centerBaselinePosition).abs();
      if (bestNearPosition == null) {
        bestNearPosition = nearPosition;
        return true;
      } else if (nearPosition < bestNearPosition!) {
        bestNearPosition = nearPosition;
        return true;
      }
      //有一个判断失败马上跳出循环
      return false;
    };
  }

  bool _hasVisibleChildren(ScrollMetrics metrics) {
    if (!_isHasData()) return false;

    final startPosition = metrics.pixels;
    final endPosition = metrics.pixels + metrics.viewportDimension;

    //先判断边界
    //取第一个
    final firstComputedSize = _sizes![_sizes!.firstKey()];
    if (firstComputedSize == null || firstComputedSize.position >= endPosition)
      return false; //这时候看不到任何视图

    final lastComputedSize = _sizes![_sizes!.lastKey()];

    if (lastComputedSize == null ||
        lastComputedSize.endPosition <= startPosition)
      return false; //这时候看不到任何视图
    return true;
  }

  int _searchEdgeVisibleIndex(ScrollMetrics metrics,
      {int startSearchIndex = -1,
      required bool firstVisible,
      required bool lastVisible}) {
    assert(firstVisible != lastVisible);

    if (!_isValidIndex(startSearchIndex) || _isDisposed(startSearchIndex)) {
      return _findEdgeVisibleIndex(metrics,
          firstVisible: firstVisible, lastVisible: lastVisible);
    }

    if (!_hasVisibleChildren(metrics)) return -1;

    final startBaselinePosition = metrics.pixels;
    final endBaselinePosition = metrics.pixels + metrics.viewportDimension;

    //没有销毁肯定不小于0
    assert(startSearchIndex >= 0);
    if (firstVisible) {
      //从下往上搜索
      final minIndex = _getMinIndex()!;
      do {
        final searchComputedSize = _getComputedSize(startSearchIndex)!;

        if (searchComputedSize.position <= startBaselinePosition &&
            searchComputedSize.endPosition > startBaselinePosition) {
          return startSearchIndex;
        }
      } while (--startSearchIndex >= minIndex);

      return _findEdgeVisibleIndex(metrics,
          firstVisible: true, lastVisible: false);
    } else {
      //从上往下搜索
      int maxIndex = _getMaxIndex()!;
      do {
        final searchComputedSize = _getComputedSize(startSearchIndex)!;

        if (searchComputedSize.position < endBaselinePosition &&
            searchComputedSize.endPosition >= endBaselinePosition)
          return startSearchIndex;
      } while (++startSearchIndex <= maxIndex);

      return _findEdgeVisibleIndex(metrics,
          firstVisible: false, lastVisible: true);
    }
  }

  int _findEdgeVisibleIndex(ScrollMetrics metrics,
      {required bool firstVisible, required bool lastVisible}) {
    assert(firstVisible != lastVisible);
    if (!_hasVisibleChildren(metrics)) return -1;

    final startBaselinePosition = metrics.pixels;
    final endBaselinePosition = metrics.pixels + metrics.viewportDimension;

    //有子视图时说明第一个和最后一个都不为空
    final firstComputedSize = _sizes![_sizes!.firstKey()!]!;
    if (firstComputedSize.position >= startBaselinePosition) {
      if (firstVisible ||
          firstComputedSize.endPosition >= endBaselinePosition) {
        return firstComputedSize.index;
      }
    }

    final lastComputedSize = _sizes![_sizes!.lastKey()!]!;
    if (lastComputedSize.endPosition <= endBaselinePosition) {
      if (lastVisible || lastComputedSize.position <= startBaselinePosition) {
        return lastComputedSize.index;
      }
    }

    final Iterable indexList = _sizes!.keys;

    if (firstVisible) {
      final baselinePosition = startBaselinePosition;
      for (int index in indexList) {
        final computedSize = _sizes![index]!;
        if (computedSize.position <= baselinePosition &&
            computedSize.endPosition > baselinePosition) return index;
      }
    } else {
      final baselinePosition = endBaselinePosition;
      int? lastKey = _sizes!.lastKey();
      do {
        final computedSize = _sizes![lastKey]!;
        if (computedSize.position < baselinePosition &&
            computedSize.endPosition >= baselinePosition) {
          return lastKey!;
        }

        lastKey = _sizes!.lastKeyBefore(lastKey!);
      } while (lastKey != null);
    }

    return -1;
  }

  int _findVisibleIndex(int oldIndex, ScrollMetrics metrics, bool isForward,
      {bool? reverse, bool Function(int index)? otherCondition}) {
    if (!_hasVisibleChildren(metrics)) return -1;

    final maxIndex = _getMaxIndex()!;
    final minIndex = _getMinIndex()!;
    final startPosition = metrics.pixels;
    final endPosition = metrics.pixels + metrics.viewportDimension;
    final centerPosition = metrics.pixels + metrics.viewportDimension / 2;

    int currentOldIndex =
        oldIndex < 0 ? (isForward ? minIndex : maxIndex) : oldIndex;

    final nextBound =
        isForward ? currentOldIndex >= maxIndex : currentOldIndex <= minIndex;
    if (nextBound) {
      assert(currentOldIndex == minIndex || currentOldIndex == maxIndex);
      return currentOldIndex;
    }

    int changeIndex(int index) => isForward ? ++index : --index;

    final double baselinePosition = reverse == null
        ? centerPosition
        : (reverse ? endPosition : startPosition);

    return _findVisibleIndexByBaseline(
        currentOldIndex, baselinePosition, changeIndex,
        reverse: reverse, otherCondition: otherCondition);
  }

  int _findVisibleIndexByBaseline(
      int index, double baselinePosition, int Function(int index) changeIndex,
      {bool? reverse, bool Function(int index)? otherCondition}) {
    assert(index >= 0);
    final maxIndex = _getMaxIndex();
    final minIndex = _getMinIndex();
    if (minIndex == null || maxIndex == null) return -1;

    int oldIndex = index;
    bool otherConditionResult;
    do {
      otherConditionResult = otherCondition?.call(index) ?? true;
      //当前下标没判断成功退出循环并取值老的下标
      if (!otherConditionResult) return oldIndex;

      final computedSize = _getComputedSize(index);
      if (reverse != null && computedSize != null) {
        final headPosition = computedSize.position;
        final tailPosition = computedSize.endPosition;
        final baseCondition = reverse
            ? headPosition < baselinePosition
            : tailPosition > baselinePosition;
        if (baseCondition) {
          final keyCondition = reverse
              ? (tailPosition >= baselinePosition || index >= maxIndex)
              : (headPosition <= baselinePosition || index <= minIndex);
          if (keyCondition) return index;
        }
      }
      oldIndex = index;
      index = changeIndex(oldIndex);
    } while (index >= minIndex && index <= maxIndex && otherConditionResult);

    return -1;
  }

  void _initVisibleIndex(ScrollMetrics metrics, {int startSearchIndex = -1}) {
    assert(metrics.hasViewportDimension);
    _firstVisibleIndex = _searchEdgeVisibleIndex(metrics,
        startSearchIndex: startSearchIndex,
        firstVisible: true,
        lastVisible: false);
    _lastVisibleIndex = _searchEdgeVisibleIndex(metrics,
        startSearchIndex: startSearchIndex,
        firstVisible: false,
        lastVisible: true);
    assert((_firstVisibleIndex! >= 0 && _lastVisibleIndex! >= 0) ||
        (_firstVisibleIndex! < 0 && _lastVisibleIndex! < 0));
    assert(_lastVisibleIndex! >= _firstVisibleIndex!);
    if (_firstVisibleIndex! >= 0) {
      final nearCenterIndexComputer = _getNearCenterIndexComputer(
          metrics.pixels, metrics.viewportDimension);
      for (int i = _firstVisibleIndex!; i <= _lastVisibleIndex!; i++) {
        final result = nearCenterIndexComputer(i);
        if (!result) break;
        _nearCenterVisibleIndex = i;
      }
    } else {
      //当第一个不可见时说明所有都不可见
      _lastVisibleIndex = -1;
      _nearCenterVisibleIndex = -1;
    }
  }

  bool _isNeedInitIndex() {
    return (_firstVisibleIndex == null ||
            !_isValidIndex(_firstVisibleIndex!)) ||
        (_nearCenterVisibleIndex == null ||
            !_isValidIndex(_nearCenterVisibleIndex!)) ||
        (_lastVisibleIndex == null || !_isValidIndex(_lastVisibleIndex!));
  }

  //viewportDimension指的是ListView的高度范围(即使边界不可见,viewportDimension也不会改变)
  void _updateScrollData(ScrollMetrics metrics) {
    assert(metrics.hasViewportDimension);
    //final extentBefore = metrics.extentBefore;
    //final extendAfter = metrics.extentAfter;
    final maxScrollExtent = metrics.maxScrollExtent;
    final pixels = metrics.pixels;
    final viewportDimension = metrics.viewportDimension;

    _scrollMetrics = metrics;
    _currentPosition ??= 0;
    final double oldPosition = _currentPosition!;
    _gestureDirection = pixels == oldPosition
        ? null
        : (pixels > oldPosition
            ? GestureDirection.forward
            : GestureDirection.backward);
    _currentPosition = pixels;

    if (_isNeedInitIndex()) {
      _initVisibleIndex(metrics);
      assert(_firstVisibleIndex != null);
      assert(_nearCenterVisibleIndex != null);
      assert(_lastVisibleIndex != null);
    }

    if (_gestureDirection != null) {
      final nearCenterIndexComputer =
          _getNearCenterIndexComputer(pixels, viewportDimension);

      final isForward = _gestureDirection == GestureDirection.forward;

      _firstVisibleIndex = _findVisibleIndex(
          _firstVisibleIndex!, metrics, isForward,
          reverse: false);

      _lastVisibleIndex = _findVisibleIndex(
          _lastVisibleIndex!, metrics, isForward,
          reverse: true);

      _nearCenterVisibleIndex = _findVisibleIndex(
          _nearCenterVisibleIndex!, metrics, isForward,
          otherCondition: nearCenterIndexComputer);
      //当正好边界为中心时,可能搜索不到,这里需要矫正中心位置
      if (_nearCenterVisibleIndex! < 0 &&
          _firstVisibleIndex! >= 0 &&
          _lastVisibleIndex! >= 0) {
        _nearCenterVisibleIndex =
            isForward ? _lastVisibleIndex! : _firstVisibleIndex!;
      }
    }
  }

  bool _isVisibleAt(int index) {
    assert(index >= 0);
    return !_isDisposed(index);
  }

  double _visibleRaTioAt(int index) {
    assert(index >= 0);
    assert(_scrollMetrics != null);

    if (index < _firstVisibleIndex! || index > _lastVisibleIndex!) return 0.0;

    if (index > _firstVisibleIndex! && index < _lastVisibleIndex!) return 1.0;

    return index == _firstVisibleIndex!
        ? _firstVisibleRatio
        : _lastVisibleRatio;
  }

  double get _firstVisibleRatio {
    assert(_scrollMetrics != null);
    if (_firstVisibleIndex! < 0) return 0.0;

    return _scrollMetrics!.pixels >= 0
        ? _getVisibleRatioAtStart(_firstVisibleIndex!)
        : _getVisibleRatioAtEnd(_firstVisibleIndex!);
  }

  double get _lastVisibleRatio {
    assert(_scrollMetrics != null);
    if (_lastVisibleIndex! < 0) return 0.0;

    return _scrollMetrics!.pixels <= _scrollMetrics!.maxScrollExtent
        ? _getVisibleRatioAtEnd(_lastVisibleIndex!)
        : _getVisibleRatioAtStart(_lastVisibleIndex!);
  }

  double get _nearCenterRatio {
    assert(_scrollMetrics != null);
    if (_nearCenterVisibleIndex! < 0 || _isDisposed(_nearCenterVisibleIndex!))
      return 0.0;
    final centerComputedSize = _getComputedSize(_nearCenterVisibleIndex!)!;
    final centerBaseline =
        _scrollMetrics!.pixels + _scrollMetrics!.viewportDimension / 2;
    if (centerBaseline <= centerComputedSize.position ||
        centerBaseline >= centerComputedSize.endPosition) return 0.0;

    return (1.0 -
        (centerBaseline - centerComputedSize.centerPosition).abs() /
            (centerComputedSize.size / 2));
  }

  List<ComputedSize> get _visibleComputedSizes {
    assert(_firstVisibleIndex != null);
    assert(_lastVisibleIndex != null);
    final List<ComputedSize> computedSizes = [];
    if (!_hasVisibleChild) return computedSizes;

    final minIndex = _getMinIndex()!;

    int firstVisibleIndex = max(_firstVisibleIndex!, minIndex);
    final maxVisibleIndex = min(_lastVisibleIndex!, _getMaxIndex()!);

    while (firstVisibleIndex <= maxVisibleIndex) {
      if (!_isDisposed(firstVisibleIndex)) continue;
      computedSizes.add(_getComputedSize(firstVisibleIndex)!);
      firstVisibleIndex++;
    }

    return computedSizes;
  }

  bool get _hasVisibleChild {
    assert(_scrollMetrics != null);
    final minIndex = _getMinIndex();
    if (minIndex == null ||
        _firstVisibleIndex! < 0 ||
        _nearCenterVisibleIndex! < 0 ||
        _lastVisibleIndex! < 0 ||
        !_hasVisibleChildren(_scrollMetrics!)) return false;
    final maxIndex = _getMaxIndex()!;
    return _firstVisibleIndex! >= minIndex && _firstVisibleIndex! <= maxIndex;
  }

  double _getVisibleRatioAtStart(int index) {
    assert(_scrollMetrics != null);
    if (!_isValidIndex(index) || _isDisposed(index)) return 0.0;

    final baselinePosition = _scrollMetrics!.pixels;
    final visibleComputedSize = _getComputedSize(index);
    final visibleSize = visibleComputedSize!.endPosition - baselinePosition;
    return (visibleSize / visibleComputedSize.size).clamp(0.0, 1.0);
  }

  double _getVisibleRatioAtEnd(int index) {
    assert(_scrollMetrics != null);
    if (!_isValidIndex(index) || _isDisposed(index)) return 0.0;

    final baselinePosition =
        _scrollMetrics!.pixels + _scrollMetrics!.viewportDimension;
    final visibleComputedSize = _getComputedSize(index);
    final visibleSize = baselinePosition - visibleComputedSize!.position;
    return (visibleSize / visibleComputedSize.size).clamp(0.0, 1.0);
  }

  void _clearData() {
    _gestureDirection = null;
    _firstVisibleIndex = null;
    _lastVisibleIndex = null;
    _nearCenterVisibleIndex = null;
    _scrollMetrics = null;
    _currentPosition = null;
    _minBuildIndex = null;
    _maxBuildIndex = null;
  }

  @override
  void dispose() {
    _clearData();
    (_scrollDataInterface! as _ImplScrollDataInterface)._dispose();
    _scrollDataInterface = null;
    _scrollViewKey = null;
    _onUpdate = null;
    _scrollController = null;
    super.dispose();
  }
}

class _DisposeSizeWidget extends StatefulWidget {
  final int index;
  final _SizeManager listSizeManager;
  final Widget child;
  _DisposeSizeWidget(
      GlobalKey key, this.child, this.listSizeManager, this.index)
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _DisposeSizeWidgetState();
}

class _DisposeSizeWidgetState extends State<_DisposeSizeWidget> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void initState() {
    super.initState();
    widget.listSizeManager._activeChild(widget.index, widget.key as GlobalKey);
  }

  @override
  void dispose() {
    widget.listSizeManager._disposeChild(widget.index, widget.key as GlobalKey);
    super.dispose();
  }
}

mixin _SizeManager {
  SplayTreeMap<int, ComputedSize>? _sizes; //按照key从小到大排序
  HashMap<int, Set<GlobalKey>>? _childKeys;

  HashMap<int, GlobalKey>? _childrenKeys; //不需要保证顺序

  int? _getMaxIndex() {
    return !_isHasData() ? null : _sizes!.lastKey();
  }

  int? _getMinIndex() {
    return !_isHasData() ? null : _sizes!.firstKey();
  }

  bool _isValidIndex(int index) {
    if (index < 0) return false;
    final minIndex = _getMinIndex();
    if (minIndex == null || index < minIndex) return false;
    final maxIndex = _getMaxIndex();
    if (maxIndex == null || index > maxIndex) return false;
    return true;
  }

  bool _isHasData() {
    return _sizes == null ? false : _sizes!.isNotEmpty;
  }

  GlobalKey _createChildKey(int index) {
    _childrenKeys ??= HashMap();
    return _childrenKeys![index] = GlobalKey();
  }

  void _updateComputedSize(ComputedSize computedSize) {
    final index = computedSize.index;
    assert(index >= 0);
    _sizes ??= SplayTreeMap();
    _sizes![index] = computedSize;
  }

  //index不受限制
  bool _isDisposed(int index, [GlobalKey? key]) {
    if (index < 0) return true;

    if (_childrenKeys == null || !_childrenKeys!.containsKey(index))
      return true;

    key ??= _childrenKeys![index];

    final keys = _childKeys![index];
    return keys == null || keys.isEmpty ? true : !keys.contains(key);
  }

  void _disposeChild(int index, GlobalKey key) {
    assert(index >= 0);
    final keys = _childKeys![index]!;
    assert(keys.isNotEmpty);
    final removed = keys.remove(key);
    assert(removed);
    if (keys.isEmpty) {
      final removedKeys = _childKeys!.remove(index);
      assert(removedKeys != null);

      //返回结果可能为空，因为只是激活了还没build就已经销毁
      _sizes!.remove(index);
      _childrenKeys!.remove(index);
    }
  }

  void _activeChild(int index, GlobalKey key) {
    assert(index >= 0);
    _childKeys ??= HashMap();
    final keys = _childKeys![index] ??= {};
    keys.add(key);
  }

  bool _isMeasuredSize(int index) {
    assert(index >= 0);
    return _isDisposed(index)
        ? false
        : ((_sizes?.containsKey(index) ?? false) && _sizes![index] != null);
  }

  ComputedSize? _getComputedSize(int index) {
    assert(index >= 0);
    return (_sizes?.containsKey(index) ?? false) ? _sizes![index] : null;
  }

  void dispose() {
    _sizes?.clear();
    _sizes = null;
    _childKeys?.clear();
    _childKeys = null;
    _childrenKeys?.clear();
    _childrenKeys = null;
  }
}

class ComputedSize {
  final int index;
  final double size;
  final double position;
  const ComputedSize._(this.index, this.size, this.position);

  @override
  int get hashCode => hashValues(index, size, position);

  double get centerPosition => position + size / 2;

  double get endPosition => position + size;

  ComputedSize copyWith({int? index, double? size, double? position}) {
    return ComputedSize._(
        index ?? this.index, size ?? this.size, position ?? this.position);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is ComputedSize &&
        other.index == index &&
        other.size == size &&
        other.position == position;
  }

  @override
  String toString() =>
      "ComputedSize(index: $index, size: $size, position: $position)";
}
