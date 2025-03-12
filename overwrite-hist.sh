#!/bin/bash

# $# - num args
#Expects 1 arg that is the repo url
if [ "$#" -lt 1 ]||[ "$#" -gt 2 ]; then
    echo "Incorrect number of args. Usage: $0 <github_repo_url> <YOLO (optional)>"
    exit 1
fi

REPO_URL="$1"
REPO=$(basename "$REPO_URL")
#Feel free to change this!
BRANCH_SUFFIX="-hist-update"

FORCE_ALL=false
if [ "$#" -eq 2 ] && [ "$2" = "YOLO" ]; then
    echo "Force history overwrite to all branches? y/n"
    read -r CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
	FORCE_ALL=true
	echo "Force pushing all branches, huh? Bold"
    else
	echo "Force push cancelled, proceeding with safe branch creation"
    fi
fi

# $? - exit status 
# -ne - not equal
git clone "$REPO_URL" "$REPO"
if [ $? -ne 0 ]; then
    echo "Failed to clone repository."
    exit 1
fi

REPO_NAME="${REPO}

cp change-auth.sh "$REPO_NAME"
if [ $? -ne 0 ]; then
    echo "Error: failed cp of change-auth.sh."
    exit 1
fi

echo "dirs"
ls
echo "$REPO_NAME"

cd "$REPO_NAME" || exit

#Set OLD_EMAIL in change-auth
OLD_EMAIL=$(grep "OLD_EMAIL"= change-auth.sh | cut -d'"' -f2)
if [ -z "$OLD_EMAIL" ]; then
    echo "Error: OLD_EMAIL cannot be obtained from change-auth.sh"
    exit 1
fi

echo "Finding commits from $OLD_EMAIL"

git fetch origin
BRANCHES=$(git branch -r | grep -v 'HEAD' | grep -v '->' | sed 's/origin\///')

if [ -z "$BRANCHES" ]; then
    echo "WARNING: Branch return failed, trying again..."
    # Alternative method to get branches
    BRANCHES="main master $(git branch | sed 's/^..//')"
    echo "Using branches: $BRANCHES"
fi

for BRANCH in $BRANCHES; do
    git checkout "$BRANCH"
    if [ $? -ne 0 ]; then
	echo "Failed to checkout branch $BRANCH, skipping."
	continue
    fi
    
    EMAIL_COMMITS=$(git log --author="$OLD_EMAIL" --pretty=format:%h -n 1)
    if [ -z "$EMAIL_COMMITS" ]; then
        echo "$BRANCH has no commits from $OLD_EMAIL, skipping."
        continue
    fi

    echo "Generating new history for $BRANCH"
    
    if [ "$FORCE_ALL" = true ]; then
	sh change-auth.sh
	if [ $? -ne 0 ]; then
	    echo "Error, execution of change-auth failed. Skipping $BRANCH"
	    continue
	fi

	git push --force origin "$BRANCH"
	if [ $? -ne 0 ]; then
	    echo "Failed to push changes to branch $BRANCH. Skipping"
	    continue
	fi

	echo "YOLO, $BRANCH has been forcefully overwritten."
    else
	NEW_BRANCH="${BRANCH}${BRANCH_SUFFIX}"

	git checkout -b "$NEW_BRANCH"
	if [ $? -ne 0 ]; then
	    echo "Failed to create new branch $NEW_BRANCH, skipping."
	    continue
	fi
    
        sh change-auth.sh
        if [ $? -ne 0 ]; then
	   echo "Error, did not finish execution of change-auth.sh."
	   continue
	fi

	git push --force origin "$NEW_BRANCH"
        
	if [ $? -ne 0 ]; then
	   echo "Failed to push $NEW_BRANCH"
	   continue
	fi

	echo "$NEW_BRANCH successfully pushed to $REPO_NAME! Yatta~"

    fi
done

# Move back to the parent directory
cd ..

# Remove the cloned repository
sudo rm -rf "$REPO_NAME"

echo "Process completed successfully."
if [ "$FORCE_ALL" = true ]; then
    echo "History forcibly overwritten. I hope you know what you're doing! If this was an accident, you can try swapping old and new email in change-auth"
else
    echo "Create a pull request from each branch ending in $BRANCH_SUFFIX to merge the changes."
fi
