echo "Setting Up Digital"
wget https://github.com/hneemann/Digital/releases/latest/download/Digital.zip -O /tmp/Digital.zip
unzip /tmp/Digital.zip -d /opt/

DESKTOP_FILE="#!/usr/bin/env xdg-open
[Desktop Entry]
Name=Digital
GenericName=Digital
Comment=an easy-to-use digital logic designer and circuit simulator
TryExec=/opt/Digital/Digital.sh
Exec=/opt/Digital/Digital.sh %F
Terminal=false
Type=Application
StartupNotify=true
Categories=Education;Information;"

echo "$DESKTOP_FILE" > /usr/share/applications/digital.desktop