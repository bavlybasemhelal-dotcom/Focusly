param([Parameter(Mandatory=$true)][string]$RequestBase64)
$ErrorActionPreference = 'Stop'
$request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($RequestBase64)) | ConvertFrom-Json
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotifier, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.NotificationSetting, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ScheduledToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Focusly.Focusly')
if ($request.action -eq 'status') {
  try { $setting = [string]$notifier.get_Setting() }
  catch { $setting = 'Unavailable' }
  @{ setting = $setting } | ConvertTo-Json -Compress
  exit 0
}
if ($request.action -eq 'inspect') {
  $found = $false
  foreach ($toast in $notifier.GetScheduledToastNotifications()) {
    if ($toast.get_Id() -eq ('f' + [string]$request.id)) { $found = $true }
  }
  @{ present = $found } | ConvertTo-Json -Compress
  exit 0
}
if ($request.action -eq 'cancelAll') {
  foreach ($toast in $notifier.GetScheduledToastNotifications()) { $notifier.RemoveFromSchedule($toast) }
  exit 0
}
$toastId = 'f' + [string]$request.id
foreach ($toast in $notifier.GetScheduledToastNotifications()) {
  if ($toast.Id -eq $toastId) { $notifier.RemoveFromSchedule($toast) }
}
if ($request.action -eq 'cancel') { exit 0 }
$title = [Security.SecurityElement]::Escape([string]$request.title)
$body = [Security.SecurityElement]::Escape([string]$request.body)
$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
$launch = ''
if ([string]$request.payload -match '^account=([^|]+)\|(.+)$') {
  $uri = 'focusly://open?account=' + [uri]::EscapeDataString($Matches[1]) + '&payload=' + [uri]::EscapeDataString($Matches[2])
  $launch = [Security.SecurityElement]::Escape($uri)
}
$xml.LoadXml("<toast activationType=`"protocol`" launch=`"$launch`"><visual><binding template=`"ToastGeneric`"><text>$title</text><text>$body</text></binding></visual></toast>")
$time = [DateTimeOffset]::Parse([string]$request.date)
if ($time -le [DateTimeOffset]::Now) { exit 0 }
$notification = [Windows.UI.Notifications.ScheduledToastNotification]::new($xml, $time)
$notification.Id = $toastId
$notifier.AddToSchedule($notification)
