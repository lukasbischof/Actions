tell application "Finder" to (insertion location as alias)
set location to the result

display dialog "Name of the file: " default answer "" buttons {"Abbrechen", "Ok"} default button 2
copy the result as list to {button_pressed, text_returned}

if button_pressed is equal to "Ok" then
	set filePath to (POSIX path of location) & text_returned
	do shell script "touch \"" & filePath & ".txt\""
end if