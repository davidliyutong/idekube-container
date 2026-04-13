# Make the nvm-installed Node.js (and globally-installed CLIs like
# claude, opencode) available to interactive login shells.
#
# Dockerfile `ENV PATH=$NVM_DIR/current:$PATH` only affects processes
# spawned by the image (e.g. supervisord), not interactive shells
# started via `docker exec`, `su -`, or SSH login. Drop this here so
# the idekube user can use the agent CLIs from a shell without
# manually exporting PATH.
export NVM_DIR=/usr/local/nvm
if [ -d "$NVM_DIR/current" ]; then
    case ":$PATH:" in
        *":$NVM_DIR/current:"*) ;;
        *) export PATH="$NVM_DIR/current:$PATH" ;;
    esac
fi
