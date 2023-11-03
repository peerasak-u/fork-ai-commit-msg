# Fork AI Commit Message

This repository hosts a script designed to facilitate the generation of AI-powered commit messages within the Fork application. It sets up a `prepare-commit-msg` hook that seamlessly integrates with your Git workflow, leveraging OpenAI's capabilities to suggest meaningful commit descriptions based on your staged changes.

## 📦 Installation
To set up the AI commit message hook in your project, follow these simple steps:

1. Navigate to your project's directory in the terminal.
2. Execute the following command:
```bash
   bash -c "$(curl -L https://raw.githubusercontent.com/peerasak-u/fork-ai-commit-msg/main/install.sh)"
```