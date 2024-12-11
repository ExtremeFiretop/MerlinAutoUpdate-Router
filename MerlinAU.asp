<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <!-- Use router-provided CSS -->
    <meta http-equiv="X-UA-Compatible" content="IE=Edge" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="-1" />
    <link rel="shortcut icon" href="images/favicon.png" />
    <link rel="icon" href="images/favicon.png" />
    <link rel="stylesheet" type="text/css" href="index_style.css" />
    <link rel="stylesheet" type="text/css" href="form_style.css" />
    <!-- Other meta tags and links -->
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <!-- Existing scripts -->
    <script type="text/javascript" src="/state.js"></script>
    <script type="text/javascript" src="/general.js"></script>
    <script type="text/javascript" src="/popup.js"></script>
    <script type="text/javascript" src="/help.js"></script>
    <script type="text/javascript" src="/validator.js"></script>
    <script type="text/javascript">
    var custom_settings;
    // Define color formatting
    var GRNct = "<span style='color:green;'>";
    var NOct = "</span>";
    var REDct = "<span style='color:red;'>";
    
    function initializeFields() {
        console.log("Initializing fields...");
        let changelogCheckEnabled = document.getElementById('changelogCheckEnabled');
        let routerPassword = document.getElementById('routerPassword');
        let fwUpdatePostponement = document.getElementById('fwUpdatePostponement');
        let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');
        let autobackupEnabled = document.getElementById('autobackupEnabled');
        let secondaryEmail = document.getElementById('secondaryEmail');
        let emailFormat = document.getElementById('emailFormat');
        let rogFWBuildType = document.getElementById('rogFWBuildType');
        let tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled');
        let autoUpdatesScriptEnabled = document.getElementById('autoUpdatesScriptEnabled');
        let betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled');
        let fwUpdateDirectory = document.getElementById('fwUpdateDirectory');

        // Read the firmware_check_enable value from the hidden input
        let firmwareCheckEnableValue = document.getElementById('firmware_check_enable').value.trim();
        let fwUpdateEnabled = document.getElementById('fwUpdateEnabled');
        let fwUpdateCheckStatus = document.getElementById('fwUpdateCheckStatus');
    
        // Determine if firmware update check is enabled based on the hidden input value
        let isFwUpdateEnabled = (firmwareCheckEnableValue === '1');
    
        // Set the checkbox state
        if (fwUpdateEnabled) {
            fwUpdateEnabled.checked = isFwUpdateEnabled;
        }
    
        // Update the Firmware Status display
        if (fwUpdateCheckStatus) {
            setStatus('fwUpdateCheckStatus', isFwUpdateEnabled);
        }

        // Safe value assignments
        if (custom_settings) {
            if (routerPassword) routerPassword.value = custom_settings.routerPassword || '';
            if (fwUpdatePostponement) fwUpdatePostponement.value = custom_settings.fwUpdatePostponement || '0';
            if (secondaryEmail) secondaryEmail.value = custom_settings.secondaryEmail || '';
            if (emailFormat) emailFormat.value = custom_settings.emailFormatType || 'HTML';
            if (rogFWBuildType) rogFWBuildType.value = custom_settings.rogFWBuildType || 'ROG';

            if (changelogCheckEnabled) changelogCheckEnabled.checked = parseBoolean(custom_settings.changelogCheckEnabled);
            if (emailNotificationsEnabled) emailNotificationsEnabled.checked = parseBoolean(custom_settings.emailNotificationsEnabled);
            if (autobackupEnabled) autobackupEnabled.checked = parseBoolean(custom_settings.autobackupEnabled);
            if (tailscaleVPNEnabled) tailscaleVPNEnabled.checked = parseBoolean(custom_settings.tailscaleVPNEnabled);
            if (autoUpdatesScriptEnabled) autoUpdatesScriptEnabled.checked = parseBoolean(custom_settings.autoUpdatesScriptEnabled);
            if (betaToReleaseUpdatesEnabled) betaToReleaseUpdatesEnabled.checked = parseBoolean(custom_settings.betaToReleaseUpdatesEnabled);
            if (fwUpdateDirectory) fwUpdateDirectory.value = custom_settings.fwUpdateDirectory || '';

            // Update Settings Status Table
            setStatus('changelogCheckStatus', parseBoolean(custom_settings.changelogCheckEnabled));
            setStatus('betaToReleaseUpdatesStatus', parseBoolean(custom_settings.betaToReleaseUpdatesEnabled));
            setStatus('tailscaleVPNAccessStatus', parseBoolean(custom_settings.tailscaleVPNEnabled));
            setStatus('autobackupEnabledStatus', parseBoolean(custom_settings.autobackupEnabled));
            setStatus('autoUpdatesScriptEnabledStatus', parseBoolean(custom_settings.autoUpdatesScriptEnabled));
            setStatus('emailNotificationsStatus', parseBoolean(custom_settings.emailNotificationsEnabled));

            // **Handle fwUpdateEstimatedRunDate Separately**
            var fwUpdateEstimatedRunDateElement = document.getElementById('fwUpdateEstimatedRunDate');

            // **Handle fwUpdateAvailable with Version Comparison**
            var fwUpdateAvailableElement = document.getElementById('fwUpdateAvailable');
            var fwVersionInstalledElement = document.getElementById('fwVersionInstalled');

            var isFwUpdateAvailable = false; // Initialize the flag

            if (fwUpdateAvailableElement && fwVersionInstalledElement) {
                var fwUpdateAvailable = custom_settings.fwUpdateAvailable ? custom_settings.fwUpdateAvailable.trim() : '';
                var fwVersionInstalled = fwVersionInstalledElement.textContent.trim();

                // Optional: Normalize version strings for accurate comparison
                var fwUpdateAvailableNormalized = fwUpdateAvailable.toLowerCase();
                var fwVersionInstalledNormalized = fwVersionInstalled.toLowerCase();

                // Compare versions and update the DOM accordingly
                if (fwUpdateAvailable && fwUpdateAvailableNormalized !== fwVersionInstalledNormalized) {
                    fwUpdateAvailableElement.innerHTML = GRNct + fwUpdateAvailable + NOct;
                    isFwUpdateAvailable = true; // Update is available
                } else {
                    fwUpdateAvailableElement.innerHTML = REDct + "NONE FOUND" + NOct;
                    isFwUpdateAvailable = false; // No update available
                }
            } else {
                console.error("Required elements for firmware version comparison not found.");
            }

            // **Update fwUpdateEstimatedRunDate Based on fwUpdateAvailable**
            if (fwUpdateEstimatedRunDateElement) {
                if (isFwUpdateAvailable && fwUpdateEstimatedRunDate) {
                    fwUpdateEstimatedRunDateElement.innerHTML = GRNct + fwUpdateEstimatedRunDate + NOct;
                } else {
                    fwUpdateEstimatedRunDateElement.innerHTML = REDct + "Disabled" + NOct;
                }
            }

        } else {
            console.error("Custom settings not loaded.");
        }
    }

    function get_conf_file() {
        $.ajax({
            url: '/ext/MerlinAU/custom_settings.htm',
            dataType: 'text',
            error: function(xhr) {
                console.error("Failed to fetch custom_settings.htm:", xhr.statusText);
                setTimeout(get_conf_file, 1000); // Retry after 1 second
            },
            success: function(data) {
                // Initialize an empty object to store relevant settings
                custom_settings = {};

                // Tokenize the data while respecting quoted values
                var tokens = tokenize(data);

                // Iterate through tokens to extract key-value pairs
                for (var i = 0; i < tokens.length; i++) {
                    var token = tokens[i];

                    if (token.includes('=')) {
                        // Handle key=value format
                        var splitIndex = token.indexOf('=');
                        var key = token.substring(0, splitIndex).trim();
                        var value = token.substring(splitIndex + 1).trim();

                        // Remove surrounding quotes if present
                        if (value.startsWith('"') && value.endsWith('"')) {
                            value = value.substring(1, value.length - 1);
                        }

                        assignSetting(key, value);
                    } else {
                        // Handle key value format
                        var key = token.trim();
                        var value = '';

                        // Ensure there's a next token for the value
                        if (i + 1 < tokens.length) {
                            value = tokens[i + 1].trim();

                            // Remove surrounding quotes if present
                            if (value.startsWith('"') && value.endsWith('"')) {
                                value = value.substring(1, value.length - 1);
                            }

                            assignSetting(key, value);
                            i++; // Skip the next token as it's already processed
                        } else {
                            console.warn(`No value found for key: ${key}`);
                        }
                    }
                }

                console.log("Custom Settings Loaded via AJAX:", custom_settings);

                // Initialize fields with the loaded settings
                initializeFields();
            }
        });
    }

    // Helper function to tokenize the input string, respecting quoted substrings
    function tokenize(input) {
        var regex = /(?:[^\s"]+|"[^"]*")+/g;
        return input.match(regex) || [];
    }

    // Helper function to assign settings based on key
    function assignSetting(key, value) {
        // Normalize key to uppercase for case-insensitive comparison
        var keyUpper = key.toUpperCase();

        switch (true) {
            case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_VERS':
                custom_settings.fwUpdateAvailable = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_EXPECTED_RUN_DATE':
                fwUpdateEstimatedRunDate = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_NOTIFICATION':
                custom_settings.emailNotificationsEnabled = parseBoolean(value);
                break;

            case keyUpper === 'CHECKCHANGELOG':
                custom_settings.changelogCheckEnabled = parseBoolean(value);
                break;

            case keyUpper === 'FW_ALLOW_BETA_PRODUCTION_UP':
                custom_settings.betaToReleaseUpdatesEnabled = parseBoolean(value);
                break;

            case keyUpper === 'ALLOW_UPDATES_OVERVPN':
                custom_settings.tailscaleVPNEnabled = parseBoolean(value);
                break;

            case keyUpper === 'FW_AUTO_BACKUPMON':
                custom_settings.autobackupEnabled = parseBoolean(value);
                break;

            case keyUpper === 'ALLOW_SCRIPT_AUTO_UPDATE':
                custom_settings.autoUpdatesScriptEnabled = parseBoolean(value);
                break;

            // Set Directory for F/W Updates
            case keyUpper === 'FW_NEW_UPDATE_ZIP_DIRECTORY_PATH':
                custom_settings.fwUpdateDirectory = value;
                break;

            // F/W Update Postponement Days
            case keyUpper === 'FW_NEW_UPDATE_POSTPONEMENT_DAYS':
                custom_settings.fwUpdatePostponement = value;
                break;

            // Router Login Password (Base64 Encoded)
            case keyUpper === 'CREDENTIALS_BASE64':
                try {
                    var decoded = atob(value);
                    var password = decoded.split(':')[1] || '';
                    custom_settings.routerPassword = password;
                } catch (e) {
                    console.error("Error decoding credentials_base64:", e);
                }
                break;

            // Additional settings can be handled here
            case keyUpper === 'ROGBuild':
                 custom_settings.rogFWBuildType = value;
                 break;

            // Additional settings can be handled here
            // Example:
            // case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_DATE':
            //     custom_settings.fwUpdateNotificationDate = value;
            //     break;

            default:
                // Optionally handle or log unknown settings
                break;
        }
    }

    // Helper function to set status with color
    function setStatus(elementId, isEnabled) {
        var element = document.getElementById(elementId);
        if (element) {
            if (isEnabled) {
                element.innerHTML = GRNct + "Enabled" + NOct;
            } else {
                element.innerHTML = REDct + "Disabled" + NOct;
            }
        }
    }

    function SetCurrentPage() {
        /* Set the proper return pages */
        document.form.next_page.value = window.location.pathname.substring(1);
        document.form.current_page.value = window.location.pathname.substring(1);
    }

    function parseBoolean(value) {
        if (typeof value === 'boolean') return value;
        if (typeof value === 'string') {
            return value.toLowerCase() === 'true' || value.toLowerCase() === 'enabled';
        }
        return false;
    }

    function initial() {
        SetCurrentPage();
        get_conf_file();
        show_menu();

        // Debugging iframe behavior
        var hiddenFrame = document.getElementById('hidden_frame');
        if (hiddenFrame) {
            hiddenFrame.onload = function () {
                console.log("Hidden frame loaded with server response.");
                hideLoading();
                window.location.reload(); // Automatically reload the page to reflect changes
            };

            initializeCollapsibleSections();
        }
    }

    function SaveActionsConfig() {
        // Retrieve the password from the input field
        var password = document.getElementById('routerPassword')?.value || '';

        // Retrieve the username from the hidden input. Default to 'admin' if not found.
        var usernameElement = document.getElementById('http_username');
        var username = usernameElement ? usernameElement.value.trim() : 'admin';

        // Validate that username is not empty
        if (!username) {
            console.error("HTTP username is missing.");
            alert("HTTP username is not set. Please contact your administrator.");
            return;
        }

        // Combine username and password in the format 'username:password'
        var credentials = username + ':' + password;
    
        // Encode the combined string into Base64
        var encodedCredentials = btoa(credentials);
    
        // Assign the encoded credentials to 'CREDENTIALS_BASE64'
        custom_settings.CREDENTIALS_BASE64 = encodedCredentials;
    
        // Remove the plaintext password from custom_settings if it exists
        delete custom_settings.routerPassword;

        custom_settings.fwUpdatePostponement = document.getElementById('fwUpdatePostponement')?.value || '0';
        custom_settings.fwUpdateEnabled = document.getElementById('fwUpdateEnabled').checked;
        custom_settings.changelogCheckEnabled = document.getElementById('changelogCheckEnabled').checked;

        // Save to hidden input field
        document.getElementById('amng_custom').value = JSON.stringify(custom_settings);

        // Add a timeout fallback
        setTimeout(() => {
            console.warn("Server response timed out.");
            hideLoading();
        }, 10000);

        // Apply the settings
        showLoading();
        document.form.submit();
        console.log("Form submitted.");
    }

    function SaveAdvancedConfig() {
        custom_settings.secondaryEmail = document.getElementById('secondaryEmail')?.value || '';
        custom_settings.emailFormatType = document.getElementById('emailFormat')?.value || 'HTML';
        custom_settings.rogFWBuildType = document.getElementById('rogFWBuildType')?.value || 'ROG';
        custom_settings.emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled').checked;
        custom_settings.autobackupEnabled = document.getElementById('autobackupEnabled').checked;
        custom_settings.tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled').checked;
        custom_settings.autoUpdatesScriptEnabled = document.getElementById('autoUpdatesScriptEnabled').checked;
        custom_settings.betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled').checked;
        custom_settings.fwUpdateDirectory = document.getElementById('fwUpdateDirectory')?.value || '';

        // Save to hidden input field
        document.getElementById('amng_custom').value = JSON.stringify(custom_settings);

        // Add a timeout fallback
        setTimeout(() => {
            console.warn("Server response timed out.");
            hideLoading();
        }, 10000);

        // Apply the settings
        showLoading();
        document.form.submit();
        console.log("Form submitted.");
    }

    // Function to get the first non-empty value from a list of element IDs
    function getFirstNonEmptyValue(ids) {
        for (var i = 0; i < ids.length; i++) {
            var elem = document.getElementById(ids[i]);
            if (elem) {
                var value = elem.value.trim();
                if (value.length > 0) {
                    return value;
                }
            }
        }
        return "";
    }

    // Function to format and display the Router IDs
    function formatRouterIDs() {
        // Define the order of NVRAM keys to search for Model ID and Product ID
        var modelKeys = ["nvram_odmpid", "nvram_wps_modelnum", "nvram_model", "nvram_build_name"];
        var productKeys = ["nvram_productid", "nvram_build_name", "nvram_odmpid"];

        // Retrieve the first non-empty values
        var MODEL_ID = getFirstNonEmptyValue(modelKeys);
        var PRODUCT_ID = getFirstNonEmptyValue(productKeys);

        // Construct FW_RouterProductID with formatting
        var FW_RouterProductID = GRNct + PRODUCT_ID + NOct;

        // Convert MODEL_ID to uppercase for comparison
        var MODEL_ID_UPPER = MODEL_ID.toUpperCase();

        // Determine FW_RouterModelID based on comparison
        var FW_RouterModelID = "";
        if (PRODUCT_ID === MODEL_ID_UPPER) {
            FW_RouterModelID = FW_RouterProductID;
        } else {
            FW_RouterModelID = FW_RouterProductID + "/" + GRNct + MODEL_ID + NOct;
        }

        // Update the HTML table cells
        var productModelCell = document.getElementById('firmwareProductModelID');
        if (productModelCell) {
            productModelCell.innerHTML = FW_RouterProductID;
        }

        // Update the consolidated 'firmver' hidden input
        var firmverInput = document.getElementById('firmver');
        if (firmverInput) {
            firmverInput.value = stripHTML(FW_RouterModelID); // Optionally strip HTML tags
        }
    }

    // Optional: Function to strip HTML tags from a string (to store plain text in hidden input)
    function stripHTML(html) {
        var tmp = document.createElement("DIV");
        tmp.innerHTML = html;
        return tmp.textContent || tmp.innerText || "";
    }

    // Function to format the Firmware Version Installed
    function formatFirmwareVersion() {
        var fwVersionElement = document.getElementById('fwVersionInstalled');
        if (fwVersionElement) {
            var version = fwVersionElement.textContent.trim();
            // Split the version string by dots
            var parts = version.split('.');
            if (parts.length >= 4) {
                // Combine the first four parts without dots
                var firstPart = parts.slice(0, 4).join('');
                // Combine the remaining parts with dots
                var remainingParts = parts.slice(4).join('.');
                // Construct the formatted version
                var formattedVersion = firstPart + '.' + remainingParts;
                // Update the table cell with the formatted version
                fwVersionElement.textContent = formattedVersion;
            } else {
                console.warn("Unexpected firmware version format:", version);
            }
        } else {
            console.error("Element with id 'fwVersionInstalled' not found.");
        }
    }

    // Modify the existing DOMContentLoaded event listener to include the new function
    document.addEventListener("DOMContentLoaded", function() {
        formatRouterIDs();
        formatFirmwareVersion(); // Call the new formatting function
    });

    function initializeCollapsibleSections() {
        if (typeof jQuery !== 'undefined') {
            $('.collapsible-jquery').each(function() {
                // Ensure sections are expanded by default
                $(this).addClass('active');  // Add 'active' class to indicate expanded state
                $(this).next('tbody').show();  // Make sure content is visible

                // Add a cursor pointer for better UX
                $(this).css('cursor', 'pointer');

                // Toggle logic on click
                $(this).on('click', function() {
                    $(this).toggleClass('active');
                    $(this).next('tbody').slideToggle();
                });
            });
        } else {
            console.error("jQuery is not loaded. Collapsible sections will not work.");
        }
    }
    </script>
</head>
<body onload="initial();" class="bg">
    <div id="TopBanner"></div>
    <div id="Loading" class="popup_bg"></div>
    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <form method="post" name="form" action="start_apply.htm" target="hidden_frame">
        <input type="hidden" name="action_script" value="start_merlinau" />
        <input type="hidden" name="current_page" value="" />
        <input type="hidden" name="next_page" value="" />
        <input type="hidden" name="modified" value="0" />
        <input type="hidden" name="action_mode" value="apply" />
        <input type="hidden" name="action_wait" value="90" />
        <input type="hidden" name="first_time" value="" />
        <input type="hidden" name="SystemCmd" value="" />
        <input type="hidden" id="http_username" value="<% nvram_get("http_username"); %>" />
        <input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get('preferred_lang'); %>" />
        <!-- Consolidated firmver input -->
        <input type="hidden" name="firmver" id="firmver" value="<% nvram_get('firmver'); %>.<% nvram_get('buildno'); %>.<% nvram_get('extendno'); %>" />
        <input type="hidden" id="firmware_check_enable" value="<% nvram_get("firmware_check_enable"); %>" />
        <input type="hidden" id="nvram_odmpid" value="<% nvram_get("odmpid"); %>" />
        <input type="hidden" id="nvram_wps_modelnum" value="<% nvram_get("wps_modelnum"); %>" />
        <input type="hidden" id="nvram_model" value="<% nvram_get("model"); %>" />
        <input type="hidden" id="nvram_build_name" value="<% nvram_get("build_name"); %>" />
        <input type="hidden" id="nvram_productid" value="<% nvram_get("productid"); %>" />
        <input type="hidden" name="installedfirm" value="<% nvram_get("innerver"); %>" />
        <input type="hidden" name="amng_custom" id="amng_custom" value="" />

        <table class="content" cellpadding="0" cellspacing="0" style="margin:0 auto;">
            <tr>
                <td width="17">&nbsp;</td>
                <td width="202" valign="top">
                    <div id="mainMenu"></div>
                    <div id="subMenu"></div>
                </td>
                <td valign="top">
                    <div id="tabMenu" class="submenuBlock"></div>

                    <table width="98%" border="0" cellpadding="0" cellspacing="0">
                        <tr>
                            <td valign="top">
                                <table width="760px" cellpadding="4" cellspacing="0" class="FormTitle" style="height: 1169px;">
                                    <tbody>
                                        <tr style="background-color:#4D595D;">
                                            <td valign="top">
                                                <div>&nbsp;</div>
                                                <div class="formfonttitle" style="text-align:center;">MerlinAU Dashboard v1.3.8</div>
                                                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                                <div class="formfontdesc">
                                                    This is the MerlinAU AMTM add-on integrated into the router WebUI.
                                                </div>
                                                <div style="line-height:10px;">&nbsp;</div>


                                                <!-- Parent Table to Arrange Firmware and Settings Status Side by Side -->
                                                <table width="100%" cellpadding="0" cellspacing="0" style="border: none; background-color: transparent;">
                                                    <tr>
                                                        <!-- Firmware Status Column -->
                                                        <td valign="top" width="50%" style="padding-right: 5px;">
                                                            <!-- Firmware Status Section -->
                                                            <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                                <thead class="collapsible-jquery" id="firmwareStatusSection">
                                                                    <tr>
                                                                        <!-- Adjust colspan to match the number of internal tables -->
                                                                        <td colspan="2">Firmware Status (click to expand/collapse)</td>
                                                                    </tr>
                                                                </thead>
                                                                <tbody>
                                                                    <tr>
                                                                        <!-- First internal table in the first column -->
                                                                        <td style="vertical-align: top; width: 50%;">
                                                                            <table style="margin: 0; text-align: left; width: 100%; border: none;">
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>F/W Product/Model ID:</strong></td>
                                                                                    <td style="padding: 4px;" id="firmwareProductModelID"></td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>USB Storage Connected:</strong></td>
                                                                                    <td style="padding: 4px;">NO CODE YET</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>F/W Version Installed:</strong></td>
                                                                                    <td style="padding: 4px;" id="fwVersionInstalled">
                                                                                        <% nvram_get("firmver"); %>.<% nvram_get("buildno"); %>.<% nvram_get("extendno"); %>
                                                                                    </td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>F/W Update Available:</strong></td>
                                                                                    <td id="fwUpdateAvailable" style="padding: 4px;">NONE FOUND</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>F/W Update Estimated Run Date:</strong></td>
                                                                                    <td id="fwUpdateEstimatedRunDate" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>F/W Update Check:</strong></td>
                                                                                    <td id="fwUpdateCheckStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                            </table>
                                                                        </td>
                                                                    </tr>
                                                                </tbody>
                                                            </table>
                                                        </td>

                                                        <!-- Settings Status Column -->
                                                        <td valign="top" width="50%" style="padding-left: 5px;">
                                                            <!-- Settings Status Section -->
                                                            <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                                <thead class="collapsible-jquery" id="settingsStatusSection">
                                                                    <tr>
                                                                        <!-- Adjust colspan to match the number of internal tables -->
                                                                        <td colspan="2">Settings Status (click to expand/collapse)</td>
                                                                    </tr>
                                                                </thead>
                                                                <tbody>
                                                                    <tr>
                                                                        <!-- Second internal table in the second column -->
                                                                        <td style="vertical-align: top; width: 50%;">
                                                                            <table style="margin: 0; text-align: left; width: 100%; border: none;">
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Changelog Check:</strong></td>
                                                                                    <td id="changelogCheckStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Beta-to-Release Updates:</strong></td>
                                                                                    <td id="betaToReleaseUpdatesStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Tailscale VPN Access:</strong></td>
                                                                                    <td id="tailscaleVPNAccessStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Auto-Backup Enabled:</strong></td>
                                                                                    <td id="autobackupEnabledStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Auto-Updates for Script:</strong></td>
                                                                                    <td id="autoUpdatesScriptEnabledStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Email-Notifications:</strong></td>
                                                                                    <td id="emailNotificationsStatus" style="padding: 4px;">Disabled</td>
                                                                                </tr>
                                                                            </table>
                                                                        </td>
                                                                    </tr>
                                                                </tbody>
                                                            </table>
                                                        </td>
                                                    </tr>
                                                </table>

                                                <div style="line-height:10px;">&nbsp;</div>

                                                <!-- Actions Section -->
                                                <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                    <thead class="collapsible-jquery" id="actionsSection">
                                                        <tr>
                                                            <td colspan="2">Actions (click to expand/collapse)</td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>
                                                            <td colspan="2">
                                                                <div style="text-align: center; margin-top: 10px;">
                                                                    <table width="100%" border="0" cellpadding="10" cellspacing="0" style="table-layout: fixed; border-collapse: collapse; background-color: transparent;">
                                                                        <colgroup>
                                                                            <col style="width: 50%;" />
                                                                            <col style="width: 50%;" />
                                                                        </colgroup>
                                                                        <tr>
                                                                            <td style="text-align: right; border: none;">
                                                                                <button type="button" onclick="checkFirmwareUpdate()">Run F/W Update Check Now</button>
                                                                            </td>
                                                                            <td style="text-align: left; border: none;">
                                                                                <button type="button" onclick="Uninstall()">Uninstall Now</button>
                                                                            </td>
                                                                        </tr>
                                                                    </table>
                                                                </div>
                                                                <form id="actionsForm">
                                                                    <table width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;">
                                                                        <colgroup>
                                                                            <col style="width: 50%;" />
                                                                            <col style="width: 50%;" />
                                                                        </colgroup>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="routerPassword">Router Login Password</label></td>
                                                                            <td><input type="password" id="routerPassword" name="routerPassword" style="width: 50%;" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="fwUpdateEnabled">Enable F/W Update Check</label></td>
                                                                            <td><input type="checkbox" id="fwUpdateEnabled" name="fwUpdateEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="fwUpdatePostponement">F/W Update Postponement (0-199 days)</label></td>
                                                                            <td><input type="number" id="fwUpdatePostponement" name="fwUpdatePostponement" min="0" max="199" style="width: 10%;" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="changelogCheckEnabled">Enable Changelog Check</label></td>
                                                                            <td><input type="checkbox" id="changelogCheckEnabled" name="changelogCheckEnabled" /></td>
                                                                        </tr>
                                                                    </table>
                                                                    <div style="text-align: center; margin-top: 10px;">
                                                                        <input type="submit" onclick="SaveActionsConfig(); return false;" value="Save" class="button_gen savebutton" name="button">
                                                                    </div>
                                                                </form>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>

                                                <div style="line-height:10px;">&nbsp;</div>

                                                <!-- Advanced Options Section -->
                                                <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                    <thead class="collapsible-jquery" id="advancedOptionsSection">
                                                        <tr>
                                                            <td colspan="2">Advanced Options (click to expand/collapse)</td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>
                                                            <td colspan="2">
                                                                <form id="advancedOptionsForm">
                                                                    <table width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;">
                                                                        <colgroup>
                                                                            <col style="width: 50%;" />
                                                                            <col style="width: 50%;" />
                                                                        </colgroup>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="fwUpdateDirectory">Set Directory for F/W Updates</label></td>
                                                                            <td><input type="text" id="fwUpdateDirectory" name="fwUpdateDirectory" style="width: 50%;" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="betaToReleaseUpdatesEnabled">Beta-to-Release Updates</label></td>
                                                                            <td><input type="checkbox" id="betaToReleaseUpdatesEnabled" name="betaToReleaseUpdatesEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="tailscaleVPNEnabled">Tailscale/ZeroTier VPN Access</label></td>
                                                                            <td><input type="checkbox" id="tailscaleVPNEnabled" name="tailscaleVPNEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="autobackupEnabled">Enable Auto-Backups</label></td>
                                                                            <td><input type="checkbox" id="autobackupEnabled" name="autobackupEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="autoUpdatesScriptEnabled">Auto-Updates for Script</label></td>
                                                                            <td><input type="checkbox" id="autoUpdatesScriptEnabled" name="autoUpdatesScriptEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="rogFWBuildType">ROG F/W Build Type</label></td>
                                                                            <td>
                                                                                <select id="rogFWBuildType" name="rogFWBuildType" style="width: 20%;">
                                                                                    <option value="ROG">ROG</option>
                                                                                    <option value="Pure">Pure</option>
                                                                                </select>
                                                                            </td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="emailNotificationsEnabled">Enable F/W Update Email Notifications</label></td>
                                                                            <td><input type="checkbox" id="emailNotificationsEnabled" name="emailNotificationsEnabled" /></td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="emailFormat">Email Format</label></td>
                                                                            <td>
                                                                                <select id="emailFormat" name="emailFormat" style="width: 20%;">
                                                                                    <option value="HTML">HTML</option>
                                                                                    <option value="PlainText">Plain Text</option>
                                                                                </select>
                                                                            </td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td style="text-align: left;"><label for="secondaryEmail">Secondary Email for Notifications</label></td>
                                                                            <td><input type="email" id="secondaryEmail" name="secondaryEmail" style="width: 50%;" /></td>
                                                                        </tr>
                                                                    </table>
                                                                    <div style="text-align: center; margin-top: 10px;">
                                                                        <input type="submit" onclick="SaveAdvancedConfig(); return false;" value="Save" class="button_gen savebutton" name="button">
                                                                    </div>
                                                                </form>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                                <div style="margin-top:10px;text-align:center;">
                                                    MerlinAU v1.3.8 by ExtremeFiretop &amp; Martinski W.
                                                </div>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
                <td width="10"></td>
            </tr>
        </table>
    </form>

    <div id="footer"></div>
</body>
</html>
