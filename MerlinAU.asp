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
    // Define color formatting
    var GRNct = "<span style='color:cyan;'>";
    var NOct = "</span>";
    var REDct = "<span style='color:red;'>";

    // Separate variables for server and AJAX settings
    var advanced_settings = {};
    var custom_settings = {};
    var server_custom_settings = {};
    var ajax_custom_settings = {};

    function LoadCustomSettings(){
        server_custom_settings = <% get_custom_settings(); %>;
        console.log("Server Custom Settings Loaded:", server_custom_settings);
    }

    function prefixCustomSettings(settings, prefix) {
        let prefixedSettings = {};
        for (let key in settings) {
            if (settings.hasOwnProperty(key)) {
                prefixedSettings[prefix + key] = settings[key];
            }
        }
        return prefixedSettings;
    }

    // Function to handle the visibility of the ROG and TUF F/W Build Type rows
    function handleROGFWBuildTypeVisibility() {
        // Get the router model from the hidden input
        var firmwareProductModelElement = document.getElementById('firmwareProductModelID');
        var routerModel = firmwareProductModelElement ? firmwareProductModelElement.textContent.trim() : '';

        // ROG Model Check
        var isROGModel = routerModel.includes('GT-');
        var hasROGFWBuildType = custom_settings.hasOwnProperty('FW_New_Update_ROGFWBuildType');
        var rogFWBuildRow = document.getElementById('rogFWBuildRow');

        if (!isROGModel || !hasROGFWBuildType) {
            // Hide the ROG row
            if (rogFWBuildRow) {
                rogFWBuildRow.style.display = 'none';
            }
        } else {
            // Show the ROG row
            if (rogFWBuildRow) {
                rogFWBuildRow.style.display = '';
            }
        }

        // TUF Model Check
        var isTUFModel = routerModel.includes('TUF-');
        var hasTUFWBuildType = custom_settings.hasOwnProperty('FW_New_Update_TUFWBuildType');
        var tufFWBuildRow = document.getElementById('tuffFWBuildRow');

        if (!isTUFModel || !hasTUFWBuildType) {
            // Hide the TUF row
            if (tufFWBuildRow) {
                tufFWBuildRow.style.display = 'none';
            }
        } else {
            // Show the TUF row
            if (tufFWBuildRow) {
                tufFWBuildRow.style.display = '';
            }
        }
    }

    function initializeFields() {
        console.log("Initializing fields...");
        let changelogCheckEnabled = document.getElementById('changelogCheckEnabled');
        let fwNotificationsDate = document.getElementById('fwNotificationsDate');
        let routerPassword = document.getElementById('routerPassword');
        let fwUpdatePostponement = document.getElementById('fwUpdatePostponement');
        let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');
        let autobackupEnabled = document.getElementById('autobackupEnabled');
        let secondaryEmail = document.getElementById('secondaryEmail');
        let emailFormat = document.getElementById('emailFormat');
        let rogFWBuildType = document.getElementById('rogFWBuildType');
        let tuffFWBuildType = document.getElementById('tuffFWBuildType');
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
            if (fwUpdatePostponement) fwUpdatePostponement.value = custom_settings.FW_New_Update_Postponement_Days || '0';
            if (secondaryEmail) secondaryEmail.value = custom_settings.FW_New_Update_EMail_CC_Address || '';
            if (emailFormat) emailFormat.value = custom_settings.FW_New_Update_EMail_FormatType || 'HTML';
            if (rogFWBuildType) rogFWBuildType.value = custom_settings.FW_New_Update_ROGFWBuildType || 'ROG';
            if (tuffFWBuildType) tuffFWBuildType.value = custom_settings.FW_New_Update_TUFWBuildType || 'TUF';

            if (changelogCheckEnabled) changelogCheckEnabled.checked = parseBoolean(custom_settings.CheckChangeLog);
            if (emailNotificationsEnabled) emailNotificationsEnabled.checked = parseBoolean(custom_settings.FW_New_Update_EMail_Notification);
            if (autobackupEnabled) autobackupEnabled.checked = parseBoolean(custom_settings.FW_Auto_Backupmon);
            if (tailscaleVPNEnabled) tailscaleVPNEnabled.checked = parseBoolean(custom_settings.Allow_Updates_OverVPN);
            if (autoUpdatesScriptEnabled) autoUpdatesScriptEnabled.checked = parseBoolean(custom_settings.Allow_Script_Auto_Update);
            if (betaToReleaseUpdatesEnabled) betaToReleaseUpdatesEnabled.checked = parseBoolean(custom_settings.FW_Allow_Beta_Production_Up);
            if (fwUpdateDirectory) fwUpdateDirectory.value = custom_settings.FW_New_Update_ZIP_Directory_Path || '';

            // Update Settings Status Table
            setStatus('changelogCheckStatus', parseBoolean(custom_settings.CheckChangeLog));
            setStatus('betaToReleaseUpdatesStatus', parseBoolean(custom_settings.FW_Allow_Beta_Production_Up));
            setStatus('tailscaleVPNAccessStatus', parseBoolean(custom_settings.Allow_Updates_OverVPN));
            setStatus('autobackupEnabledStatus', parseBoolean(custom_settings.FW_Auto_Backupmon));
            setStatus('autoUpdatesScriptEnabledStatus', parseBoolean(custom_settings.Allow_Script_Auto_Update));
            setStatus('emailNotificationsStatus', parseBoolean(custom_settings.FW_New_Update_EMail_Notification));

            // Handle fwNotificationsDate as a date
            if (fwNotificationsDate && custom_settings.FW_New_Update_Notifications_Date) {
                fwNotificationsDate.innerHTML = GRNct + custom_settings.FW_New_Update_Notifications_Date + NOct;
            } else if (fwNotificationsDate) {
                fwNotificationsDate.innerHTML = REDct + "TBD" + NOct;
            }

            // **Handle fwUpdateEstimatedRunDate Separately**
            var fwUpdateEstimatedRunDateElement = document.getElementById('fwUpdateEstimatedRunDate');

            // **Handle fwUpdateAvailable with Version Comparison**
            var fwUpdateAvailableElement = document.getElementById('fwUpdateAvailable');
            var fwVersionInstalledElement = document.getElementById('fwVersionInstalled');

            var isFwUpdateAvailable = false; // Initialize the flag

            if (fwUpdateAvailableElement && fwVersionInstalledElement) {
                var fwUpdateAvailable = custom_settings.FW_New_Update_Available ? custom_settings.FW_New_Update_Available.trim() : '';
                var fwVersionInstalled = fwVersionInstalledElement.textContent.trim();

                // Optional: Normalize version strings for accurate comparison
                var fwUpdateAvailableNormalized = fwUpdateAvailable.toLowerCase();
                var fwVersionInstalledNormalized = fwVersionInstalled.toLowerCase();

                // Compare versions and update the DOM accordingly
                if (fwUpdateAvailableNormalized === 'tbd') {
                    fwUpdateAvailableElement.innerHTML = REDct + "NONE FOUND" + NOct;
                    isFwUpdateAvailable = false; // No update available
                } else if (fwUpdateAvailable && fwUpdateAvailableNormalized !== fwVersionInstalledNormalized) {
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
                if (isFwUpdateAvailable && fwUpdateEstimatedRunDateElement.textContent.trim() !== '') {
                    fwUpdateEstimatedRunDateElement.innerHTML = GRNct + fwUpdateEstimatedRunDateElement.textContent.trim() + NOct;
                } else {
                    fwUpdateEstimatedRunDateElement.innerHTML = REDct + "TBD" + NOct;
                }
            }

            // **Handle Changelog Approval Display**
            var changelogApprovalElement = document.getElementById('changelogApproval');
            if (changelogApprovalElement) {
                var approvalStatus = custom_settings.hasOwnProperty('FW_New_Update_Changelog_Approval') ? custom_settings.FW_New_Update_Changelog_Approval : "DISABLED"; // Default to "DISABLED" if missing
                if (approvalStatus === "TBD") {
                    changelogApprovalElement.innerHTML = REDct + approvalStatus + NOct;
                } else if (approvalStatus === "BLOCKED") {
                    changelogApprovalElement.innerHTML = REDct + approvalStatus + NOct;
                } else if (approvalStatus === "APPROVED") {
                    changelogApprovalElement.innerHTML = GRNct + approvalStatus + NOct;
                } else {
                    // Handle unexpected values gracefully
                    changelogApprovalElement.innerHTML = REDct + approvalStatus + NOct;
                }
            }

            // **Control "Approve Changelog" Button Visibility**
            var approveChangelogButton = document.getElementById('approveChangelogButton');
            if (approveChangelogButton) {
                var isChangelogCheckEnabled = custom_settings.CheckChangeLog;
                var changelogApprovalValue = custom_settings.FW_New_Update_Changelog_Approval;

                // Condition: Show button only if
                // 1. Changelog Check is enabled
                // 2. Changelog Approval is neither empty nor "TBD"
                if (isChangelogCheckEnabled && changelogApprovalValue && changelogApprovalValue !== 'TBD') {
                    approveChangelogButton.style.display = 'inline-block'; // Show the button
                } else {
                    approveChangelogButton.style.display = 'none'; // Hide the button
                }
            }

            // Call the visibility handler
            handleROGFWBuildTypeVisibility();

        } else {
            console.error("Custom settings not loaded.");
        }
    }

    function get_conf_file() {
        $.ajax({
            url: '/ext/MerlinAU.d/custom_settings.htm',
            dataType: 'text',
            error: function(xhr) {
                console.error("Failed to fetch custom_settings.htm:", xhr.statusText);
                setTimeout(get_conf_file, 1000); // Retry after 1 second
            },
            success: function(data) {
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

                        assignAjaxSetting(key, value);
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

                            assignAjaxSetting(key, value);
                            i++; // Skip the next token as it's already processed
                        } else {
                            console.warn(`No value found for key: ${key}`);
                        }
                    }
                }

                console.log("AJAX Custom Settings Loaded:", ajax_custom_settings);

                // Merge both server and AJAX settings
                custom_settings = Object.assign({}, server_custom_settings, ajax_custom_settings);
                console.log("Merged Custom Settings:", custom_settings);

                // Initialize fields with the merged settings
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
    function assignAjaxSetting(key, value) {
        // Normalize key to uppercase for case-insensitive comparison
        var keyUpper = key.toUpperCase();

        switch (true) {
            case keyUpper === 'FW_NEW_UPDATE_POSTPONEMENT_DAYS':
                ajax_custom_settings.FW_New_Update_Postponement_Days = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_EXPECTED_RUN_DATE':
                fwUpdateEstimatedRunDate = value;  // We don't want to save it the custom_settings; only as-is for displaying it.
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_NOTIFICATION':
                ajax_custom_settings.FW_New_Update_EMail_Notification = parseBoolean(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_FORMATTYPE':
                ajax_custom_settings.FW_New_Update_EMail_FormatType = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_ZIP_DIRECTORY_PATH':
                ajax_custom_settings.FW_New_Update_ZIP_Directory_Path = value;
                break;

            case keyUpper === 'ALLOW_UPDATES_OVERVPN':
                ajax_custom_settings.Allow_Updates_OverVPN = parseBoolean(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_CC_ADDRESS':
                ajax_custom_settings.FW_New_Update_EMail_CC_Address = value;
                break;

            case keyUpper === 'CHECKCHANGELOG':
                ajax_custom_settings.CheckChangeLog = parseBoolean(value);
                break;

            case keyUpper === 'ALLOW_SCRIPT_AUTO_UPDATE':
                ajax_custom_settings.Allow_Script_Auto_Update = parseBoolean(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_CHANGELOG_APPROVAL':
                ajax_custom_settings.FW_New_Update_Changelog_Approval = value; // Store as-is for display
                break;

            case keyUpper === 'FW_ALLOW_BETA_PRODUCTION_UP':
                ajax_custom_settings.FW_Allow_Beta_Production_Up = parseBoolean(value);
                break;

            case keyUpper === 'FW_AUTO_BACKUPMON':
                ajax_custom_settings.FW_Auto_Backupmon = parseBoolean(value);
                break;

            case keyUpper === 'CREDENTIALS_BASE64':
                try {
                    var decoded = atob(value);
                    var password = decoded.split(':')[1] || '';
                    ajax_custom_settings.routerPassword = password;
                } catch (e) {
                    console.error("Error decoding credentials_base64:", e);
                }
                break;

            case keyUpper === 'ROGBUILD':
                ajax_custom_settings.FW_New_Update_ROGFWBuildType = parseBoolean(value) ? 'ROG' : 'Pure';
                break;

            case keyUpper === 'TUFBUILD':
                ajax_custom_settings.FW_New_Update_TUFWBuildType = parseBoolean(value) ? 'TUF' : 'Pure';
                break;

            case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_DATE':
                ajax_custom_settings.FW_New_Update_Notifications_Date = value;
                break;

            // Additional AJAX settings can be handled here

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
        LoadCustomSettings();
        get_conf_file();
        show_menu();

        // Debugging iframe behavior
        var hiddenFrame = document.getElementById('hidden_frame');
        if (hiddenFrame) {
            hiddenFrame.onload = function () {
                console.log("Hidden frame loaded with server response.");
            };

            initializeCollapsibleSections();
        }
    }

    // **Adjusted SaveActionsConfig Function**
function SaveActionsConfig() {
    // Collect Action form-specific settings
    var password = document.getElementById('routerPassword')?.value || '';
    var usernameElement = document.getElementById('http_username');
    var username = usernameElement ? usernameElement.value.trim() : 'admin';

    if (!username) {
        console.error("HTTP username is missing.");
        alert("HTTP username is not set. Please contact your administrator.");
        return;
    }

    // Encode credentials in Base64
    var credentials = username + ':' + password;
    var encodedCredentials = btoa(credentials);

    // Collect only Action form-specific settings
    var action_settings = {
        credentials_base64: encodedCredentials,
        FW_New_Update_Postponement_Days: document.getElementById('fwUpdatePostponement')?.value || '0',
        CheckChangeLog: document.getElementById('changelogCheckEnabled').checked
    };

    // Prefix only Action settings
    var prefixedActionSettings = prefixCustomSettings(action_settings, 'MerlinAU_');

    // Merge Server Custom Settings and prefixed Action form settings
    var updatedSettings = Object.assign({}, server_custom_settings, prefixedActionSettings);

    // Save merged settings to the hidden input field
    document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

    // Apply the settings
    document.form.action_script.value = 'start_MerlinAUconfig';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
    console.log("Actions Config Form submitted with settings:", updatedSettings);
}

function SaveAdvancedConfig() {
    // Collect only Advanced form-specific settings
    var advanced_settings = {
        FW_New_Update_EMail_Notification: document.getElementById('emailNotificationsEnabled').checked,
        FW_New_Update_EMail_FormatType: document.getElementById('emailFormat')?.value || 'HTML',
        FW_New_Update_ZIP_Directory_Path: document.getElementById('fwUpdateDirectory')?.value || '/tmp/mnt/USB1',
        Allow_Updates_OverVPN: document.getElementById('tailscaleVPNEnabled').checked,
        FW_New_Update_EMail_CC_Address: document.getElementById('secondaryEmail')?.value || 'TBD',
        Allow_Script_Auto_Update: document.getElementById('autoUpdatesScriptEnabled').checked,
        FW_Allow_Beta_Production_Up: document.getElementById('betaToReleaseUpdatesEnabled').checked,
        FW_Auto_Backupmon: document.getElementById('autobackupEnabled').checked
    };

    // Handle conditional fields based on visibility
    var rogFWBuildRow = document.getElementById('rogFWBuildRow');
    if (rogFWBuildRow && rogFWBuildRow.style.display !== 'none') {
        advanced_settings.FW_New_Update_ROGFWBuildType = document.getElementById('rogFWBuildType')?.value || 'ROG';
    }

    var tufFWBuildRow = document.getElementById('tuffFWBuildRow');
    if (tufFWBuildRow && tufFWBuildRow.style.display !== 'none') {
        advanced_settings.FW_New_Update_TUFWBuildType = document.getElementById('tuffFWBuildType')?.value || 'TUF';
    }

    // Prefix only Advanced settings
    var prefixedAdvancedSettings = prefixCustomSettings(advanced_settings, 'MerlinAU_');

    // Merge Server Custom Settings and prefixed Advanced settings
    var updatedSettings = Object.assign({}, server_custom_settings, prefixedAdvancedSettings);

    // Save merged settings to the hidden input field
    document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

    // Apply the settings
    document.form.action_script.value = 'start_MerlinAUconfig';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
    console.log("Advanced Config Form submitted with settings:", updatedSettings);
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
        <input type="hidden" name="action_script" value="start_MerlinAUconfig" />
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
        <input type="hidden" name="firmwarev" id="firmwarev" value="<% nvram_get('firmver'); %>" />
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
                                                                                    <td id="fwUpdateEstimatedRunDate" style="padding: 4px;">TBD</td>
                                                                                </tr>
                                                                                <tr>
                                                                                    <td style="padding: 4px;"><strong>Last Notificiation Date:</strong></td>
                                                                                    <td id="fwNotificationsDate" style="padding: 4px;">TBD</td>
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
                                                                                    <td style="padding: 4px;"><strong>Changelog Approval:</strong></td>
                                                                                    <td id="changelogApproval" style="padding: 4px;">Disabled</td>
                                                                                </tr>
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
                                                                            <col style="width: 33%;" />
                                                                            <col style="width: 33%;" />
                                                                            <col style="width: 33%;" />
                                                                        </colgroup>
                                                                        <tr>
                                                                            <td style="text-align: right; border: none;">
                                                                                <button type="button" onclick="checkFirmwareUpdate()">F/W Update Check Now</button>
                                                                            </td>
                                                                            <td style="text-align: center; border: none;" id="approveChangelogCell">
                                                                                <button type="button" id="approveChangelogButton" onclick="changelogApproval()">Approve Changelog</button>
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
                                                                        <tr id="rogFWBuildRow">
                                                                            <td style="text-align: left;"><label for="rogFWBuildType">ROG F/W Build Type</label></td>
                                                                            <td>
                                                                                <select id="rogFWBuildType" name="rogFWBuildType" style="width: 20%;">
                                                                                    <option value="ROG">ROG</option>
                                                                                    <option value="Pure">Pure</option>
                                                                                </select>
                                                                            </td>
                                                                        </tr>
                                                                        <tr id="tuffFWBuildRow">
                                                                            <td style="text-align: left;"><label for="tuffFWBuildType">TUF F/W Build Type</label></td>
                                                                            <td>
                                                                                <select id="tuffFWBuildType" name="tuffFWBuildType" style="width: 20%;">
                                                                                    <option value="TUF">TUF</option>
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
