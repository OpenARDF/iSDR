project := "iSDR.xcodeproj"
scheme := "iSDR Dev"
derived_data := "/tmp/isdr-derived-data"
analyze_derived_data := "/tmp/isdr-analyze-derived-data"
device_derived_data := "/tmp/isdr-device-derived-data"
xcode_26_6 := "/Applications/Xcode-26.6.app/Contents/Developer"
ios_deploy := "/opt/homebrew/bin/ios-deploy"
device_test_app := device_derived_data + "/Build/Products/Debug-iphoneos/iSDR.app"
ios_deploy_output := "/tmp/isdr-ios-deploy.out"
ios_deploy_error := "/tmp/isdr-ios-deploy.err"
test_build_dir := "/tmp/isdr-tests"
test_binary := test_build_dir + "/dsp-core-tests"
spectrum_test_binary := test_build_dir + "/spectrum-analysis-tests"

# Show the targets, configurations, and shared schemes Xcode recognizes.
list:
    xcodebuild -list -project {{project}}

# Build the development scheme for a generic current-iOS simulator.
build:
    xcodebuild -quiet -project {{project}} -scheme "{{scheme}}" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath {{derived_data}} CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build

# Compile the production DSP core and run its host-side characterization tests under sanitizers.
test:
    mkdir -p {{test_build_dir}}
    xcrun --sdk macosx clang -std=c17 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-omit-frame-pointer -I. -IClasses -I"Other Sources/fft" Tests/DSPCoreTests.c "Other Sources/fft/rad2fft.c" -o {{test_binary}}
    UBSAN_OPTIONS=halt_on_error=1 {{test_binary}}
    xcrun --sdk macosx clang -std=c17 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-omit-frame-pointer -I. -I"Other Sources/fft" -c "Other Sources/fft/rad2fft.c" -o {{test_build_dir}}/rad2fft.o
    xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-omit-frame-pointer -I. -I"Other Sources/fft" Tests/SpectrumAnalysisTests.cpp "Other Sources/fft/SpectrumAnalysis.cpp" {{test_build_dir}}/rad2fft.o -o {{spectrum_test_binary}}
    UBSAN_OPTIONS=halt_on_error=1 {{spectrum_test_binary}}

# Run Clang's interprocedural analyzer against the complete iOS application target.
analyze:
    xcodebuild -quiet -project {{project}} -scheme "{{scheme}}" -configuration Debug -sdk iphoneos -destination "generic/platform=iOS" -derivedDataPath {{analyze_derived_data}} CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES analyze

# Rebuild simulator and device products; fail if an unwaived warning is emitted.
check: test
    xcodebuild -quiet -project {{project}} -scheme "{{scheme}}" -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath {{derived_data}} CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES clean build
    xcodebuild -quiet -project {{project}} -scheme "{{scheme}}" -configuration Debug -sdk iphoneos -destination "generic/platform=iOS" -derivedDataPath {{device_derived_data}} CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES clean build

# Verify that the current tree contains only documented source-provenance categories.
provenance-check:
    ./Scripts/check-provenance.sh

# Run every local gate required before exporting a public source snapshot.
public-release-check: provenance-check check analyze
    gitleaks dir --redact --no-banner .

# Export a validated commit without this private recovery repository's Git history.
public-snapshot destination:
    ./Scripts/export-public-snapshot.sh "{{destination}}"

# Produce a signed build that remains compatible with the iOS 15 test iPad.
device-build-ios15:
    DEVELOPER_DIR={{xcode_26_6}} xcodebuild -quiet -project {{project}} -scheme "{{scheme}}" -configuration Debug -sdk iphoneos -destination "generic/platform=iOS" -derivedDataPath {{device_derived_data}} GCC_TREAT_WARNINGS_AS_ERRORS=YES -allowProvisioningUpdates clean build

# Install and launch the signed build over USB without printing the device identifier.
device-install-ios15: device-build-ios15
    # ios-deploy 1.12.2 can return 1 after LLDB safequit even when launch succeeded.
    -DEVELOPER_DIR={{xcode_26_6}} {{ios_deploy}} --no-wifi --bundle {{device_test_app}} --justlaunch --timeout 15 > {{ios_deploy_output}} 2> {{ios_deploy_error}}
    @rg -q '^\[100%\] Installed package ' {{ios_deploy_output}}
    @rg -q '^success$' {{ios_deploy_output}}
    @echo 'Installed and launched iSDR Dev on the attached iOS 15 device.'
