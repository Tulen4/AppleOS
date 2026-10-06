import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 15000
        running: true
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#101014"
            Image {
                source: "slide-1.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#101014"
            Image {
                source: "slide-2.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#101014"
            Image {
                source: "slide-3.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }
}
