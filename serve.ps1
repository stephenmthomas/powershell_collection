# serve.ps1
# Starts npx serve in the background and opens the app in the default browser.

$port = 8080
$url  = "http://localhost:$port"

# Start the server in a new window so it stays alive independently
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx serve . -l $port"

# Give the server a moment to start
Start-Sleep -Seconds 2

# Open in default browser
#Start-Process $url

# Open in Chrome specifically
Start-Process "chrome.exe" -ArgumentList "--new-window $url"
