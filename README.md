Check out my <a href="http://lausbert.com">blog post</a>!

# Snaptake

There are already some tries (<a href="https://github.com/fastlane/fastlane/pull/10121">here</a> and <a href="https://github.com/fastlane/fastlane/pull/11744">here</a>) to automate creating videos with fastlane snapshot. Anyway Felix definitely does not want to have an http server in his code base :)
<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/image1.png" width="750">
</p>

The following step by step guide shows an alternative way of solution. The outline corresponds to the commit history.
<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/image2.png" width="750">
</p>

## Prerequisites

- <a href="https://docs.fastlane.tools/getting-started/ios/setup">Fastlane</a> for recording videos
- <a href="http://www.renevolution.com/ffmpeg/2013/03/16/how-to-install-ffmpeg-on-mac-os-x.html">FFmpeg</a> for editing videos

## Creating project

Just create a single view application in XCode without any tests.
<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/image3.png" width="500">
</p>

## Setting up fastlane snapshot

```cd``` to your project folder and run ```fastlane init```. When fastlane is asking what you would like to use it for press "1".
<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/image4.png" width="500">
</p>

Do exactly what fastlane is telling you afterwards. After finishing the instructions open the newly created Snapfile in your projects fastlane folder. Uncomment at least one device and one language. Make sure ``` snapshot("0Launch") ``` is called in one of your UITests. Run ``` fastlane snapshot ``` in your project folder to verify everything is working fine.

## Setting up storyboard

To test the later added video recording feature, we need something to record. Therefore just add a button to your first ViewController and add a second ViewController with a distinguishable background. Push the second ViewController, when the button is clicked. Also set the buttons accessibility identifier to ```"button"```.
<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/image5.png" width="500">
</p>

## Setting up UITests

Now that your storyboard is set up, let's add video related code to the SnapshotHelper file. To keep the original snapshot logic, add the following two functions to the SnapshotHelper file scope.

```swift
func snaptake(_ name: String, waitForLoadingIndicator: Bool, plot: ()->()) {
    if waitForLoadingIndicator {
        Snapshot.snaptake(name, plot: plot)
    } else {
        Snapshot.snaptake(name, timeWaitingForIdle: 0, plot: plot)
    }
}
```

```swift
/// - Parameters:
///   - name: The name of the snaptake
///   - timeout: Amount of seconds to wait until the network loading indicator disappears. Pass `0` if you don't want to wait.
///   - plot: Plot which should be recorded.
func snaptake(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20, plot: ()->()) {
    Snapshot.snaptake(name, timeWaitingForIdle: timeout, plot: plot)
}
```
These two functions are pretty similar to the already existing snapshot functions. The only difference lies in the additional argument ```plot: ()->()```, which is a closure with no parameters and return values. ```plot``` contains all the interface interactions you want to record. You will see how to use it later.

Within your Snapshot class add the actual recording logic. ```snaptake``` takes ```plot``` as an argument and successively calls ```snaptakeStart()```, ```snaptakeSetTrimmingFlag()```, ```plot()``` and ```snaptakeStop()```.

```swift
open class func snaptake(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20, plot: ()->()) {
        
    guard let recordingFlagPath = snaptakeStart(name, timeWaitingForIdle: timeout) else { return }

    snaptakeSetTrimmingFlag()

    plot()

    snaptakeStop(recordingFlagPath)
}
```

Within ```snaptakeStart``` a recordingFlag is saved to your hard drive. This recordingFlag contains the path of the later recorded video. The saving of this recordingFlag is watched outside of XCode to start the actual recording process. You will see how this works later.

```swift
class func snaptakeStart(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) -> URL? {
    if timeout > 0 {
        waitForLoadingIndicatorToDisappear(within: timeout)
    }

    print("snaptake: \(name)")

    sleep(1) // Waiting for the animation to be finished (kind of)

    #if os(OSX)
    XCUIApplication().typeKey(XCUIKeyboardKeySecondaryFn, modifierFlags: [])
    #else
    guard let simulator = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"], let screenshotsDir = screenshotsDirectory, let cacheDirectory else { return nil }

    let simulatorNamePath = cacheDirectory.appendingPathComponent("simulator-name.txt")

    let simulatorTrimmed = simulator.replacingOccurrences(of: "Clone 1 of ", with: "")
    let path = "./videos/\(locale)/\(simulatorTrimmed)-\(name).mp4"
    let recordingFlagPath = screenshotsDir.appendingPathComponent("recordingFlag.txt")

    if !FileManager.default.fileExists(atPath: screenshotsDir.path) {
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
    }

    do {
        try simulator.trimmingCharacters(in: .newlines).write(to: simulatorNamePath, atomically: false, encoding: .utf8)
        try path.trimmingCharacters(in: .newlines).write(to: recordingFlagPath, atomically: false, encoding: String.Encoding.utf8)
    } catch let error {
        print("Problem setting recording flag: \(recordingFlagPath)")
        print(error)
    }
    #endif
    return recordingFlagPath
}
```

There is a pretty annoying bug, when recording videos via console: The first few frames appear black until somethings happens within your application. That's why we are going to rotate the device and save related duration in ```snaptakeSetTrimmingFlag```. Later we will trim the recorded video accordingly.

```swift
class func snaptakeSetTrimmingFlag() {

    let start = Date()
    sleep(2)
    XCUIDevice.shared.orientation = .landscapeLeft
    sleep(2)
    XCUIDevice.shared.orientation = .portrait
    let trimmingTime = -start.timeIntervalSinceNow - 2

    let hours = Int(trimmingTime)/3600
    let minutes = (Int(trimmingTime)/60)%60
    let seconds = Int(trimmingTime)%60
    let milliseconds = Int((trimmingTime - Double(Int(trimmingTime))) * 1000)
    let trimmingTimeString = String(format:"%02i:%02i:%02i.%03i", hours, minutes, seconds, milliseconds)

    #if os(OSX)
    XCUIApplication().typeKey(XCUIKeyboardKeySecondaryFn, modifierFlags: [])
    #else
    guard let screenshotsDir = screenshotsDirectory else { return }

    let trimmingFlagPath = screenshotsDir.appendingPathComponent("trimmingFlag.txt")

    do {
        try trimmingTimeString.write(to: trimmingFlagPath, atomically: false, encoding: String.Encoding.utf8)
    } catch let error {
        print("Problem setting recording flag: \(trimmingFlagPath)")
        print(error)
    }

    #endif
}
```

After we called ```plot``` in ```snaptake``` we finally are going to stop recording in ```snaptakeStop```. We are doing so by removing the ```recordingFlag``` we added earlier in ```snaptakeStart```.

```swift
class func snaptakeStop(_ recordingFlagPath: URL) {
    guard let screenshotsDir = cacheDirectory else { return }

    let simulatorNamePath = screenshotsDir.appendingPathComponent("simulator-name.txt")

    let fileManager = FileManager.default

    do {
        try fileManager.removeItem(at: recordingFlagPath)
        try fileManager.removeItem(at: simulatorNamePath)
    } catch let error {
        print("Problem removing recording flag: \(recordingFlagPath)")
        print(error)
    }
}
```

Finally add the following test function within SnaptakeUITests file. The function contains our plot where our button is simply tapped.

```swift
func testExample() {
    snaptake("testExample") {
        XCUIApplication().buttons["button"].tap()
    }
}
```

## Setting up fastfile, gemfile and snapfile

After your UITests are fully set up we need to add related logic outside of XCode. Within your Gemfile in your fastlane folder add ```gem "listen"```. Within your Snapfile remove ```output_directory("./screenshots")```. Now we are ready to create a videos lane in your Fastfile. The videos lane is more or less self-explaining. The most relevant part is the ```recordingListener```. Within its handlers the video reording process is started and stopped, when the recordingFlag is added or removed. When recording is stopped, the trimming time for the resulting video is read from our trimmingFlag and stored in ```trimming_time_dictionary```. ```sh("cd .. && fastlane snapshot --concurrent_simulators false && cd fastlane")``` builds Snaptake and runs SnaptakeUITests, so our ```recordingListener``` could actually be triggered. After recording any videos, they are trimmed and reencoded.

```ruby
desc "Generate new localized videos"
lane :videos do |options|

  ### RECORDING VIDEOS

  # Delete all existing videos
  mp4_file_paths = Find.find('screenshots').select { |p| /.*\.mp4$/ =~ p}
  for mp4_file_path in mp4_file_paths
    File.delete(mp4_file_path)
  end

  simulatorNamePath = '~/Library/Caches/tools.fastlane'
  cacheDirectory = '~/Library/Caches/tools.fastlane/screenshots'

  # Ensure that caching folder for screenshots and recording flags exists
  Dir.mkdir(File.expand_path(cacheDirectory)) unless Dir.exist?(File.expand_path(cacheDirectory))

  # Setup listeners for starting and ending recording
  fastlane_require 'listen'
  path = nil
  process = nil
  name = nil
  trimming_time_dictionary = {}
  recordingListener = Listen.to(File.expand_path(cacheDirectory), only: /\.txt$/) do |modified, added, removed|
    if (!added.empty?) && File.basename(added.first) == 'recordingFlag.txt'
      recording_flag_path = added.first
      expanded = File.expand_path("simulator-name.txt", simulatorNamePath)
      name = File.read(expanded)
      path = File.read(recording_flag_path)
      # Start recording of current simulator to path determined in recordingFlag.txt
      expandedPath = File.expand_path(path)
      process = IO.popen("xcrun simctl --set testing io '#{name}' recordVideo '#{expandedPath}' --force")

      puts "Starting recording for #{name} #{process.pid} to #{expandedPath}"
    end
    if (!removed.empty?) && File.basename(removed.first) == 'recordingFlag.txt'
      pid = process.pid
      # Stop recording by killing process with id pid
      Process.kill("INT", pid)
      trimming_flag_path = File.expand_path(cacheDirectory + '/trimmingFlag.txt')
      trimming_time = File.read(trimming_flag_path)
      # Storing trimming time determined in trimmingFlag.txt for recorded video (necessary due to initial black simulator screen after starting recording)
      trimming_time_dictionary[path] = trimming_time

      puts "Finished recording for #{name} #{pid}"
    end
  end

  # Build SnaptakeUITests and Snaptake and run UITests
  recordingListener.start
  sh("cd .. && fastlane snapshot --concurrent_simulators false && cd fastlane")
  recordingListener.stop

  ### EDIT VIDEOS

  sleep(3)

  # Trim videos and reencode
  mp4_file_paths = Find.find('screenshots').select { |p| /.*\.mp4$/ =~ p}
  for mp4_file_path in mp4_file_paths

    trimmed_path = mp4_file_path.chomp('.mp4') + '-trimmed.mp4'
    trimming_time = trimming_time_dictionary[mp4_file_path]
    sh("ffmpeg -ss '#{trimming_time}' -i '#{mp4_file_path}' -c:v copy -r 30 '#{trimmed_path}'") # Trimming the Beginning of the Videos
    File.delete(mp4_file_path)

    final_path = trimmed_path.chomp('-trimmed.mp4') + '-final.mp4'
    sh("ffmpeg  -i '#{trimmed_path}' -ar 44100 -ab 256k -r 30 -crf 22 -profile:v main -pix_fmt yuv420p -y -max_muxing_queue_size 1000 '#{final_path}'")
    File.delete(trimmed_path)
  end
end
```

## Running videos lane

By calling ```fastlane videos``` we are creating our test video:

<p align="center">
<img src="https://github.com/Lausbert/Snaptake/blob/master/images/gif.gif" width="300">
</p>

## Call to action

You want to know what is possible with this procedure?

**Checkout <a href="https://itunes.apple.com/de/app/bonprix/id1090412741?mt=8">Bonprix</a> with your iPhone in the (e.g. German) Appstore!**

You want to solve similarly exciting technical questions?

**Join us at <a href="http://www.apploft.de/karriere/">apploft</a>!**
