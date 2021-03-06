part of scrollview_manager;

//- A description of the parameters to the 'buildScrollView' function:
//  - OnScrollStart:
//       The callback of the start of the scroll.
//  - OnScrollUpdate:
//      The callback of the update of the scroll.
//  - OnScrollEnd:
//       The callback of the end of the scroll.
//  - OnUpdate:
//       The callback to the ScrollView or children update.

typedef OnScrollStart = void Function(IScrollDataInterface scrollDataInterface);
typedef OnScrollUpdate = void Function(
    IScrollDataInterface scrollDataInterface);
typedef OnScrollEnd = void Function(IScrollDataInterface scrollDataInterface);
typedef OnUpdate = void Function(IScrollDataInterface scrollDataInterface);

abstract class IScrollDataInterface {
  ///Index of the first child component in the viewport view.
  ///-1 means the location is not visible.
  int get firstVisibleIndex;

  ///Index of the last child component in the viewport view.
  ///-1 means the location is not visible.
  int get lastVisibleIndex;

  ///Index of nearing the center baseline in the viewport view.
  ///-1 means the location is not visible.
  int get nearCenterVisibleIndex;

  ///Whether there are child components in the viewport view.
  bool get hasVisibleChild;

  /// A description of a [Scrollable]'s contents, useful for modeling the state
  /// of its viewport.
  ScrollMetrics get scrollMetrics;

  ///The direction in which the gesture is dragged while scrolling.
  GestureDirection? get gestureDirection;

  ///Size information for the child at Index.
  ComputedSize? getComputedSize(int index);

  ///Determine whether the dimensions have been measured for the child at Index.
  bool isMeasuredSize(int index);

  ///Whether the child at index is in the viewport view.
  bool isVisibleAt(int index);

  /// The proportion of the child at index in the viewport view, The range is 0.0 to 1.0.
  double visibleRatioAt(int index);

  ///The proportion of the first child at index in the viewport view, The range is 0.0 to 1.0.
  double get firstVisibleRatio;

  ///The proportion of the last child at index in the viewport view, The range is 0.0 to 1.0.
  double get lastVisibleRatio;

  ///The proportion of the child distance close to center baseline, The range is 0.0 to 1.0.
  double get nearCenterRatio;

  ///All measured dimension information in the viewport view.
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
  double visibleRatioAt(int index) => _visibleManager!._visibleRatioAt(index);

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
      _buildScrollView(
        child: child,
        keepScrollPosition: keepScrollPosition,
        onUpdate: onUpdate,
        onScrollStart: onScrollStart,
        onScrollUpdate: onScrollUpdate,
        onScrollEnd: onScrollEnd,
      );

  Widget buildChild({required int index, required Widget child}) =>
      _buildChild(index: index, child: child);

  //void _jumpToIndex(int index) => _jumpToIndex(index);

  void jumpTo(double position) => _jumpTo(position);

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
  int? _firstVisibleIndex, _lastVisibleIndex;
  int? _nearCenterVisibleIndex;
  double? _currentPosition;
  ScrollMetrics? _scrollMetrics;
  ScrollController? _scrollController;

  bool _updateMetricsFlag = false;
  bool _markUpdateFlag = false;
  OnUpdate? _onUpdate;

  int? _minBuildIndex, _maxBuildIndex;

  GlobalKey? _scrollViewKey;

  late IScrollDataInterface? _scrollDataInterface =
      _ImplScrollDataInterface._(this);

  Widget _buildScrollView(
      {required ScrollView child,
      bool keepScrollPosition = true,
      OnUpdate? onUpdate,
      OnScrollStart? onScrollStart,
      OnScrollUpdate? onScrollUpdate,
      OnScrollEnd? onScrollEnd}) {
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

  Widget _buildChild({required int index, required Widget child}) {
    return LayoutCallbackBuilder(
        layoutCallback: (Size childSize) {
          print("layout => $index");
          _markUpdateAfterBuild(index);
        },
        builder: (_, _$) =>
            _DisposeSizeWidget(_createChildKey(index), child, this, index));
  }

  /*void _jumpToIndex(int index) {
    */ /*assert(_scrollController is FixedExtentScrollController, "You need to create a FixedExtentScrollController for the ScrollView");
    final FixedExtentScrollController controller = _scrollController as FixedExtentScrollController;
    controller.jumpToItem(index);*/ /*
  }*/

  void _jumpTo(double position) {
    _scrollController!.jumpTo(position);
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

      return false;
    };
  }

  bool _hasVisibleChildren(ScrollMetrics metrics) {
    if (!_isHasData()) return false;

    final startPosition = metrics.pixels;
    final endPosition = metrics.pixels + metrics.viewportDimension;

    final firstComputedSize = _sizes![_sizes!.firstKey()];
    if (firstComputedSize == null || firstComputedSize.position >= endPosition)
      return false;

    final lastComputedSize = _sizes![_sizes!.lastKey()];

    if (lastComputedSize == null ||
        lastComputedSize.endPosition <= startPosition) return false;
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

    assert(startSearchIndex >= 0);
    if (firstVisible) {
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

  void _updateScrollData(ScrollMetrics metrics) {
    assert(metrics.hasViewportDimension);
    //final extentBefore = metrics.extentBefore;
    //final extendAfter = metrics.extentAfter;
    //final maxScrollExtent = metrics.maxScrollExtent;
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
    assert(_scrollMetrics != null);
    if (_isDisposed(index) || !_hasVisibleChildren(_scrollMetrics!))
      return false;
    return index >= _firstVisibleIndex! && index <= _lastVisibleIndex!;
  }

  double _visibleRatioAt(int index) {
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
  SplayTreeMap<int, ComputedSize>? _sizes;
  HashMap<int, Set<GlobalKey>>? _childKeys;

  HashMap<int, GlobalKey>? _childrenKeys;

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
