set -e
gcc -o killsession killsession.c
mv killsession /usr/local/bin
chmod a=rx /usr/local/bin/killsession
chmod a+s /usr/local/bin/killsession
mv killsession.py /usr/local/bin/ && chmod a+x /usr/local/bin/killsession.py
mkdir -p /usr/local/share/pixmaps && mv killsession.png /usr/local/share/pixmaps/
mv KillSession.desktop /usr/share/applications/ && chmod a+x /usr/share/applications/KillSession.desktop