const fs = require('fs');
const path = require('path');

module.exports = function(context) {
    const plist = require('plist');
    const { ConfigParser } = require('cordova-common');

    var scheme = 'ekey';
    const args = process.argv;
    for (const arg of args) {
        if (arg.includes('AllowedExternalSchemes')) {
            var stringArray = arg.split("=");
            scheme = stringArray.slice(-1).pop();
        }
    }

    const projectRoot = context.opts.projectRoot;
    const configParser = new ConfigParser(path.join(projectRoot, 'config.xml'));
    const appName = configParser.name();
    const plistPath = path.join(projectRoot, 'platforms', 'ios', appName, appName + '-Info.plist');

    if (!fs.existsSync(plistPath)) {
        console.log('Info.plist not found at: ' + plistPath);
        return;
    }

    const plistContent = fs.readFileSync(plistPath, 'utf8');
    const plistObj = plist.parse(plistContent);

    if (!plistObj.LSApplicationQueriesSchemes) {
        plistObj.LSApplicationQueriesSchemes = [];
    }

    const schemes = scheme.split(',').map(s => s.trim());
    schemes.forEach(function(s) {
        if (plistObj.LSApplicationQueriesSchemes.indexOf(s) === -1) {
            plistObj.LSApplicationQueriesSchemes.push(s);
        }
    });

    fs.writeFileSync(plistPath, plist.build(plistObj));
    console.log('Added LSApplicationQueriesSchemes: ' + schemes.join(', '));
};
