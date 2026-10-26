import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot driver (tools/screenshot). Reads a job list from the JSON file
// named by OMARKY_SHOT, opens each file in a fresh window at a fixed size,
// grabs the top and further pages by scrolling, then quits.
//   { "out": dir, "jobs": [ { "file", "name", "w", "h", "pages", "opts": {} } ] }
Item {
  id: root
  property string specPath: ""
  property var spec: null
  property int jobIndex: -1
  property var win: null
  property int page: 0
  property Component windowComponent

  function nextJob() {
    if (win) { win.destroy(); win = null }
    jobIndex++
    if (!spec || jobIndex >= spec.jobs.length) { console.info("shots: done"); Qt.quit(); return }
    var job = spec.jobs[jobIndex]
    page = 0
    win = windowComponent.createObject(root, { path: job.file, implicitWidth: job.w, implicitHeight: job.h, shotOptions: job.opts || {} })
    settle.restart()
  }

  function grab() {
    // A version still being resolved: look again shortly.
    if (win.shotBusy) { settle.restart(); return }
    var job = spec.jobs[jobIndex]
    page++
    var file = spec.out + "/" + job.name + "-" + page + ".png"
    win.grabRoot.grabToImage(function(result) {
      result.saveToFile(file)
      console.info("shots: wrote " + file)
      if (page >= (job.pages || 1) || !win.shotNextPage()) nextJob()
      else settle.restart()
    })
  }

  // A stuck job must never hang tools/screenshot.
  Timer { running: true; interval: 240000; onTriggered: { console.error("shots: watchdog fired"); Qt.quit() } }

  // Long enough for fonts, images and the fade-in to finish.
  Timer { id: settle; interval: 450; onTriggered: root.grab() }

  FileView {
    path: root.specPath
    blockLoading: true
    onLoaded: { root.spec = JSON.parse(text()); root.nextJob() }
    onLoadFailed: { console.error("shots: cannot read " + root.specPath); Qt.quit() }
  }
}
