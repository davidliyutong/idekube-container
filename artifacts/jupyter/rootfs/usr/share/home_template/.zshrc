# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Disable complition-check
ZSH_DISABLE_COMPFIX="true"

# Disable Update
DISABLE_AUTO_UPDATE="true"
plugins=(git extract vscode zsh-autosuggestions zsh-syntax-highlighting sudo)

source $ZSH/oh-my-zsh.sh

# PIP
# pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

. /opt/miniconda3/etc/profile.d/conda.sh
conda activate

PROMPT=%m\ $PROMPT
