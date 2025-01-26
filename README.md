# Multiple Node Docker Runner

This script sets up a Docker container to run the `nodepay-runner` project, which is a Python-based application for managing nodes. The script creates a Docker container with a random UUID and MAC address, and installs necessary dependencies.

## Prerequisites

Before running the script, make sure you have the following installed on your system:

- Docker
- `sudo` privileges
- `curl`

## Installation & Setup

To run the script, use the following one-liner command:

```bash
curl -O https://raw.githubusercontent.com/juliwicks/multiple-cc-with-docker/refs/heads/main/MultipleNode.sh && sudo chmod +x MultipleNode.sh && sudo ./MultipleNode.sh
```

# Explanation of the One-Liner:
- curl -O: Downloads the MultipleNode.sh script.
- sudo chmod +x: Makes the script executable.
- sudo ./MultipleNode.sh: Executes the script with superuser privileges.
  
# Script Flow
## Step 1: Docker Container Name
The script prompts you to enter the name for the Docker container.

## Step 2: UUID & MAC Address Generation
A random UUID and MAC address are generated and displayed.

## Step 3: Changing Docker Socket Permissions
The script changes the Docker socket permissions to allow interaction with Docker without needing root privileges.

## Step 4: Dockerfile Creation
The script creates a Dockerfile with the following setup:

Uses an official Python 3.9 slim image.
Installs git and required Python packages.

## Step 5: Building Docker Image
The Docker image for the container is built from the generated Dockerfile.

## Step 6: Running the Docker Container
The script runs the Docker container interactively with the following environment:

The name provided by the user.
The generated UUID and MAC address.
The nodepay-runner application starts inside the container.

## Step 7: Confirmation
Once the container is running, the script confirms the setup and that the container is set to auto-start.

