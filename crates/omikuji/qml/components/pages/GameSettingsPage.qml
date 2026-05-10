import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../widgets"
import "../settings"

Item {
    id: root

    property var gameModel: null
    property int gameIndex: -1

    // TabRunnerOptions re-queries list_runners without restart when this bumps
    property int runnersVersion: 0

    // stored separately becuase index can shift during refresh
    property string gameId: ""

    property var gameData: null
    property var config: ({})

    signal cancelRequested()
    signal saveRequested(int gameIndex)
    signal saveAndPlayRequested(int gameIndex)
    signal refetchMediaRequested(string gameId)

    // tabs live in the TopBar so Main can surface them in the centered pill
    property var tabs: {
        let base = [
            { label: "Game Info", kind: "info" },
            { label: "Runner",    kind: "runner" },
            { label: "System",    kind: "system" }
        ]
        if (root.config["source.kind"] === "epic") {
            base.push({ label: "Epic", kind: "epic", icon: "shield_moon" })
        }
        return base
    }
    property int currentTabIndex: 0
    readonly property string currentKind:
        tabs[currentTabIndex] ? tabs[currentTabIndex].kind : "info"

    onTabsChanged: if (currentTabIndex >= tabs.length) currentTabIndex = 0

    onGameIndexChanged: loadGame()
    Component.onCompleted: loadGame()
    Component.onDestruction: {
        if (gameModel) gameModel.discard_draft()
    }

    function loadGame() {
        if (!gameModel || gameIndex < 0) {
            gameData = null
            config = {}
            gameId = ""
            return
        }
        let data = gameModel.get_game(gameIndex)
        gameData = data
        gameId = data ? data["gameId"] : ""
        config = gameModel.begin_edit_game(gameIndex)
    }

    function save() {
        if (gameModel && gameId !== "") {
            gameModel.commit_edit_game(gameId)
        }
        root.saveRequested(gameIndex)
    }

    function saveAndPlay() {
        save()
        root.saveAndPlayRequested(gameIndex)
    }

    function cancel() {
        if (gameModel) gameModel.discard_draft()
        root.cancelRequested()
    }

    function updateField(key, value) {
        if (gameModel && gameId !== "") {
            let strVal = String(value)
            if (gameModel.update_draft_field(key, strVal)) {
                let next = gameModel.get_draft_config()
                if (key === "launch.args") next["launch.args"] = strVal
                config = next
            }
        }
    }

    // lookup by id because index may shift after a refresh
    function findIndex() {
        if (!gameModel || gameId === "") return -1
        for (let i = 0; i < gameModel.count; i++) {
            let g = gameModel.get_game(i)
            if (g && g["gameId"] === gameId) return i
        }
        return -1
    }

    function refreshConfig() {
        let idx = findIndex()
        if (idx >= 0) config = gameModel.begin_edit_game(idx)
    }

    Item {
        id: contentHost
        property bool isDropdownHost: true
        anchors.fill: parent

        Flickable {
            id: contentFlick
            anchors.fill: parent
            contentHeight: contentCol.height + 100
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.right: parent.right
                anchors.rightMargin: 48
                spacing: 0

                Loader {
                    width: parent.width
                    active: root.currentKind === "info"
                    visible: active
                    source: "../settings/TabGameInfo.qml"
                    onLoaded: {
                        item.config = Qt.binding(() => root.config)
                        item.updateField = root.updateField
                        item.gameModel = root.gameModel
                        item.refetchMediaRequested.connect(() => root.refetchMediaRequested(root.gameId))
                    }
                }

                Loader {
                    width: parent.width
                    active: root.currentKind === "runner"
                    visible: active
                    source: "../settings/TabRunnerOptions.qml"
                    onLoaded: {
                        item.config = Qt.binding(() => root.config)
                        item.updateField = root.updateField
                        item.gameModel = root.gameModel
                        item.runnersVersion = Qt.binding(() => root.runnersVersion)
                    }
                }

                Loader {
                    width: parent.width
                    active: root.currentKind === "system"
                    visible: active
                    source: "../settings/TabSystem.qml"
                    onLoaded: {
                        item.config = Qt.binding(() => root.config)
                        item.updateField = root.updateField
                        item.gameModel = root.gameModel
                    }
                }

                Loader {
                    width: parent.width
                    active: root.currentKind === "epic"
                    visible: active
                    source: "../settings/TabEpic.qml"
                    onLoaded: {
                        item.config = Qt.binding(() => root.config)
                        item.updateField = root.updateField
                        item.refreshConfig = root.refreshConfig
                        item.gameModel = root.gameModel
                        item.gameId = Qt.binding(() => root.gameId)
                    }
                }
            }
        }
    }

    // z 100 so it covers dropdown popups (z 50) whose trigger sits near the bottom of the flickable
    SettingsActionBar {
        id: actionBar
        z: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        onCancelClicked: root.cancel()
        onSaveClicked: root.save()
        onSaveAndPlayClicked: root.saveAndPlay()
    }

}
