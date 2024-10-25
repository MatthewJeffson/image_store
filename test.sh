#!/bin/bash

# Set the directory where the images will be saved (same as the script folder)
LOCAL_REPO=$(pwd)
IMAGE_COUNTER=1  # Start with 1.png

# GitHub configuration: Use an environment variable for the token
GITHUB_TOKEN="${GITHUB_TOKEN_ENV}"
REPO_URL="https://$GITHUB_TOKEN@github.com/MatthewJeffson/image_store.git"

# Set the IP and port to listen for data
LISTEN_IP="192.168.66.184"
LISTEN_PORT=12345

# Ensure the repo is cloned if it doesn't exist
if [ ! -d "$LOCAL_REPO/.git" ]; then
    echo "Git repository not found. Cloning the repository..."
    git clone "$REPO_URL" "$LOCAL_REPO"
else
    echo "Git repository found."
fi

# Function to increment the image filename (1.png, 2.png, etc.)
increment_filename() {
    FILENAME="${IMAGE_COUNTER}.png"
    IMAGE_COUNTER=$((IMAGE_COUNTER + 1))
}

# Function to upload all images to GitHub using 'git add .'
upload_images_to_github() {
    cd "$LOCAL_REPO" || exit

    echo "Staging all files for upload..."

    # Stage all new/modified files (i.e., all images and other changes)
    git add .

    # Commit the changes with a message
    git commit -m "Auto-update: Added new images"

    # Push to GitHub
    git push origin main
    if [ $? -eq 0 ]; then
        echo "Images uploaded successfully!"
    else
        echo "Error during push to GitHub."
    fi

    # Return to the original directory
    cd - > /dev/null
}

# Start listening for data from the ESP32
echo "Waiting for signal on $LISTEN_IP:$LISTEN_PORT..."

while true; do
    # Use netcat to listen for incoming data on the specified IP and port
    DATA=$(nc -l $LISTEN_IP $LISTEN_PORT)

    # Debugging: Print the received data for verification
    echo "Received data: $DATA"

    # Check if the received data is "58426"
    if [[ "$DATA" == "58426" ]]; then
        echo "Received trigger signal. Starting image capture..."

        # Capture 3 images in 2 seconds
        for i in {1..3}; do
            # Increment the filename before each capture
            increment_filename

            # Capture the image using fswebcam and save directly to the current folder
            fswebcam -r 1280x720 --no-banner --png 9 "$LOCAL_REPO/$FILENAME"

            echo "Captured image: $FILENAME"

            # Add a short delay to ensure time between captures
            sleep 0.5
        done

        # Upload all files to GitHub (including the newly captured images)
        upload_images_to_github

        echo "Image capture and upload complete. Waiting for the next trigger..."

        # Wait 2 seconds before continuing
        sleep 2

    else
        echo "Received invalid data: $DATA. Waiting for correct signal..."
    fi
done
