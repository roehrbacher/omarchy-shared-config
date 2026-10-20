// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_kinetic.qml
// KineticScroll on a plain ListView: wheel notches scroll a fixed step,
// touchpad deltas scroll 1:1 and keep going (decaying) after lift-off.
import QtQuick
import QtTest
import ".."

Item {
  width: 300
  height: 300

  ListView {
    id: list
    anchors.fill: parent
    model: 200
    flickDeceleration: 2500
    maximumFlickVelocity: 6000
    boundsBehavior: Flickable.StopAtBounds
    delegate: Rectangle { width: 300; height: 50 }
    KineticScroll { id: kinetic; flickable: list; wheelStep: 75 }
  }

  TestCase {
    name: "Kinetic"
    when: windowShown

    function init() { list.cancelFlick(); list.contentY = 0 }

    function test_wheel_notch_scrolls_one_step() {
      mouseWheel(list, 150, 150, 0, -120)
      compare(list.contentY, 75, "one notch down = wheelStep")
      compare(list.flicking, false, "no momentum for the mouse wheel")
      mouseWheel(list, 150, 150, 0, 120)
      compare(list.contentY, 0)
    }

    function test_touchpad_moves_one_to_one() {
      var t = 1000
      kinetic.lastTime = t
      kinetic.touchpadDelta(-40, t + 200)
      compare(list.contentY, 40)
    }

    function test_flick_continues_after_lift_and_decays() {
      var t = 1000
      kinetic.lastTime = t
      for (var i = 1; i <= 6; i++) kinetic.touchpadDelta(-30, t + i * 10)
      var atLift = list.contentY
      compare(atLift, 180)
      kinetic.touchpadEnd(t + 70)
      verify(list.flicking, "momentum started")
      wait(150)
      var y1 = list.contentY
      verify(y1 > atLift, "still scrolling after the fingers lifted")
      tryCompare(list, "flicking", false, 4000)
      var moved1 = y1 - atLift
      var moved2 = list.contentY - y1
      verify(moved2 < moved1 * 20, "slows down and stops")
      verify(list.contentY > atLift + 100, "glides a fair distance: " + (list.contentY - atLift))
    }

    function test_no_flick_when_fingers_stopped() {
      var t = 1000
      kinetic.lastTime = t
      kinetic.touchpadDelta(-30, t + 10)
      kinetic.touchpadEnd(t + 400)
      verify(!list.flicking)
    }
  }
}
