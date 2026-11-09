# Android Release Signing

Release APKs must use a permanent signing key. Do not use the Android debug
key for a release. Debug keys are developer-machine-specific and are not a
stable identity for app updates.

## Create the Key

Run this on the machine that will create release builds:

```sh
mkdir -p ~/.android
keytool -genkeypair -v \
  -keystore ~/.android/undercroft-release.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias undercroft
```

`keytool` prompts for the keystore and key passwords. Use strong, unique
passwords and save them in a password manager. Never put passwords in the
command line or commit them to the repository.

## Configure Gradle

Create the ignored file `android/key.properties` with:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=undercroft
storeFile=~/.android/undercroft-release.jks
```

Gradle expands `~` to the current user's home directory. This file and common
keystore formats are excluded by `android/.gitignore`. Keep encrypted backups
of the keystore separate from this computer. Anyone producing future releases
must use this same key; do not generate a replacement.

Android release builds and the Android option in `deploy.sh` fail with a
setup message until the signing configuration and keystore are present.
Debug builds continue to use the normal debug key.

## Existing Testers

Testers with a debug-signed APK installed cannot install the first
production-signed APK as an in-place update. They must uninstall the old app,
then install the new APK. Their estate data is stored in Supabase, but local
app preferences and cache are cleared by uninstalling.

Once the production-signed APK is installed, future releases must retain the
same application ID and signing key to install as updates.
