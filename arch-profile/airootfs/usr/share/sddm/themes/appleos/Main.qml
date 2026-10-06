import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: container
    anchors.fill: parent
    color: "black"

    // Clock, top center
    Text {
        id: clock
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        font.pixelSize: 52
        function updateClock() {
            clock.text = new Date().toLocaleTimeString(Qt.locale(), "hh:mm");
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                clock.updateClock();
                if (typeof greeting !== "undefined") greeting.refresh();
            }
        }
        Component.onCompleted: { updateClock(); if (typeof greeting !== "undefined") greeting.refresh(); }
    }

    // Center: apple + login form
    Column {
        anchors.centerIn: parent
        spacing: 10

        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            source: "logo.png"
            sourceSize.width: 180
            sourceSize.height: 180
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AppleOS"
            color: "white"
            font.pixelSize: 28
        }

        Text {
            id: greeting
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#bbbbbb"
            font.pixelSize: 18
            function refresh() {
                var h = new Date().getHours();
                var part = (h >= 5 && h < 12) ? "Good morning" : ((h >= 12 && h < 18) ? "Have a good day" : "Good evening");
                var who = name.text.length > 0 ? name.text : String(userModel.lastUser);
                greeting.text = who.length > 0 ? part + ", " + who : part;
            }
        }

        Text {
            text: "Username"
            color: "#888888"
            font.pixelSize: 14
        }

        TextBox {
            id: name
            width: 280
            text: userModel.lastUser
            focus: true
            KeyNavigation.tab: password
            KeyNavigation.backtab: loginButton
        }

        Text {
            text: "Password"
            color: "#888888"
            font.pixelSize: 14
        }

        PasswordBox {
            id: password
            width: 280
            KeyNavigation.tab: session
            KeyNavigation.backtab: name
            Keys.onPressed: {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    sddm.login(name.text, password.text, session.index);
                    event.accepted = true;
                }
            }
        }

        ComboBox {
            id: session
            width: 280
            model: sessionModel
            index: sessionModel.lastIndex
            KeyNavigation.tab: loginButton
            KeyNavigation.backtab: password
        }

        Button {
            id: loginButton
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Login"
            onClicked: sddm.login(name.text, password.text, session.index)
            KeyNavigation.tab: name
            KeyNavigation.backtab: session
        }

        Text {
            id: failedLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ff5555"
            font.pixelSize: 14
            text: ""
        }
    }

    // Power buttons, bottom right
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 24
        spacing: 12

        Button {
            text: "Reboot"
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }

        Button {
            text: "Power off"
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
    }

    Connections {
        function onLoginFailed() {
            failedLabel.text = "Login failed, try again";
            password.text = "";
            password.focus = true;
        }
        target: sddm
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = true;
        else
            password.focus = true;
    }
}
