tell application "Finder" to (insertion location as alias)
set location to the result

set content to "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
    <dict>
    
    </dict>
</plist>
"

display dialog "Name of the file: " default answer "" buttons {"Abbrechen", "Ok"} default button 2
copy the result as list to {button_pressed, text_returned}

if button_pressed is equal to "Ok" then
	set filePath to (POSIX path of location) & text_returned
	do shell script "echo \"" & content & "\" > \"" & filePath & ".plist\""
end if