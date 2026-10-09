#!/usr/bin/env bash

# Copyright (c) 2026 OpenARDF. Licensed under the MIT License.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

failed=0

report_error() {
	printf 'provenance error: %s\n' "$1" >&2
	failed=1
}

removed_paths=(
	"Other Sources/hardware/DeviceHardware.h"
	"Other Sources/hardware/DeviceHardware.m"
	"Other Sources/hardware/README.md"
	"Wifi/SimplePing 2.h"
	"Wifi/SimplePing 2.m"
	"Wifi/SimplePing.h"
	"Wifi/SimplePing.m"
	"Wifi/SimplePingHelper.h"
	"Wifi/SimplePingHelper.m"
)

for path in "${removed_paths[@]}"; do
	if [[ -e "$path" ]]; then
		report_error "removed provenance-risk file is present: $path"
	fi
done

if rg -n -e '__MyCompanyName__' -e 'SimplePingHelper' -e 'DeviceHardware' -e 'DH_MACHINE_' Classes AudioViews FileSharing "Other Sources" Wifi iSDR.xcodeproj --glob '*.{h,m,mm,c,cpp,pbxproj}' >/dev/null; then
	report_error "a removed provenance-risk identifier remains in source or project files"
fi

apple_derived_files=(
	"AudioViews/AULevelMeter.h"
	"AudioViews/AULevelMeter.mm"
	"AudioViews/GLLevelMeter.h"
	"AudioViews/GLLevelMeter.m"
	"AudioViews/LevelMeter.h"
	"AudioViews/LevelMeter.m"
	"AudioViews/MeterTable.cpp"
	"AudioViews/MeterTable.h"
	"Classes/EAGLView.h"
	"Classes/EAGLView.mm"
	"Classes/EAGLViewController.h"
	"Classes/EAGLviewController.mm"
	"Classes/FFTBufferManager.cpp"
	"Classes/FFTBufferManager.h"
	"Classes/MultichannelMixerController.h"
	"Classes/MultichannelMixerController.mm"
	"Classes/iSDRAppDelegate.h"
	"Classes/iSDRAppDelegate.mm"
	"Other Sources/iPublicUtility/CADebugMacros.cpp"
	"Other Sources/iPublicUtility/CAMath.h"
	"Other Sources/iPublicUtility/CAXException.cpp"
	"Other Sources/iPublicUtility/CAXException.h"
	"Other Sources/iSDR_helper.cpp"
	"Other Sources/iSDR_helper.h"
	"Other Sources/main.m"
)

for path in "${apple_derived_files[@]}"; do
	if [[ ! -f "$path" ]]; then
		report_error "expected Apple-derived source is missing: $path"
	elif ! rg -Fq 'LICENSES/Apple-Sample-Code.txt' "$path"; then
		report_error "Apple-derived source lacks its license reference: $path"
	fi
done

if [[ ! -f LICENSES/Apple-Sample-Code.txt ]]; then
	report_error "Apple sample-code license text is missing"
fi

apple_derived_resources=(
	"Resources/Base.lproj/MainWindow.xib"
	"Resources-iPad/Base.lproj/MainWindow-iPad.xib"
	"Resources-iPad/Resources/en.lproj/MainWindow-iPad.xib"
)

for path in "${apple_derived_resources[@]}"; do
	if [[ ! -f "$path" ]]; then
		report_error "expected Apple-derived resource is missing: $path"
	elif ! rg -Fq "\`$path\`" THIRD_PARTY_NOTICES.md; then
		report_error "Apple-derived resource is absent from THIRD_PARTY_NOTICES.md: $path"
	fi
done

while IFS= read -r path; do
	if ! head -n 100 "$path" | rg -qi 'OpenARDF|Apple (Inc|Computer)|public[ -]domain|Permission is hereby granted'; then
		report_error "source lacks a recognized provenance or license marker: $path"
	fi
done < <(find AudioViews Classes FileSharing "Other Sources" Tests Wifi -type f \( -name '*.h' -o -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cpp' \) -print | sort)

if ((failed)); then
	exit 1
fi

printf 'Provenance checks passed for the current working tree.\n'
