<%
    ' If needed, call get_custom_settings() or other ASP functions here
    ' get_custom_settings();
%>

<!-- Do not add DOCTYPE or HTML tags. The main WebUI handles that. -->

<!-- Use router-provided CSS -->
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">

<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="action_script" value="start_merlinau"> 
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_wait" value="90">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="SystemCmd" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">

<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>

<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">

<table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle">
<tbody>
<tr bgcolor="#4D595D">
<td valign="top">

<div>&nbsp;</div>
<div class="formfonttitle" style="text-align:center;">MerlinAU Dashboard v1.3.8</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">This is the MerlinAU Dashboard integrated into the router UI.</div>
<div style="line-height:10px;">&nbsp;</div>

<!-- Firmware Status Section -->
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible-jquery" id="firmwareStatusSection">
<tr><td>Firmware Status (click to expand/collapse)</td></tr>
</thead>
<tr>
<td>
<p><strong>F/W Product/Model ID:</strong> GT-AXE11000</p>
<p><strong>F/W Update Available:</strong> NONE FOUND</p>
<p><strong>F/W Version Installed:</strong> 3004.388.6.3_rog</p>
<p><strong>USB Storage Connected:</strong> True</p>
<p><strong>Auto-Backup Enabled:</strong> False</p>
<p><strong>Email Notifications Filter:</strong> Normal</p>
</td>
</tr>
</table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Actions Section -->
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible-jquery" id="actionsSection">
<tr><td>Actions (click to expand/collapse)</td></tr>
</thead>
<tr>
<td>
<div style="margin-bottom:10px;">
    <button onclick="checkFirmwareUpdate()">Run F/W Update Check Now</button>
    <button onclick="toggleFirmwareUpdateCheck()">Toggle F/W Update Check</button>
    <button onclick="toggleEmailNotifications()">Toggle F/W Update Email Notifications</button>
    <button onclick="uninstallMerlinAU()">Uninstall</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Configure Router Login Credentials</h3>
    <label for="routerPassword">Password:</label>
    <input type="password" id="routerPassword" name="routerPassword">
    <button onclick="applyRouterCredentials()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Set F/W Update Postponement Days (0-60)</h3>
    <input type="number" id="fwUpdatePostponementDays" name="fwUpdatePostponementDays" min="0" max="60">
    <button onclick="applyUpdatePostponementDays()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Enable/Disable Automatic Backups</h3>
    <button onclick="toggleAutomaticBackups()">Toggle Auto-Backup</button>
</div>
</td>
</tr>
</table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Advanced Options Section -->
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible-jquery" id="advancedOptionsSection">
<tr><td>Advanced Options (click to expand/collapse)</td></tr>
</thead>
<tr>
<td>
<div style="margin-bottom:10px;">
    <h3>Set F/W Update Check Schedule</h3>
    <input type="text" id="fwUpdateSchedule" name="fwUpdateSchedule">
    <button onclick="applyUpdateCheckSchedule()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Set a Secondary Email Address for Notifications:</h3>
    <input type="email" id="secondaryEmailAddress" name="secondaryEmailAddress">
    <button onclick="applySecondaryEmailAddress()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Set Email Format Type:</h3>
    <select id="emailFormatType" name="emailFormatType">
        <option value="HTML">HTML</option>
        <option value="PlainText">Plain Text</option>
    </select>
    <button onclick="applyEmailFormatType()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Change ROG F/W Build Type:</h3>
    <select id="rogFWBuildType" name="rogFWBuildType">
        <option value="ROG">ROG</option>
        <option value="Pure">Pure</option>
    </select>
    <button onclick="applyROGFWBuildType()">Apply</button>
</div>
<div style="margin-bottom:10px;">
    <h3>Set Email Notifications Filter:</h3>
    <select id="emailNotificationsFilter" name="emailNotificationsFilter">
        <option value="Minimal">Minimal</option>
        <option value="Normal" selected>Normal</option>
        <option value="Verbose">Verbose</option>
    </select>
    <button onclick="applyEmailNotificationsFilter()">Apply</button>
</div>
</td>
</tr>
</table>

<div style="margin-top:10px;text-align:center;">
    MerlinAU v1.3.8 by ExtremeFiretop & Martinski W.
</div>

</td>
</tr>
</tbody>
</table>

</td>
</tr>
</table>
</form>

<!-- Remove Node.js code entirely (require, fs, path) -->
<!-- If you need settings, use ASP server-side calls (e.g., get_custom_settings()) or other router-supported methods. -->
<script>
const fs = require('fs');
const path = require('path');

function getCustomSetting(settingType, defaultValue = 'TBD') {
  const settingsDir = '/jffs/addons/MerlinAU.d';
  const settingsFile = path.join(settingsDir, 'custom_settings.txt');

  let settingValue = ""; // Default to an empty string

  try {
    if (fs.existsSync(settingsFile)) {
      const lines = fs.readFileSync(settingsFile, 'utf-8').split(/\r?\n/);
      lines.forEach((line) => {
        if (line.startsWith(settingType + " ") || line.startsWith(settingType + "=")) {
          const parts = line.split(/ |=/); // Split on space or equals
          settingValue = parts[1].replace(/['"]/g, ''); // Remove potential quotes
        }
      });
    }
  } catch (err) {
    console.error(err);
    return defaultValue; // Return default value in case of an error
  }

  return settingValue || defaultValue; // Return the found value or the default
}
</script>
