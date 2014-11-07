#!/bin/sh

# This script will create new tags in multiple repos, but you need to specify the 
# repos by their path. I found it worked using ~/path/to/repo but if you have problems
# you may want to try using fully qualified paths.

# This script was written to create new tags in multiple repos all at the
# same time. This is in response to the branching model we're using, that is
# very similar to this: http://nvie.com/posts/a-successful-git-branching-model/
# It also calls a PHP script in order to tag any issues in a connected Jira
# instance with the same tag. That script was written by
# Evan Frohlich <evan.frohlich@controlgroup.com>

# This script was cobbled together--with infinite help from stack exchange--by:
# Dan Meltz <dan.meltz@controlgroup.com>

# Where are we starting? Let's actually start there
ORIGINDIR=`pwd`

# What is the branch you'll be working from. You may want to change this to "master". For the
# during which this was written, the devs merge everything into "develop", so...
ORIGINBRANCH="develop"

# We need to search for the issues in Jira at the end, and we only want issues in our project:
# You will need to put YOUR project name in the quotes
PROJECT="YOUR_PROJECT_NAME"            

# What status/column do you want to tag?
# We used this to tag things for QA. You can tag ANY status
STATUS="Validated"    

# COUNT is a counter for RESULTS
COUNT=0

# Define domain for jira tagging
# You will need to put YOUR domain name in the quotes
DOMAIN="YOUR_DOMAIN_NAME"

# Path the the PHP script for Jira labeling
LABELER="$ORIGINDIR/jiraLabel.php"

# Set the version counter
VERSION=1

# Set the tag prefix. This is just to make this thing as modular as possible
TAG_PREFIX="QA"

# Define the key file for jira tagging. This is kept in a separate "my.key" file
# that is not added to the repo. Moreover, gitignore contains a "*.key" entry
# to keep all ".key" files from being added to the repo.
# The key file holds your username:password base64 encrypted. I used 
# http://www.opinionatedgeek.com/dotnet/tools/Base64Encode/
# and fed it
# myusername:mypassword
KEYFILE="my.key"

# Load the key from the key file for jira tagging
if [[ -a $KEYFILE && -s $KEYFILE ]]  # I may have the wrong syntax here
then
  KEY=`cat $KEYFILE`
else
  echo "The specified file, $KEYFILE, is missing or empty" >&2
    exit 1 # terminate and indicate error
fi

# Get today's date
TODAY=`date +"%Y-%m-%d"`
TAG_NAME="$TAG_PREFIX-$TODAY.$VERSION"

echo "------------- Starting tagging ------------"


# Function to check to see if the tag name exists, and increment name if it
# does. When an available name is found, save it
check_tag () {
cd $1 || exit $?                                        # cd to the path of the repo
  TAKEN=TRUE
  echo "Checking $1"
  git checkout $ORIGINBRANCH
  git pull
  while [ $TAKEN == "TRUE" ]
  do
    TAG_NAME="QA-$TODAY.$VERSION"                                  # ...and put it in the new name
    #git ls-remote origin --tags --verify "refs/tags/$TAG_NAME"
    git show-ref --tags --quiet --verify -- "refs/tags/$TAG_NAME"  # check to see if THIS name exists [melodramatic sigh]
    if [ $? -eq 1 ]
    then
      TAKEN=FALSE
      return 0
    else
      ((VERSION++))                                                # Increment the version...
    fi
  done
}

# Function to create a tag. Pass it the branch to switch to, then the
# new tag to create
create_tag () {
  cd $1                                          # cd to the path of the repo
  echo "Tagging $1"
  git checkout $ORIGINBRANCH
  git pull
  git tag $TAG_NAME                                         # Create new tag
  git push origin $TAG_NAME                                 # Push the new tag up
}

for REPO in "$@"                                            # Go through all the repos passed to the script
do                                                          # and check to make sure we'll be using an unused tag name
  check_tag $REPO
done

# Display the tag name ASAP
echo "------------  $TAG_NAME  ------------"

for REPO in "$@"                                            # Now go ahead and create them.
do
  create_tag $REPO
  RESULTS[$COUNT]=$REPO                                     # Put the repo name in the RESULTS array
  COUNT=`expr $COUNT + 1`                                   # Increment COUNT
  RESULTS[$COUNT]=`git rev-parse HEAD`                      # put the SHA1 in the RESULTS array, too
  COUNT=`expr $COUNT + 1`                                   # increment COUNT again
  echo "---------------- Tagged $REPO with the tag $TAG_NAME ----------------"
done

php $LABELER $DOMAIN $KEY "status%20in%20($STATUS)%20AND%20project%20in%20($PROJECT)" $TAG_NAME

# Determine the lenght of RESULTS so we can loop throught and display the repos and their SHA1s
LENGTH=`expr ${#RESULTS[@]}`
COUNT=0

# Loop through the repos and display their names and SHA1s
while [[ $COUNT -lt $LENGTH ]]
do
  echo ${RESULTS[$COUNT]} " " ${RESULTS[$COUNT+1]}
  COUNT=`expr $COUNT + 2`
done

