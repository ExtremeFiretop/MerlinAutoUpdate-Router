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
    var custom_settings = <% get_custom_settings(); %>;

    function initial() {
        SetCurrentPage();
        show_menu();

        // Populate form fields with existing settings or set default values
        if (custom_settings.routerPassword === undefined) {
            document.getElementById('routerPassword').value = "";
        } else {
            document.getElementById('routerPassword').value = custom_settings.routerPassword;
        }

        if (custom_settings.fwUpdatePostponementDays === undefined) {
            document.getElementById('fwUpdatePostponementDays').value = "0";
        } else {
            document.getElementById('fwUpdatePostponementDays').value = custom_settings.fwUpdatePostponementDays;
        }

        if (custom_settings.secondaryEmailAddress === undefined) {
            document.getElementById('secondaryEmailAddress').value = "";
        } else {
            document.getElementById('secondaryEmailAddress').value = custom_settings.secondaryEmailAddress;
        }

        if (custom_settings.emailFormatType === undefined) {
            document.getElementById('emailFormatType').value = "HTML";
        } else {
            document.getElementById('emailFormatType').value = custom_settings.emailFormatType;
        }

        if (custom_settings.rogFWBuildType === undefined) {
            document.getElementById('rogFWBuildType').value = "ROG";
        } else {
            document.getElementById('rogFWBuildType').value = custom_settings.rogFWBuildType;
        }

        if (custom_settings.fwUpdateSchedule === undefined) {
            document.getElementById('fwUpdateSchedule').value = "";
        } else {
            document.getElementById('fwUpdateSchedule').value = custom_settings.fwUpdateSchedule;
        }

        // Initialize collapsible sections
        // Add other fields as needed
        initializeCollapsibleSections();

        // Set F/W Version Installed from hidden input
        var installedfirm = document.getElementById('installedfirm').value;
        document.getElementById('fwVersion').textContent = installedfirm;

        // Add other fields as needed
    }

    function SetCurrentPage() {
        /* Set the proper return pages */
        document.form.next_page.value = window.location.pathname.substring(1);
        document.form.current_page.value = window.location.pathname.substring(1);
    }

    function applySettings() {
        /* Retrieve value from input fields and store in object */
        custom_settings.routerPassword = document.getElementById('routerPassword').value;
        custom_settings.fwUpdatePostponementDays = document.getElementById('fwUpdatePostponementDays').value;
        custom_settings.secondaryEmailAddress = document.getElementById('secondaryEmailAddress').value;
        custom_settings.emailFormatType = document.getElementById('emailFormatType').value;
        custom_settings.rogFWBuildType = document.getElementById('rogFWBuildType').value;
        custom_settings.fwUpdateSchedule = document.getElementById('fwUpdateSchedule').value;
        // Add other settings as needed

        /* Store object as a string in the amng_custom hidden input field */
        document.getElementById('amng_custom').value = JSON.stringify(custom_settings);

        /* Apply */
        showLoading();
        document.form.submit();
    }

    function initializeCollapsibleSections() {
        // Check if jQuery is loaded
        if (typeof jQuery !== 'undefined') {
            $('.collapsible-jquery').each(function() {
                // Remove or comment out the line that hides the tbody
                // $(this).next('tbody').hide();

                // Optionally, add an 'active' class to indicate expanded state
                $(this).addClass('active');

                // Add a cursor pointer to indicate it's clickable
                $(this).css('cursor', 'pointer');

                // Bind click event to toggle the tbody
                $(this).click(function() {
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
        <input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get('preferred_lang'); %>" />
        <input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>" />
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
                                                    This is the MerlinAU Dashboard integrated into the router UI.
                                                </div>
                                                <div style="line-height:10px;">&nbsp;</div>

                                                <!-- Firmware Status Section -->
                                                <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                    <thead class="collapsible-jquery" id="firmwareStatusSection">
                                                        <tr>
                                                            <td>Firmware Status (click to expand/collapse)</td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                    <tr>
                                                        <td>
                                                            <p><strong>F/W Product/Model ID:</strong> GT-AXE11000</p>
                                                            <p><strong>F/W Update Available:</strong> NONE FOUND</p>
                                                            <p><strong>F/W Version Installed:</strong> <% nvram_get("innerver"); %></p>
                                                            <p><strong>USB Storage Connected:</strong> True</p>
                                                            <p><strong>Auto-Backup Enabled:</strong> False</p>
                                                        </td>
                                                    </tr>
                                                    </tbody>
                                                </table>

                                                <div style="line-height:10px;">&nbsp;</div>

                                                <!-- Actions Section -->
                                                <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                    <thead class="collapsible-jquery" id="actionsSection">
                                                        <tr>
                                                            <td>Actions (click to expand/collapse)</td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                    <tr>
                                                        <td>
                                                            <div style="margin-bottom:10px;">
                                                                <button type="button" onclick="checkFirmwareUpdate()">Run F/W Update Check Now</button>
                                                                <button type="button" onclick="toggleFirmwareUpdateCheck()">Toggle F/W Update Check</button>
                                                                <button type="button" onclick="toggleEmailNotifications()">Toggle F/W Update Email Notifications</button>
                                                                <button type="button" onclick="uninstallMerlinAU()">Uninstall</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Configure Router Login Credentials</h3>
                                                                <label for="routerPassword">Password:</label>
                                                                <input type="password" id="routerPassword" name="routerPassword" />
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Set F/W Update Postponement Days (0-60)</h3>
                                                                <input type="number" id="fwUpdatePostponementDays" name="fwUpdatePostponementDays" min="0" max="60" />
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Enable/Disable Automatic Backups</h3>
                                                                <button type="button" onclick="toggleAutomaticBackups()">Toggle Auto-Backup</button>
                                                            </div>
                                                        </td>
                                                    </tr>
                                                    </tbody>
                                                </table>

                                                <div style="line-height:10px;">&nbsp;</div>

                                                <!-- Advanced Options Section -->
                                                <table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
                                                    <thead class="collapsible-jquery" id="advancedOptionsSection">
                                                        <tr>
                                                            <td>Advanced Options (click to expand/collapse)</td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                    <tr>
                                                        <td>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Set F/W Update Check Schedule</h3>
                                                                <input type="text" id="fwUpdateSchedule" name="fwUpdateSchedule" />
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Set a Secondary Email Address for Notifications:</h3>
                                                                <input type="email" id="secondaryEmailAddress" name="secondaryEmailAddress" />
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Set Email Format Type:</h3>
                                                                <select id="emailFormatType" name="emailFormatType">
                                                                    <option value="HTML">HTML</option>
                                                                    <option value="PlainText">Plain Text</option>
                                                                </select>
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
                                                            <div style="margin-bottom:10px;">
                                                                <h3>Change ROG F/W Build Type:</h3>
                                                                <select id="rogFWBuildType" name="rogFWBuildType">
                                                                    <option value="ROG">ROG</option>
                                                                    <option value="Pure">Pure</option>
                                                                </select>
                                                                <button type="button" onclick="applySettings()">Apply</button>
                                                            </div>
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
