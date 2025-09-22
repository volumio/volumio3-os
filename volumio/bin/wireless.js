#!/usr/bin/env node

//Volumio Network Manager - Copyright Michelangelo Guarise - Volumio.org

// Time needed to settle some commands sent to the system like ifconfig
var debug = false;

var settleTime = 3000;
var wiredCheckInterval = 5000;
var fs = require('fs-extra')
var thus = require('child_process');
var wlan = "wlan0";
var eth = "eth0";
// var dhcpd = "dhcpd";
var dhclient = "/usr/bin/sudo /sbin/dhcpcd";
var justdhclient = "/usr/bin/sudo /sbin/dhcpcd";
var starthostapd = "systemctl start hostapd.service";
var stophostapd = "systemctl stop hostapd.service";
var ifconfigHotspot = "ifconfig " + wlan + " 192.168.211.1 up";
var ifconfigWlan = "ifconfig " + wlan + " up";
var ifdeconfig = "sudo ip addr flush dev " + wlan + " && sudo ifconfig " + wlan + " down";
var execSync = require('child_process').execSync;
var exec = require('child_process').exec;
var ifconfig = require('/volumio/app/plugins/system_controller/network/lib/ifconfig.js');
var wirelessEstablishedOnceFlagFile = '/data/flagfiles/wirelessEstablishedOnce';
var wirelessWPADriver = getWirelessWPADriverString();
// If true, only one network device can be active at a time between ethernet and wireless
var singleNetworkMode = true;
var networkMonitorInterval;
var isWiredNetworkActive = false;

startWiredNetworkingMonitor();

if (debug) {
    var wpasupp = "wpa_supplicant -d -s -B -D" + wirelessWPADriver + " -c/etc/wpa_supplicant/wpa_supplicant.conf -i" + wlan;
} else {
    var wpasupp = "wpa_supplicant -s -B -D" + wirelessWPADriver + " -c/etc/wpa_supplicant/wpa_supplicant.conf -i" + wlan;
}

function kill(process, callback) {
    var all = process.split(" ");
    var process = all[0];
    var command = 'kill `pgrep -f "^' + process + '"` || true';
    logger("killing: " + command);
    return thus.exec(command, callback);
}



function launch(fullprocess, name, sync, callback) {
    if (sync) {
        var child = thus.exec(fullprocess, {}, callback);
        child.stdout.on('data', function(data) {
            logger(name + 'stdout: ' + data);
        });

        child.stderr.on('data', function(data) {
            logger(name + 'stderr: ' + data);
        });

        child.on('close', function(code) {
            logger(name + 'child process exited with code ' + code);
        });
    } else {
        var all = fullprocess.split(" ");
        var process = all[0];
        if (all.length > 0) {
            all.splice(0, 1);
        }
        logger("launching " + process + " args: ");
        logger(all);
        var child = thus.spawn(process, all, {});
        child.stdout.on('data', function(data) {
            logger(name + 'stdout: ' + data);
        });

        child.stderr.on('data', function(data) {
            logger(name + 'stderr: ' + data);
        });

        child.on('close', function(code) {
            logger(name + 'child process exited with code ' + code);
        });
        callback();
    }

    return
}


function startHotspot() {
    stopHotspot(function(err) {
        if (isHotspotDisabled()) {
            console.log('Hotspot is disabled, not starting it');
            launch(ifconfigWlan, "configwlanup", true, function(err) {
                logger("ifconfig " + err);
            });
        } else {
            launch(ifconfigHotspot, "confighotspot", true, function(err) {
                logger("ifconfig " + err);
                launch(starthostapd,"hotspot" , false, function() {
                    wstatus("hotspot");
                });
            });
        }
    });
}

function startHotspotForce() {
    stopHotspot(function(err) {
        console.log('Starting Force Hotspot')
        launch(ifconfigHotspot, "confighotspot", true, function(err) {
            logger("ifconfig " + err);
            launch(starthostapd,"hotspot" , false, function() {
                wstatus("hotspot");
            });
        });
    });
}

function stopHotspot(callback) {
    launch(stophostapd, "stophotspot" , true, function(err) {
        launch(ifdeconfig, "ifdeconfig", true, callback);
    });
}

function startAP(callback) {
    console.log("Stopped hotspot (if there)..");
    launch(ifdeconfig, "ifdeconfig", true,  function(err) {
        logger("Conf " + ifdeconfig);
        launch(wpasupp, "wpa supplicant", false, function(err) {
            logger("wpasupp " + err);
            wpaerr = err;
            try {
                dhclient = fs.readFileSync('/data/configuration/wlanstatic', 'utf8');
                console.log("FIXED IP");
            } catch (e) {
                console.log("DHCP IP ");
            }
            launch(dhclient,"dhclient", false, callback);
        });
    });
}

function stopAP(callback) {
    kill(justdhclient, function(err) {
        kill(wpasupp, function(err) {
            callback();
        });
    });
}
var wpaerr;
var lesstimer;
var totalSecondsForConnection = 20;
var pollingTime = 1;
var actualTime = 0;
var apstopped = 0

function startFlow() {
    try {
        var netconfigured = fs.statSync('/data/configuration/netconfigured');
    } catch (e) {
        var directhotspot = true;
    }

    try {
        fs.accessSync('/tmp/forcehotspot', fs.F_OK);
        var hotspotForce = true;
        fs.unlinkSync('/tmp/forcehotspot')
    } catch (e) {
        var hotspotForce = false;
    }
    if (hotspotForce) {
        console.log('Wireless networking forced to hotspot mode');
        startHotspotForce(function () {});
    } else if (isWirelessDisabled() || (singleNetworkMode && isWiredNetworkActive)) {
        console.log('Wireless Networking DISABLED, not starting wireless flow');
    } else if (directhotspot){
        startHotspot(function () {});
    } else {
        console.log("Start wireless flow");
        startAP(function () {
            console.log("Start ap");
            lesstimer = setInterval(()=> {
                actualTime += pollingTime;
                if (wpaerr > 0) {
                    actualTime = totalSecondsForConnection + 1;
                }

                if (actualTime > totalSecondsForConnection) {
                    console.log("Overtime, starting plan B");
                    if (hotspotFallbackCondition()) {
                        console.log('STARTING HOTSPOT');
                        apstopped = 1;
                        clearTimeout(lesstimer);
                        stopAP(function () {
                            setTimeout(()=> {
                                startHotspot(function (err) {
                                    if(err) {
                                        console.log('Could not start Hotspot Fallback: ' + err);
                                    }
                                });
                            }, settleTime);
                        });
                    } else {
                        apstopped = 0;
                        wstatus("ap");
                        clearTimeout(lesstimer);
                    }
                } else {
                    var SSID = undefined;
                    console.log("trying...");
                    try {
                        var SSID = execSync("/usr/bin/sudo /sbin/iwgetid -r", { uid: 1000, gid: 1000, encoding: 'utf8'});
                        console.log('Connected to: ----'+SSID+'----');
                    } catch(e) {
                        //console.log('ERROR: '+e)
                    }


                    if (SSID != undefined) {
                        ifconfig.status(wlan, function (err, ifstatus) {
                            console.log("... joined AP, wlan0 IPv4 is " + ifstatus.ipv4_address + ", ipV6 is " + ifstatus.ipv6_address);
                            if (((ifstatus.ipv4_address != undefined) &&
                                (ifstatus.ipv4_address.length > "0.0.0.0".length))
                                ||
                                ((ifstatus.ipv6_address != undefined) &&
                                (ifstatus.ipv6_address.length > "::".length))) {
                                if (apstopped == 0) {
                                    console.log("It's done! AP");
                                    wstatus("ap");
                                    clearTimeout(lesstimer);
                                    restartAvahi();
                                    saveWirelessConnectionEstablished();
                                }
                            }
                        });
                    }

                }
            }, pollingTime * 1000);
        });
    }
}

function stop(callback) {
    stopAP(function() {
        stopHotspot(callback);
    });
}

if ( ! fs.existsSync("/sys/class/net/" + wlan + "/operstate") ) {
    console.log("WIRELESS: No wireless interface, exiting");
    process.exit(0);
}


if (process.argv.length < 2) {
    console.log("Use: start|stop");
} else {
    var args = process.argv[2];
    logger('WIRELESS DAEMON: ' + args);

    switch (args) {
        case "start":
            initializeWirelessFlow();
            break;
        case "stop":
            stopAP(function() {});
            break;
        case "test":
            wstatus("test");
            break;
    }
}

function initializeWirelessFlow() {
    console.log("Wireless.js initializing wireless flow");
    console.log("Cleaning previous...");
    stopHotspot(function () {
        stopAP(function() {
            console.log("Stopped aP");
            // Here we set the regdomain if not set
            detectAndApplyRegdomain(function() {
                startFlow();
            });
        })});
}

function wstatus(nstatus) {
    thus.exec("echo " + nstatus + " >/tmp/networkstatus", null);
}

function restartAvahi() {
    //thus.exec("/bin/systemctl restart avahi-daemon");
}

function logger(msg) {
    if (debug) {
        console.log(msg)
    }
}

function getWirelessConfiguration() {
    try {
        var conf = fs.readJsonSync('/data/configuration/system_controller/network/config.json');
        logger('WIRELESS: Loaded configuration');
        logger('WIRELESS CONF: ' + JSON.stringify(conf));
    } catch (e) {
        logger('WIRELESS: First boot');
        var conf = fs.readJsonSync('/volumio/app/plugins/system_controller/network/config.json');
    }
    return conf
}

function isHotspotDisabled() {
    var hotspotConf = getWirelessConfiguration();
    var hotspotDisabled = false;
    if (hotspotConf !== undefined && hotspotConf.enable_hotspot !== undefined && hotspotConf.enable_hotspot.value !== undefined && !hotspotConf.enable_hotspot.value) {
        hotspotDisabled = true;
    }
    return hotspotDisabled
}

function isWirelessDisabled() {
    var wirelessConf = getWirelessConfiguration();
    var wirelessDisabled = false;
    if (wirelessConf !== undefined && wirelessConf.wireless_enabled !== undefined && wirelessConf.wireless_enabled.value !== undefined && !wirelessConf.wireless_enabled.value) {
        wirelessDisabled = true;
    }
    return wirelessDisabled
}

function hotspotFallbackCondition() {
    var hotspotFallbackConf = getWirelessConfiguration();
    var startHotspotFallback = false;
    if (hotspotFallbackConf !== undefined && hotspotFallbackConf.hotspot_fallback !== undefined && hotspotFallbackConf.hotspot_fallback.value !== undefined && hotspotFallbackConf.hotspot_fallback.value) {
        startHotspotFallback = true;
    }
    if (!startHotspotFallback && !hasWirelessConnectionBeenEstablishedOnce()) {
        startHotspotFallback = true;
    }
    return startHotspotFallback
}

function saveWirelessConnectionEstablished() {
    try {
        fs.ensureFileSync(wirelessEstablishedOnceFlagFile)
    } catch (e) {
        logger('Could not save Wireless Connection Established: ' + e);
    }
}

function hasWirelessConnectionBeenEstablishedOnce() {
    var wirelessEstablished = false;
    try {
        if (fs.existsSync(wirelessEstablishedOnceFlagFile)) {
            wirelessEstablished = true;
        }
    } catch(err) {}
    return wirelessEstablished
}

function getWirelessWPADriverString() {
    try {
        var volumioHW = execSync("cat /etc/os-release | grep ^VOLUMIO_HARDWARE | tr -d 'VOLUMIO_HARDWARE=\"'", { uid: 1000, gid: 1000, encoding: 'utf8'}).replace('\n','');
    } catch(e) {
        var volumioHW = 'none';
    }
    var fullDriver = 'nl80211,wext';
    var onlyWextDriver = 'wext';
    if (volumioHW === 'nanopineo2') {
        return onlyWextDriver
    } else {
        return fullDriver
    }
}

function detectAndApplyRegdomain(callback) {
    if (isWirelessDisabled()) {
        return callback();
    }
    var appropriateRegDom = '00';
    try {
        var currentRegDomain = execSync("/usr/bin/sudo /sbin/ifconfig wlan0 up && /usr/bin/sudo /sbin/iw reg get | grep country | cut -f1 -d':'", { uid: 1000, gid: 1000, encoding: 'utf8'}).replace(/country /g, '').replace('\n','');
        var countryCodesInScan = execSync("/usr/bin/sudo /sbin/ifconfig wlan0 up && /usr/bin/sudo /sbin/iw wlan0 scan | grep Country: | cut -f 2", { uid: 1000, gid: 1000, encoding: 'utf8'}).replace(/Country: /g, '').split('\n');
        var appropriateRegDomain = determineMostAppropriateRegdomain(countryCodesInScan);
        logger('CURRENT REG DOMAIN: ' + currentRegDomain)
        logger('APPROPRIATE REG DOMAIN: ' + appropriateRegDomain)
        if (isValidRegDomain(appropriateRegDomain) && appropriateRegDomain !== currentRegDomain) {
            applyNewRegDomain(appropriateRegDomain);
        }
    } catch(e) {
        console.log('Failed to determine most appropriate reg domain: ' + e);
    }
    callback();
}

function applyNewRegDomain(newRegDom) {
    console.log('SETTING APPROPRIATE REG DOMAIN: ' + newRegDom);

    try {
        execSync("/usr/bin/sudo /sbin/ifconfig wlan0 up && /usr/bin/sudo /sbin/iw reg set " + newRegDom, { uid: 1000, gid: 1000, encoding: 'utf8'});
        //execSync("/usr/bin/sudo /bin/echo 'REGDOMAIN=" + newRegDom + "' > /etc/default/crda", { uid: 1000, gid: 1000, encoding: 'utf8'});
        fs.writeFileSync("/etc/default/crda", "REGDOMAIN=" + newRegDom);
        console.log('SUCCESSFULLY SET NEW REGDOMAIN: ' + newRegDom)
    } catch(e) {
        console.log('Failed to set new reg domain: ' + e);
    }

}

function isValidRegDomain(regDomain) {
    if (regDomain && regDomain.length === 2) {
        return true;
    } else {
        return false;
    }
}

function determineMostAppropriateRegdomain(arr) {
        let compare = "";
        let mostFreq = "";
        if (!arr.length) {
            arr = ['00'];
        }
        arr.reduce((acc, val) => {
            if(val in acc){
                acc[val]++;
            }else{
                acc[val] = 1;
            }
            if(acc[val] > compare){
                compare = acc[val];
                mostFreq = val;
            }
            return acc;
        }, {})
       return mostFreq;
}

function startWiredNetworkingMonitor() {

    if (networkMonitorInterval !== undefined) {
        clearInterval(networkMonitorInterval);
    }
    checkWiredStatus();
    networkMonitorInterval = setInterval(() => {
        checkWiredStatus();
    }, wiredCheckInterval);
}

function checkWiredStatus(callback) {
    isWiredConnected(function(wiredActive) {
        if (wiredActive !== isWiredNetworkActive) {
            isWiredNetworkActive = wiredActive;
            if (wiredActive) {
                logger('ETHERNET: Wired network active, stopping wireless');
            } else {
                logger('ETHERNET: Wired network not active, starting wireless flow');
            }
            initializeWirelessFlow();
        }
    });
}

function isWiredConnected(callback) {
    if (!fs.existsSync("/sys/class/net/" + eth + "/operstate")) {
        logger("ETHERNET: No ethernet interface found");
        return callback(false);
    }
    // TODO: Find a less spammy way to read the IP address
    ifconfig.status(eth, function (err, ifstatus) {
        if (err) {
            logger("ETHERNET: Error checking ethernet status: " + err);
            return callback(false);
        }
        var hasIP = false;
        if (ifstatus && (ifstatus.ipv4_address && ifstatus.ipv4_address.length > "0.0.0.0".length)) {
            hasIP = true;
            logger("ETHERNET: Connected with IP - IPv4: " + ifstatus.ipv4_address);
        } else {
            logger("ETHERNET: Interface exists but no IP address assigned");
        }
        return callback(hasIP);
    });
}
