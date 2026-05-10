import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../widgets"
import "../settings"

Item {
    id: root

    property var gameModel: null

    // forwarded to TabRunnerOptions so the runner dropdown refreshes after an install without restart
    property int runnersVersion: 0

    property var config: ({})

    // set by save() on success so saveAndPlay can locate the new game
    property string newGameId: ""

    signal cancelRequested()
    signal gameCreated(string gameId)
    signal gameCreatedAndPlay(string gameId)

    // tabs live in the TopBar, Main binds topBar.tabs when currentView is add
    property var tabs: [
        { label: "Game Info", kind: "info" },
        { label: "Runner",    kind: "runner" },
        { label: "System",    kind: "system" }
    ]
    property int currentTabIndex: 0
    readonly property string currentKind:
        tabs[currentTabIndex] ? tabs[currentTabIndex].kind : "info"

    Component.onCompleted: startDraft()

    function startDraft() {
        if (!gameModel) return
        config = gameModel.begin_new_game()
    }

    function updateField(key, value) {
        if (!gameModel) return
        let strVal = String(value)
        if (gameModel.update_draft_field(key, strVal)) {
            let next = gameModel.get_draft_config()
            if (key === "launch.args") next["launch.args"] = strVal
            config = next
        }
    }

    // returns new game id or empty on validation failure, draft is presevred
    function save() {
        if (!gameModel) return ""
        let id = gameModel.commit_new_game()
        if (id && id.length > 0) {
            newGameId = id
            root.gameCreated(id)
            return id
        }
        return ""
    }

    function saveAndPlay() {
        let id = save()
        if (id && id.length > 0) {
            root.gameCreatedAndPlay(id)
        }
    }

    function cancel() {
        if (gameModel) gameModel.discard_draft()
        root.cancelRequested()
    }

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

            // all three stay active so field state survives tab switches, a fresh Loader would lose user input apparently, unless there's another way, but idk
            Loader {
                width: parent.width
                active: true
                visible: root.currentKind === "info"
                source: "../settings/TabGameInfo.qml"
                onLoaded: {
                    item.config = Qt.binding(() => root.config)
                    item.updateField = root.updateField
                    item.gameModel = root.gameModel
                }
            }

            Loader {
                width: parent.width
                active: true
                visible: root.currentKind === "runner"
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
                active: true
                visible: root.currentKind === "system"
                source: "../settings/TabSystem.qml"
                onLoaded: {
                    item.config = Qt.binding(() => root.config)
                    item.updateField = root.updateField
                    item.gameModel = root.gameModel
                }
            }
        }
    }

    // save disabled until theres a name, the other options are arguably not needed for the .toml creation
    SettingsActionBar {
        id: actionBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        canSave: (root.config["meta.name"] || "").trim().length > 0

        onCancelClicked: root.cancel()
        onSaveClicked: root.save()
        onSaveAndPlayClicked: root.saveAndPlay()
    }
}
