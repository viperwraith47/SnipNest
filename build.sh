#!/bin/bash

set -euo pipefail

# Optional Developer ID signing and notarization.
#
# Export these before running the script to sign and notarize:
#   export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
#   export NOTARY_KEYCHAIN_PROFILE="your-notarytool-profile"
#
# DEVELOPMENT_TEAM is optional when the identity already contains a team ID.
# Create the notary profile once with `xcrun notarytool store-credentials`.
# Without these variables, the script still creates an unsigned, unnotarized DMG.

PROJECT="SnipNest.xcodeproj"
SCHEME="SnipNest"
CONFIGURATION="Release"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
NOTARIZED=0

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local tool="$1"
    local help="$2"
    command -v "$tool" >/dev/null 2>&1 || die "Required tool '$tool' was not found. $help"
}

# Check every tool needed for an unsigned build before changing files.
require_command xcodebuild "Install Xcode and its command line tools."
require_command xcode-select "Install Apple's command line tools."
require_command hdiutil "This tool is included with macOS."
require_command plutil "This tool is included with macOS."
require_command sed "This tool is included with macOS."
require_command grep "This tool is included with macOS."
require_command ditto "This tool is included with macOS."

# Respect DEVELOPER_DIR, otherwise find a full Xcode installation without
# changing the machine's xcode-select setting. Command Line Tools alone cannot
# build an Xcode app project even though they provide an xcodebuild shim.
select_xcode() {
    if [[ -n "${DEVELOPER_DIR:-}" ]]; then
        [[ -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]] \
            || die "DEVELOPER_DIR does not contain xcodebuild: $DEVELOPER_DIR"
        return
    fi

    local active candidate
    active="$(xcode-select -p 2>/dev/null || true)"
    if [[ -x "$active/usr/bin/xcodebuild" && -d "$active/Platforms/MacOSX.platform" ]]; then
        export DEVELOPER_DIR="$active"
        return
    fi

    for candidate in /Applications/Xcode.app/Contents/Developer /Applications/Xcode*.app/Contents/Developer; do
        if [[ -x "$candidate/usr/bin/xcodebuild" && -d "$candidate/Platforms/MacOSX.platform" ]]; then
            export DEVELOPER_DIR="$candidate"
            log "Using Xcode at $candidate"
            return
        fi
    done

    die "A full Xcode installation is required. Install Xcode or set DEVELOPER_DIR to its Contents/Developer directory."
}

select_xcode

# Validate the expected project and scheme before starting a lengthy build.
[[ -d "$PROJECT" ]] \
    || die "Expected $PROJECT in $ROOT. Run this script from the project root."
[[ -f "$PROJECT/project.pbxproj" ]] \
    || die "$PROJECT is missing project.pbxproj and is not a valid Xcode project."

if ! PROJECT_INFO="$(xcodebuild -list -project "$PROJECT" 2>&1)"; then
    die "xcodebuild could not read $PROJECT. Check the project in Xcode."
fi

if ! printf '%s\n' "$PROJECT_INFO" | grep -Eq "^[[:space:]]*${SCHEME}[[:space:]]*$"; then
    die "Scheme '$SCHEME' was not found in $PROJECT. Available schemes are listed by: xcodebuild -list -project $PROJECT"
fi

# Read product metadata from the actual Release build settings rather than
# duplicating the app name or version in this script.
if ! BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>&1)"; then
    die "Could not read $CONFIGURATION build settings for scheme '$SCHEME'."
fi

build_setting() {
    printf '%s\n' "$BUILD_SETTINGS" | sed -n "s/^[[:space:]]*$1 = //p" | sed -n '1p'
}

APP_NAME="$(build_setting PRODUCT_NAME)"
FULL_PRODUCT_NAME="$(build_setting FULL_PRODUCT_NAME)"
VERSION="$(build_setting MARKETING_VERSION)"
VERSION="${VERSION//\"/}"

[[ -n "$APP_NAME" ]] \
    || die "PRODUCT_NAME is empty in the $CONFIGURATION build settings."
[[ "$FULL_PRODUCT_NAME" == *.app ]] \
    || die "FULL_PRODUCT_NAME is missing or is not an app bundle: $FULL_PRODUCT_NAME"
[[ -n "$VERSION" ]] \
    || die "MARKETING_VERSION was not found in the $CONFIGURATION build settings."
[[ "$VERSION" != *"/"* && "$VERSION" != *$'\n'* ]] \
    || die "MARKETING_VERSION contains characters that are unsafe for a filename: $VERSION"

FINAL_DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APP_BUNDLE="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$FULL_PRODUCT_NAME"

# Notarization without signing would reject the package, so fail early.
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" && -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    die "NOTARY_KEYCHAIN_PROFILE is set, but DEVELOPER_ID_APPLICATION is missing."
fi

# Build unsigned by default. Supplying a Developer ID switches to a signed
# Release build and enables the optional notarization step below.
XCODE_SIGNING=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    require_command codesign "Install Apple's command line tools."
    XCODE_SIGNING=(
        CODE_SIGNING_ALLOWED=YES
        CODE_SIGN_STYLE=Manual
        CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
        PROVISIONING_PROFILE_SPECIFIER=
    )
    if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
        XCODE_SIGNING+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
    fi
fi

log "Cleaning previous build artifacts"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -f "$FINAL_DMG"

log "Building $APP_NAME $VERSION in $CONFIGURATION configuration"
BUILD_LOG="$BUILD_DIR/xcodebuild.log"
if ! xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    "${XCODE_SIGNING[@]}" >"$BUILD_LOG" 2>&1; then
    die "$CONFIGURATION build failed. Review the build log at $BUILD_LOG"
fi

# Verify the built app and ensure its generated Info.plist agrees with the
# version used for the DMG filename.
[[ -d "$APP_BUNDLE" ]] \
    || die "Build succeeded but the expected app bundle was not found: $APP_BUNDLE"
[[ -f "$APP_BUNDLE/Contents/Info.plist" ]] \
    || die "The built app is missing Contents/Info.plist."

if ! BUILT_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null)"; then
    die "Could not read CFBundleShortVersionString from the built app."
fi
[[ "$BUILT_VERSION" == "$VERSION" ]] \
    || die "Version mismatch: build settings say $VERSION, but the app reports $BUILT_VERSION."

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    if ! codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1; then
        die "The app bundle failed code-signature verification."
    fi
fi

log "Creating the drag-to-Applications installer"
STAGING_DIR="$BUILD_DIR/dmg"
mkdir -p "$STAGING_DIR"
ditto "$APP_BUNDLE" "$STAGING_DIR/$FULL_PRODUCT_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

HDIUTIL_LOG="$BUILD_DIR/hdiutil.log"
if ! hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov "$FINAL_DMG" >"$HDIUTIL_LOG" 2>&1; then
    die "Could not create the DMG. Review the log at $HDIUTIL_LOG"
fi

[[ -f "$FINAL_DMG" ]] || die "hdiutil finished without creating $FINAL_DMG"
if ! hdiutil verify "$FINAL_DMG" >"$BUILD_DIR/hdiutil-verify.log" 2>&1; then
    die "The DMG failed hdiutil verification. See $BUILD_DIR/hdiutil-verify.log"
fi

# Sign the DMG itself as well when a Developer ID identity is available.
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    log "Signing the DMG with Developer ID"
    if ! codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$FINAL_DMG" >/dev/null 2>&1; then
        die "DMG signing failed. Check DEVELOPER_ID_APPLICATION and the signing certificate in Keychain Access."
    fi
fi

# Optional notarization. The ticket is stapled to the DMG so Gatekeeper can
# verify it while offline.
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    require_command xcrun "Install Apple's command line tools."

    log "Submitting the DMG for notarization"
    NOTARY_LOG="$BUILD_DIR/notarytool.log"
    if ! xcrun notarytool submit "$FINAL_DMG" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait >"$NOTARY_LOG" 2>&1; then
        die "Notarization failed. Review $NOTARY_LOG and your notarytool credentials."
    fi

    log "Stapling the notarization ticket"
    if ! xcrun stapler staple "$FINAL_DMG" >"$BUILD_DIR/stapler.log" 2>&1; then
        die "Notarization succeeded, but stapling failed. See $BUILD_DIR/stapler.log"
    fi
    if ! xcrun stapler validate "$FINAL_DMG" >"$BUILD_DIR/stapler-validate.log" 2>&1; then
        die "The stapled DMG failed validation. See $BUILD_DIR/stapler-validate.log"
    fi
    NOTARIZED=1
fi

if [[ "$NOTARIZED" -eq 0 ]]; then
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        warn "The DMG is unsigned and unnotarized. Friends may see a Gatekeeper warning."
    else
        warn "The DMG is signed but not notarized. Friends may see a Gatekeeper warning."
    fi
    warn "To open the app: right-click it and choose Open, or use System Settings > Privacy & Security > Open Anyway."
fi

printf '\nFinished DMG: %s\n' "$FINAL_DMG"
