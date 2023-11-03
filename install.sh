#!/bin/bash

# Check if the OpenAI API key is already set in the git configuration
existing_key=$(git config --global --get openai.apikey)

if [ -n "$existing_key" ]; then
    echo "You have already set the OpenAI API key."
else
    # Prompt the user for their OpenAI API key
    echo "Please enter your OpenAI API key:"
    read -r openai_api_key < /dev/tty

    # Save the OpenAI API key to the git configuration
    git config --global openai.apikey "$openai_api_key"
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