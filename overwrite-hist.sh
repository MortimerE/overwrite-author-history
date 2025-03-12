#!/bin/bash

# $# - num args
#Expects 1 arg that is the repo url
if [ "$#" -ne 1 ]; then
    echo "Incorrect number of args. Usage: $0 <github_repo_url>"
    exit 1
fi

REPO_URL="$1"
REPO_NAME=$(basename "$REPO_URL" .git)
#Feel free to change this!
NEW_BRANCH="author-hist-update"

# $? - exit status 
# -ne - not equal
git clone --bare "$REPO_URL"
if [ $? -ne 0 ]; then
    echo "Failed to clone repository."
    exit 1
fi

cp change-auth.sh "$REPO_NAME.git"
if [ $? -ne 0 ]; then
    echo "Error: failed cp of change-auth.sh."
    exit 1
fi

cd "$REPO_NAME.git" || exit

git checkout -b "$NEW_BRANCH"
if [ $? -n 0 ]; then
	echo "Failed to create new branch."
	exit 1
fi 

sh change-auth.sh
if [ $? -ne 0 ]; then
	echo "Error, did not finish execution of change_auth.sh."
	exit 1
fi

# Force push all branches and tags
git push --force --tags origin 'refs/heads/*'
if [ $? -ne 0 ]; then
    echo "Failed to push changes."
    exit 1
fi

# Move back to the parent directory
cd ..

# Remove the cloned repository
sudo rm -rf "$REPO_NAME.git"

echo "Process completed successfully."
echo "Create a pull request from the '$NEW_BRANCH' branch to merge the changes."
