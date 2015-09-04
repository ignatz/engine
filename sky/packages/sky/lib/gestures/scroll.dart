// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

import 'package:sky/gestures/arena.dart';
import 'package:sky/gestures/recognizer.dart';
import 'package:sky/gestures/constants.dart';

enum DragState {
  ready,
  possible,
  accepted
}

typedef void GestureDragStartCallback();
typedef void GestureDragUpdateCallback(double scrollDelta);
typedef void GestureDragEndCallback();

typedef void GesturePanStartCallback();
typedef void GesturePanUpdateCallback(sky.Offset scrollDelta);
typedef void GesturePanEndCallback();

typedef void _GesturePolymorphicUpdateCallback<T>(T scrollDelta);

abstract class _DragGestureRecognizer<T extends dynamic> extends GestureRecognizer {
  _DragGestureRecognizer({ PointerRouter router, this.onStart, this.onUpdate, this.onEnd })
    : super(router: router);

  GestureDragStartCallback onStart;
  _GesturePolymorphicUpdateCallback<T> onUpdate;
  GestureDragEndCallback onEnd;

  DragState _state = DragState.ready;
  T _pendingDragDelta;

  T get _initialPendingDragDelta;
  T _getDragDelta(sky.PointerEvent event);
  bool get _hasSufficientPendingDragDeltaToAccept;

  void addPointer(sky.PointerEvent event) {
    startTrackingPointer(event.pointer);
    if (_state == DragState.ready) {
      _state = DragState.possible;
      _pendingDragDelta = _initialPendingDragDelta;
    }
  }

  void handleEvent(sky.PointerEvent event) {
    assert(_state != DragState.ready);
    if (event.type == 'pointermove') {
      T delta = _getDragDelta(event);
      if (_state == DragState.accepted) {
        if (onUpdate != null)
          onUpdate(delta);
      } else {
        _pendingDragDelta += delta;
        if (_hasSufficientPendingDragDeltaToAccept)
          resolve(GestureDisposition.accepted);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  void acceptGesture(int pointer) {
    if (_state != DragState.accepted) {
      _state = DragState.accepted;
      T delta = _pendingDragDelta;
      _pendingDragDelta = null;
      if (onStart != null)
        onStart();
      if (delta != _initialPendingDragDelta && onUpdate != null)
        onUpdate(delta);
    }
  }

  void didStopTrackingLastPointer() {
    if (_state == DragState.possible) {
      resolve(GestureDisposition.rejected);
      _state = DragState.ready;
      return;
    }
    bool wasAccepted = (_state == DragState.accepted);
    _state = DragState.ready;
    if (wasAccepted && onEnd != null)
      onEnd();
  }
}

class VerticalDragGestureRecognizer extends _DragGestureRecognizer<double> {
  VerticalDragGestureRecognizer({
    PointerRouter router,
    GestureDragStartCallback onStart,
    GestureDragUpdateCallback onUpdate,
    GestureDragEndCallback onEnd
  }) : super(router: router, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd);

  double get _initialPendingDragDelta => 0.0;
  // Notice that we negate dy because scroll offsets go in the opposite direction.
  double _getDragDelta(sky.PointerEvent event) => -event.dy;
  bool get _hasSufficientPendingDragDeltaToAccept => _pendingDragDelta.abs() > kTouchSlop;
}

class HorizontalDragGestureRecognizer extends _DragGestureRecognizer<double> {
  HorizontalDragGestureRecognizer({
    PointerRouter router,
    GestureDragStartCallback onStart,
    GestureDragUpdateCallback onUpdate,
    GestureDragEndCallback onEnd
  }) : super(router: router, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd);

  double get _initialPendingDragDelta => 0.0;
  double _getDragDelta(sky.PointerEvent event) => -event.dx;
  bool get _hasSufficientPendingDragDeltaToAccept => _pendingDragDelta.abs() > kTouchSlop;
}

class PanGestureRecognizer extends _DragGestureRecognizer<sky.Offset> {
  PanGestureRecognizer({
    PointerRouter router,
    GesturePanStartCallback onStart,
    GesturePanUpdateCallback onUpdate,
    GesturePanEndCallback onEnd
  }) : super(router: router, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd);

  sky.Offset get _initialPendingDragDelta => sky.Offset.zero;
  // Notice that we negate dy because scroll offsets go in the opposite direction.
  sky.Offset _getDragDelta(sky.PointerEvent event) => new sky.Offset(event.dx, -event.dy);
  bool get _hasSufficientPendingDragDeltaToAccept {
    return _pendingDragDelta.dx.abs() > kTouchSlop || _pendingDragDelta.dy.abs() > kTouchSlop;
  }
}
