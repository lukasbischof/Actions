tell application "System Events"
	tell security preferences
		set require password to wake to false
	end tell
end tell

tell application "System Events"
	start current screen saver
end tell

delay 1

tell application "System Events"
	tell security preferences
		set require password to wake to true
	end tell
end tell