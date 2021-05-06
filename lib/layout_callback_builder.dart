import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef LayoutWidgetBuilder = Widget Function(
    BuildContext context, BoxConstraints constraints);
typedef LayoutAfterCallback = void Function(Size size);

abstract class ConstrainedLayoutCallbackBuilder<
    ConstraintType extends Constraints> extends RenderObjectWidget {
  /// Creates a widget that defers its building until layout.
  ///
  /// The [builder] argument must not be null, and the returned widget should not
  /// be null.
  const ConstrainedLayoutCallbackBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  _LayoutCallbackBuilderElement<ConstraintType> createElement() =>
      _LayoutCallbackBuilderElement<ConstraintType>(this);

  /// Called at layout time to construct the widget tree.
  ///
  /// The builder must not return null.
  final Widget Function(BuildContext, ConstraintType) builder;

// updateRenderObject is redundant with the logic in the LayoutBuilderElement below.
}

class _LayoutCallbackBuilderElement<ConstraintType extends Constraints>
    extends RenderObjectElement {
  _LayoutCallbackBuilderElement(
      ConstrainedLayoutCallbackBuilder<ConstraintType> widget)
      : super(widget);

  @override
  ConstrainedLayoutCallbackBuilder<ConstraintType> get widget =>
      super.widget as ConstrainedLayoutCallbackBuilder<ConstraintType>;

  @override
  RenderConstrainedLayoutCallbackBuilder<ConstraintType, RenderObject>
      get renderObject =>
          super.renderObject as RenderConstrainedLayoutCallbackBuilder<
              ConstraintType, RenderObject>;

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child!);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot); // Creates the renderObject.
    renderObject.updateCallback(_layout);
  }

  @override
  void update(ConstrainedLayoutCallbackBuilder<ConstraintType> newWidget) {
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);

    renderObject.updateCallback(_layout);
    // Force the callback to be called, even if the layout constraints are the
    // same, because the logic in the callback might have changed.
    renderObject.markNeedsBuild();
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.

    // Force the callback to be called, even if the layout constraints are the
    // same. This is because that callback may depend on the updated widget
    // configuration, or an inherited widget.
    renderObject.markNeedsBuild();
    super
        .performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void unmount() {
    renderObject.updateCallback(null);
    super.unmount();
  }

  void _layout(ConstraintType constraints) {
    owner!.buildScope(this, () {
      Widget built;
      try {
        built = widget.builder(this, constraints);
        debugWidgetBuilderValue(widget, built);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _debugReportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () sync* {
              yield DiagnosticsDebugCreator(DebugCreator(this));
            },
          ),
        );
      }
      try {
        _child = updateChild(_child, built, null);
        assert(_child != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _debugReportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () sync* {
              yield DiagnosticsDebugCreator(DebugCreator(this));
            },
          ),
        );
        _child = updateChild(null, built, slot);
      }
    });
  }

  @override
  void insertRenderObjectChild(RenderObject child, dynamic slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject =
        this.renderObject;
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(
      RenderObject child, dynamic oldSlot, dynamic newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, dynamic slot) {
    final RenderConstrainedLayoutCallbackBuilder<ConstraintType, RenderObject>
        renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}

mixin RenderConstrainedLayoutCallbackBuilder<ConstraintType extends Constraints,
    ChildType extends RenderObject> on RenderObjectWithChildMixin<ChildType> {
  LayoutCallback<ConstraintType>? _callback;

  /// Change the layout callback.
  void updateCallback(LayoutCallback<ConstraintType>? value) {
    if (value == _callback) return;
    _callback = value;
    markNeedsLayout();
  }

  bool _needsBuild = true;

  /// Marks this layout builder as needing to rebuild.
  ///
  /// The layout build rebuilds automatically when layout constraints change.
  /// However, we must also rebuild when the widget updates, e.g. after
  /// [State.setState], or [State.didChangeDependencies], even when the layout
  /// constraints remain unchanged.
  ///
  /// See also:
  ///
  ///  * [ConstrainedLayoutBuilder.builder], which is called during the rebuild.
  void markNeedsBuild() {
    // Do not call the callback directly. It must be called during the layout
    // phase, when parent constraints are available. Calling `markNeedsLayout`
    // will cause it to be called at the right time.
    _needsBuild = true;
    markNeedsLayout();
  }

  // The constraints that were passed to this class last time it was laid out.
  // These constraints are compared to the new constraints to determine whether
  // [ConstrainedLayoutBuilder.builder] needs to be called.
  Constraints? _previousConstraints;

  /// Invoke the callback supplied via [updateCallback].
  ///
  /// Typically this results in [ConstrainedLayoutBuilder.builder] being called
  /// during layout.
  void rebuildIfNecessary() {
    assert(_callback != null);
    if (_needsBuild || constraints != _previousConstraints) {
      _previousConstraints = constraints;
      _needsBuild = false;
      invokeLayoutCallback(_callback!);
    }
  }
}

class LayoutCallbackBuilder extends ConstrainedLayoutCallbackBuilder<BoxConstraints> {
  /// Creates a widget that defers its building until layout.
  ///
  /// The [builder] argument must not be null.
  const LayoutCallbackBuilder({
    Key? key,
    required this.layoutCallback,
    required LayoutWidgetBuilder builder,
  }) : super(key: key, builder: builder);

  @override
  LayoutWidgetBuilder get builder => super.builder;

  final LayoutAfterCallback layoutCallback;

  @override
  _RenderLayoutCallbackBuilder createRenderObject(BuildContext context) =>
      _RenderLayoutCallbackBuilder(layoutCallback: layoutCallback);

  @override
  void updateRenderObject(BuildContext context,
      covariant _RenderLayoutCallbackBuilder renderObject) {
    renderObject..layoutCallback = layoutCallback;
  }
}

class _RenderLayoutCallbackBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderConstrainedLayoutCallbackBuilder<BoxConstraints, RenderBox> {
  LayoutAfterCallback layoutCallback;

  _RenderLayoutCallbackBuilder({
    required this.layoutCallback,
  });

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason:
          'Calculating the dry layout would require running the layout callback '
          'speculatively, which might mutate the live render object tree.',
    ));
    return Size.zero;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    rebuildIfNecessary();
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.biggest;
    }
    layoutCallback.call(size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null) return child!.getDistanceToActualBaseline(baseline);
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError(
            'LayoutBuilder does not support returning intrinsic dimensions.\n'
            'Calculating the intrinsic dimensions would require running the layout '
            'callback speculatively, which might mutate the live render object tree.');
      }
      return true;
    }());

    return true;
  }
}

FlutterErrorDetails _debugReportException(
  DiagnosticsNode context,
  Object exception,
  StackTrace stack, {
  InformationCollector? informationCollector,
}) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'widgets library',
    context: context,
    informationCollector: informationCollector,
  );
  FlutterError.reportError(details);
  return details;
}
