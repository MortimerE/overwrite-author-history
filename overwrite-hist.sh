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
BRANCH_SUFFIX="-hist-update"

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

#Set OLD_EMAIL in change-auth
OLD_EMAIL=$(grep "OLD_EMAIL"= change-auth.sh | cut -d'"' -f2)
if [ -z "$OLD_EMAIL" ]; then
    echo "Error: OLD_EMAIL cannot be obtained from change-auth.sh"
    exit 1
fi

echo "Finding commits from $OLD_EMAIL"

BRANCHES=$(git branch -r  | grep -v '\->' | sed 's/origin\///')
echo "Found branches: $BRANCHES"

for BRANCH in $BRANCHES; do
    echo "Generating new history for $BRANCH"
    
    git checkout "$BRANCH"
    if [ $? -ne 0 ]; then
	echo "Failed to checkout branch $BRANCH, skipping."
	continue
    fi

    NEW_BRANCH = "${BRANCH}${BRANCH_SUFFIX}"

    git checkout -b "$NEW_BRANCH"
    if [ $? -ne 0 ]; then
	echo "Failed to create new branch $NEW_BRANCH, skipping."
	continue
    fi

    sh change-auth.sh
    if [ $? -ne 0 ]; then
	echo "Error, did not finish execution of change_auth.sh."
	continue
    fi

    git push --force origin "$NEW_BRANCH"
    if [ $? -ne 0 ]; then
	echo "Failed to push $NEW_BRANCH"
	continue
    fi

    echo "$NEW_BRANCH successfully pushed to $REPO_NAME! Yatta~"
done

# Force push all branches and tags
#git push --force --tags origin 'refs/heads/*'
#if [ $? -ne 0 ]; then
#    echo "Failed to push changes."
#    exit 1
#fi

# Move back to the parent directory
cd ..

# Remove the cloned repository
sudo rm -rf "$REPO_NAME.git"

echo "Process completed successfully."
echo "Create a pull request from each branch ending in $BRANCH_SUFFIX to merge the changes."
