import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  color: Color.popups.background
  radius: Style.space(8)
  
  property var ytdlService: null
  property color foreground: Color.popups.text
  property color activeColor: Color.accent
  property string fontFamily: Style.font.family
  
  property string selectedQuality: ytdlService ? ytdlService.selectedQuality : "1080p"
  property string selectedDownloadType: ytdlService ? ytdlService.defaultDownloadType : "video"
  property string selectedVideoFormat: ytdlService ? ytdlService.videoFormat : "mp4"
  property string selectedAudioFormat: ytdlService ? ytdlService.audioFormat : "mp3"
  property bool downloadTranscripts: ytdlService ? ytdlService.downloadTranscripts : false
  property string transcriptLanguages: ytdlService ? ytdlService.transcriptLanguages : "en"
  property bool playlistInSeparateFolder: ytdlService ? ytdlService.playlistInSeparateFolder : true
  
  signal closeRequested()
  
  Column {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(16)
    
    RowLayout {
      width: parent.width
      spacing: Style.space(8)
      
      Text {
        Layout.fillWidth: true
        text: "Download Settings"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
      
      PanelActionButton {
        iconText: "\uf00d"
        tooltipText: "Close"
        foreground: root.foreground
        hoverColor: Color.urgent
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        onClicked: root.closeRequested()
      }
    }
    
    Rectangle {
      width: parent.width
      height: 1
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      Text {
        text: "Download Type"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      
      Row {
        spacing: Style.space(8)
        
        Repeater {
          model: [
            { value: "video", label: "Video", icon: "󰕧" },
            { value: "audio", label: "Audio", icon: "󰎆" },
            { value: "both", label: "Both", icon: "󰼁" }
          ]
          
          delegate: Button {
            width: Style.space(100)
            height: Style.space(40)
            text: modelData.label
            iconText: modelData.icon
            foreground: root.foreground
            accent: root.activeColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.selectedDownloadType === modelData.value
            onClicked: {
              root.selectedDownloadType = modelData.value
              if (ytdlService) ytdlService.defaultDownloadType = modelData.value
            }
          }
        }
      }
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      Text {
        text: "Video Quality"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      
      Flow {
        width: parent.width
        spacing: Style.space(8)
        
        Repeater {
          model: ["best", "1080p", "720p", "480p"]
          
          delegate: Button {
            width: Style.space(80)
            height: Style.space(36)
            text: modelData
            foreground: root.foreground
            accent: root.activeColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.selectedQuality === modelData
            onClicked: {
              root.selectedQuality = modelData
              if (ytdlService) {
                ytdlService.selectedQuality = modelData
                ytdlService.persistQuality()
                ytdlService.setDefaultQuality(modelData)
              }
            }
          }
        }
      }
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      Text {
        text: "Video Format"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      
      Flow {
        width: parent.width
        spacing: Style.space(8)
        
        Repeater {
          model: ["mp4", "mkv", "webm", "avi"]
          
          delegate: Button {
            width: Style.space(70)
            height: Style.space(36)
            text: modelData.toUpperCase()
            foreground: root.foreground
            accent: root.activeColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.selectedVideoFormat === modelData
            onClicked: {
              root.selectedVideoFormat = modelData
              if (ytdlService) ytdlService.videoFormat = modelData
            }
          }
        }
      }
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      Text {
        text: "Audio Format"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      
      Flow {
        width: parent.width
        spacing: Style.space(8)
        
        Repeater {
          model: ["mp3", "m4a", "opus", "flac", "wav"]
          
          delegate: Button {
            width: Style.space(70)
            height: Style.space(36)
            text: modelData.toUpperCase()
            foreground: root.foreground
            accent: root.activeColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.selectedAudioFormat === modelData
            onClicked: {
              root.selectedAudioFormat = modelData
              if (ytdlService) ytdlService.audioFormat = modelData
            }
          }
        }
      }
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        
        Text {
          Layout.fillWidth: true
          text: "Download Transcripts"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        
        Button {
          implicitWidth: Style.space(48)
          implicitHeight: Style.space(28)
          text: root.downloadTranscripts ? "On" : "Off"
          foreground: root.foreground
          accent: root.activeColor
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          selected: root.downloadTranscripts
          onClicked: {
            root.downloadTranscripts = !root.downloadTranscripts
            if (ytdlService) ytdlService.downloadTranscripts = root.downloadTranscripts
          }
        }
      }
      
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        visible: root.downloadTranscripts
        
        Text {
          text: "Languages:"
          color: Qt.darker(root.foreground, 1.3)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        
        TextField {
          id: langInput
          Layout.fillWidth: true
          height: Style.space(32)
          text: root.transcriptLanguages
          placeholderText: "e.g., en,es,fr"
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          foreground: root.foreground
          accent: root.activeColor
          onAccepted: {
            root.transcriptLanguages = text
            if (ytdlService) ytdlService.transcriptLanguages = text
          }
        }
      }
    }
    
    Column {
      width: parent.width
      spacing: Style.space(12)
      
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        
        Text {
          Layout.fillWidth: true
          text: "Playlists in Separate Folders"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        
        Button {
          implicitWidth: Style.space(48)
          implicitHeight: Style.space(28)
          text: root.playlistInSeparateFolder ? "On" : "Off"
          foreground: root.foreground
          accent: root.activeColor
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          selected: root.playlistInSeparateFolder
          onClicked: {
            root.playlistInSeparateFolder = !root.playlistInSeparateFolder
            if (ytdlService) ytdlService.playlistInSeparateFolder = root.playlistInSeparateFolder
          }
        }
      }
    }
    
    Item {
      Layout.fillHeight: true
    }
  }
}
