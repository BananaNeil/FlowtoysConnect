# FlowtoysConnect
Flutter-based mobile client app for the Flowtoys connect bridge

# BEFORE YOU BUILD:
update the version code (Y) in the pubspec.yml (2.X.X+Y)

# To build for the android store, run:
flutter build appbundle --release --target-platform android-arm,android-arm64,android-x64; open build/app/outputs/flutter-apk/

# To build for android devices
flutter build apk --release; open build/app/outputs/flutter-apk/








# SETUP/BUILD for ios DEVICES:

$ open ios/Runner.xcodeproj/

- Select Runner (nested in Project, not in Targets)
- Select 'Build Settings'
- Click "+"
- Click "Add User-Defined Setting"
- Add FLUTTER_ROOT as the key and add the result of the following as the value:

$ which flutter | sed 's/.\{11\}$//'
(should be something like /Users/neil/.flutter)
(`which flutter` should result in the binary, and the flutter root, should be one dir up)

- Select Runner (nested in Project, not in Targets)
- Select 'Info'
- Under configurations, open each one up and set the value to 'None'
- (make sure it says "No configurations set" on each item)
- Close Xcode

$ flutter clean
$ flutter pub get
$ rm -rf ~/Library/Developer/Xcode/DerivedData/
$ cd ios;rm -rf Pods/ Podfile Podfile.lock ; pod install; cd ..
$ flutter build ios
$ open ios/Runner.xcworkspace





( those commands as a one liner ):
flutter clean; flutter pub get; rm -rf ~/Library/Developer/Xcode/DerivedData/; cd ios;rm -rf Pods/ Podfile Podfile.lock ; pod install; cd ..; flutter build ios; open ios/Runner.xcworkspace



# Building for iOS:
# (usually these steps will work, but sometimes you need to go back and run the steps above 

```
flutter build ios; open ios/Runner.xcworkspace
```


- Select Product > (hold option) Clean Build Folder
- Select Product > Destination > Generic iOS Device
- Select Product > Archive
