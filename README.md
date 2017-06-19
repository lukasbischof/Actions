# Actions
A small macOS application for displaying useful system information and providing customisable actions.

## Functionality
The application is a statusbar application that provides a customisable menu with customisable actions and a menu section with system information such as CPU usage, clock speed, Fan speeds, DC/IN and networking information. 

## Installation
The project is a Xcode project which can simply be built in Xcode under Product > Build. The application is most useful if specified for instant launch at system startup.

### Customise Menu 
The application creates a folder "~/Documents/Scripts" into which you can copy all your AppleScripts, Automator Scripts and Bundles. 
Folders will be displayed as submenus.

#### AppleScripts
Save your AppleScripts as a .scpt file.

#### Automator
Save your Automator Files as Automator Workflows (.workflow).

#### Bundles
You can even compile C code in a bundle and provide a void run() funtion, which then gets executed by the application.
