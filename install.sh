#!/usr/bin/env bash

# Set default configuration values
DEFAULT_CHATGPT_PROMPT="Suggest commit message based on the following diff:\n\n\`\`\`\n{{diff}}\n\`\`\`\n\ncommit messages must be following these rules:\n - follow conventional commits\n - message format must be in this format: \"<TYPE>: <DESCRIPTION>\"\n - <TYPE> must be the prefix of commit message and must be one of the following: feat, fix, docs, style, refactor, test, chore\n - <DESCRIPTION> must be the description of the commit in lowercase and without any special characters\n\nEXAMPLES COMMIT MESSAGE:\n - fix: add password regex pattern\n - feat: add new test cases\n\nNOTE: Response only commit message, no explanation anymore\n\nACTUAL COMMIT MESSAGE: \n"
DEFAULT_MODEL="gpt-3.5-turbo"
DEFAULT_MAX_TOKENS=150

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Attempting to install jq..."

    # Use curl to download and run the webinstall.dev script for jq
    if curl -s https://webinstall.dev/jq | bash; then
        echo "jq has been installed successfully."

        # Add the installed jq to the current PATH, if it's not already there
        if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            export PATH="$HOME/.local/bin:$PATH"
            echo "Added jq to PATH for this session."
        fi

        # Reload the shell's environment if possible to recognize jq immediately
        if [ -f "$HOME/.profile" ]; then
            source "$HOME/.profile"
        elif [ -f "$HOME/.bashrc" ]; then
            source "$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            source "$HOME/.bash_profile"
        elif [ -f "$HOME/.zshrc" ]; then
            source "$HOME/.zshrc"
        elif [ -f "$HOME/.zprofile" ]; then
            source "$HOME/.zprofile"
        fi
    # Attempt to detect the platform (only works for some common distributions)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Attempt to install for Debian-based or Red Hat-based systems
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            echo "Package manager not recognized. Please install jq manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Attempt to install for macOS
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo "Homebrew not found. Please install jq manually or install Homebrew."
            exit 1
        fi
    else
        echo "Operating system not recognized. Please install jq manually."
        exit 1
    fi
fi

# Check if jq was successfully installed
if ! command -v jq &> /dev/null; then
    echo "Failed to install jq. Please install it manually."
    exit 1
fi

# Check if the OpenAI API key is already set in the git configuration
existing_key=$(git config --global --get openai.apikey)

if [ -n "$existing_key" ]; then
    echo "You have already set the OpenAI API key."
    echo "Do you want to use the existing key? [Y/n]"
    read -r use_existing_key < /dev/tty

    if [[ $use_existing_key =~ ^([nN][oO]|[nN])$ ]]; then
        echo "Please enter your new OpenAI API key:"
        read -r openai_api_key < /dev/tty
        git config --global openai.apikey "$openai_api_key"
    else
        echo "Using the existing OpenAI API key."
    fi
else
    # Prompt the user for their OpenAI API key
    echo "Please enter your OpenAI API key:"
    read -r openai_api_key < /dev/tty

    # Save the OpenAI API key to the git configuration
    git config --global openai.apikey "$openai_api_key"
fi

# Set default Git configuration values for CHATGPT_PROMPT, model, and max_tokens
git config --global --add commit.template "$DEFAULT_CHATGPT_PROMPT"
git config --global --add ai.model "$DEFAULT_MODEL"
git config --global --add ai.maxtokens "$DEFAULT_MAX_TOKENS"

# Check if we're inside a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: this script must be run from within a git repository."
    exit 1
fi

# Define the path to the git hooks folder
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Check if the hooks directory exists, create if not
if [ ! -d "$HOOKS_DIR" ]; then
    echo "The hooks directory was not found, creating..."
    mkdir -p "$HOOKS_DIR"
fi

# Define the URL of the raw gist containing the prepare-commit-msg hook
GIST_URL="https://raw.githubusercontent.com/peerasak-u/fork-ai-commit-msg/main/prepare-commit-msg"

# Define the path to the git hooks folder
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Define the path to the prepare-commit-msg hook within the hooks directory
HOOK_FILE="$HOOKS_DIR/prepare-commit-msg"

# Download the prepare-commit-msg hook from the Gist
echo "Downloading prepare-commit-msg hook..."
curl -L -o "$HOOK_FILE" "$GIST_URL"

# Check if the download was successful
if [ ! -f "$HOOK_FILE" ]; then
    echo "Failed to download the prepare-commit-msg hook."
    exit 1
fi

# Make the prepare-commit-msg hook executable
chmod +x "$HOOK_FILE"

echo "The prepare-commit-msg hook has been installed successfully."
