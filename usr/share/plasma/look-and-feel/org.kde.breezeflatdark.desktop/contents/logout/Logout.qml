/***************************************************************************
 *   Copyright (C) 2014 by Aleix Pol Gonzalez <aleixpol@blue-systems.com>  *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.2
import QtQuick.Layouts 1.2
import QtQuick.Controls 1.1 as Controls

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.kcoreaddons 1.0 as KCoreAddons

import "../components"
import "timer.js" as AutoTriggerTimer

import org.kde.plasma.private.sessions 2.0

PlasmaCore.ColorScope {
    id: root
    colorGroup: PlasmaCore.Theme.ComplementaryColorGroup
    height: screenGeometry.height
    width: screenGeometry.width

    signal logoutRequested()
    signal haltRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal cancelRequested()
    signal lockScreenRequested()

    property alias backgroundColor: backgroundRect.color

    function sleepRequested() {
        root.suspendRequested(2);
    }
 
    property real timeout: 30
    property real remainingTime: root.timeout
    property var currentAction: {
        switch (sdtype) {
            case ShutdownType.ShutdownTypeReboot:
                return root.rebootRequested;
            case ShutdownType.ShutdownTypeHalt:
                return root.haltRequested;
            default:
                return root.logoutRequested;
        }
    }

    KCoreAddons.KUser {
        id: kuser
    }

    // For showing a "other users are logged in" hint
    SessionsModel {
        id: sessionsModel
        includeUnusedSessions: false
    }

    Controls.Action {
        onTriggered: root.cancelRequested()
        shortcut: "Escape"
    }

    onRemainingTimeChanged: {
        if (remainingTime <= 0) {
            root.currentAction();
        }
    }

    Timer {
        id: countDownTimer
        running: true
        repeat: true
        interval: 1000
        onTriggered: remainingTime--
        Component.onCompleted: {
            AutoTriggerTimer.addCancelAutoTriggerCallback(function() {
                countDownTimer.running = false;
            });
        }
    }

    function isLightColor(color) {
        return Math.max(color.r, color.g, color.b) > 0.5
    }

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        //use "black" because this is intended to look like a general darkening of the scene. a dark gray as normal background would just look too "washed out"
        color: root.isLightColor(PlasmaCore.ColorScope.backgroundColor) ? PlasmaCore.ColorScope.backgroundColor : "black"
        opacity: 0.5
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }
    UserDelegate {
        width: units.iconSizes.enormous
        height: width
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.verticalCenter
        }
        constrainText: false
        avatarPath: kuser.faceIconUrl
        iconSource: "user-identity"
        isCurrent: true
        name: kuser.fullName
    }
    ColumnLayout {
        anchors {
            top: parent.verticalCenter
            topMargin: units.gridUnit * 2
            horizontalCenter: parent.horizontalCenter
        }
        spacing: units.largeSpacing

        height: Math.max(implicitHeight, units.gridUnit * 10)
        width: Math.max(implicitWidth, units.gridUnit * 16)

        PlasmaComponents.Label {
            Layout.maximumWidth: units.gridUnit * 16
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.italic: true
            text: i18ndp("plasma_lookandfeel_org.kde.lookandfeel",
                         "One other user is currently logged in. If the computer is shut down or rebooted, that user may lose work.",
                         "%1 other users are currently logged in. If the computer is shut down or rebooted, those users may lose work.",
                         sessionsModel.count)
            visible: sessionsModel.count > 1
        }

        RowLayout {
            spacing: units.largeSpacing * 2
            Layout.alignment: Qt.AlignHCenter
            LogoutButton {
                id: shutdownButton
                iconSource: "system-shutdown"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Shutdown")
                action: root.haltRequested
                KeyNavigation.left: logoutButton
                KeyNavigation.right: suspendButton
                focus: sdtype == ShutdownType.ShutdownTypeHalt
                visible: maysd
            }
            LogoutButton {
                id: suspendButton
                iconSource: "system-suspend"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Suspend")
                action: root.sleepRequested
                KeyNavigation.left: shutdownButton
                KeyNavigation.right: rebootButton
                visible: spdMethods.SuspendState
            }
            LogoutButton {
                id: rebootButton
                iconSource: "system-reboot"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Reboot")
                action: root.rebootRequested
                KeyNavigation.left: suspendButton
                KeyNavigation.right: logoutButton
                focus: sdtype == ShutdownType.ShutdownTypeReboot
                visible: maysd
            }
            LogoutButton {
                id: logoutButton
                iconSource: "system-log-out"
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Logout")
                action: root.logoutRequested
                KeyNavigation.left: rebootButton
                KeyNavigation.right: shutdownButton
                focus: sdtype == ShutdownType.ShutdownTypeNone
                visible: canLogout
            }
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            //opacity, as visible would re-layout
            opacity: countDownTimer.running ? 1 : 0
            Behavior on opacity {
                OpacityAnimator {
                    duration: units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
            text: {
                switch (sdtype) {
                    case ShutdownType.ShutdownTypeReboot:
                        return i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Reboot in 1 second", "Reboot in %1 seconds", root.remainingTime);
                    case ShutdownType.ShutdownTypeHalt:
                        return i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Shutting down in 1 second", "Shutting down in %1 seconds", root.remainingTime);
                    default:
                        return i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Logging out in 1 second", "Logging out in %1 seconds", root.remainingTime);
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            PlasmaComponents.Button {
                enabled: root.currentAction != null
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "OK")
                onClicked: root.currentAction()
            }
            PlasmaComponents.Button {
                text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Cancel")
                onClicked: root.cancelRequested()
            }
        }
    }
}
