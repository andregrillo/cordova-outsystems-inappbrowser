#!/usr/bin/env node

/**
 * This hook updates the R class import in OSIABWebViewActivity.kt
 * to match the app's package namespace after the plugin is installed.
 */

const fs = require('fs');
const path = require('path');

module.exports = function(context) {
    const platformRoot = path.join(context.opts.projectRoot, 'platforms/android');
    const ConfigParser = context.requireCordovaModule('cordova-common').ConfigParser;
    const config = new ConfigParser(path.join(context.opts.projectRoot, 'config.xml'));

    // Get the app's package name from config.xml
    const packageName = config.android_packageName() || config.packageName();

    if (!packageName) {
        console.error('Could not determine package name for R class import');
        return;
    }

    // Path to the OSIABWebViewActivity.kt file after it's been copied to the app
    const activityPath = path.join(
        platformRoot,
        'app/src/main/kotlin/com/outsystems/plugins/inappbrowser/osinappbrowserlib/views/OSIABWebViewActivity.kt'
    );

    if (!fs.existsSync(activityPath)) {
        console.warn('OSIABWebViewActivity.kt not found at expected location');
        return;
    }

    // Read the file
    let content = fs.readFileSync(activityPath, 'utf8');

    // Replace the old R import with the app's package R import
    const oldImport = /import\s+com\.outsystems\.plugins\.inappbrowser\.osinappbrowserlib\.R/g;
    const newImport = `import ${packageName}.R`;

    if (content.match(oldImport)) {
        content = content.replace(oldImport, newImport);
        fs.writeFileSync(activityPath, content, 'utf8');
        console.log(`Updated R class import to: ${newImport}`);
    } else {
        console.log('R import already updated or not found');
    }
};
