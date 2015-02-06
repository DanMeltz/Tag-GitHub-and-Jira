#!/bin/sh

# This script was written to create new tags in multiple repos all at the
# same time. This is in response to the branching model we're using, that is
# very similar to this: http://nvie.com/posts/a-successful-git-branching-model/
# It also calls a PHP script in order to tag any issues in a connected Jira
# instance with the same tag. That script was written by
# Evan Frohlich <evan.frohlich@controlgroup.com>

# This script will create new tags in multiple repos. You need to specify the 
# repos by their path. I found it worked using ~/path/to/repo but if you have problems
# you may want to try using fully qualified paths.

# This script was cobbled together--with infinite help from stack exchange--by:
# Dan Meltz <dan@controlgroup.com>

# get only the current BRANCH (not the SHA) (leave this commented out for now)
# git rev-parse --abbrev-ref HEAD

if [ $# -eq 0 ]
  then
    echo "No agruments provided. You must provide the tag name and at least one repository."
    printf "Usage: $0 [-o tag_prefix] tag_name repo1 repo2 ... "
fi

while getopts ":o:t:b:p:s:" name
do
    case $name in
    o)  TAG_PREFIX="$OPTARG-";;                   # Set the tag prefix. 
    t)  ORIGIN_TAG=$OPTARG;;                      # Set the origin TAG, you can use this OR the origin branch, not both 
    b)  ORIGIN_BRANCH=$OPTARG;;                   # Set the origin BRANCH, you can use this OR the origin tag, not both
    p)  PROJECT=$OPTARG;;                         # Set the project. 
    s)  STATUS=$OPTARG;;                          # Set the Status you're looking for in Jira
    \?)  printf "Invalid option: -$OPTARG.  Usage: $0 [-o tag_prefix] -t origin-tag -b origin-branch -p project -s status tag_name repo1 repo2 ... " >&2
        exit 2;;
    esac
done

# Now shift to keep the opts out of the rest of the script
shift $((OPTIND-1))

# Where are we starting? Let's actually start there
ORIGINDIR=`pwd`

# COUNT is a counter for RESULTS
COUNT=0

# Set the version counter
VERSION=1

# For Jira: We need to search for the issues in Jira at the end, and we only want issues in our project:
# If you use this a lot, you can just hard-code the project name in here
#PROJECT=""

# For Jira: What status/column do you want to tag? For this project, we tag things that are in the 
# "needs to be QA-ed" column, which Jira calls "Validated"
STATUS="Validated"

# For Jira: Define domain for jira tagging. You need to put your domain in the quotes. It's probably something
# like awesomepants.atlassian.net. If you work at a place called "AwesomePants"
DOMAIN=""

# For Jira: Path the the PHP script for Jira labeling
LABELER="$ORIGINDIR/jiraLabel.php"

# For Jira: Define the key file for jira tagging. This is kept in a separate "my.key" file
# that is not added to the repo. Moreover, gitignore contains a "*.key" entry
# to keep all ".key" files from being added to the repo.
# The key file holds your username:password base64 encrypted. I used 
# http://www.opinionatedgeek.com/dotnet/tools/Base64Encode/
# and fed it "myusername:mypassword"
KEYFILE="my.key"

# Load the key from the key file for jira tagging
# This is done now instead of later so the script will fail quickly if the key file is not found.
if [[ -a $KEYFILE && -s $KEYFILE ]] 
then
  KEY=`cat $KEYFILE`
else
  echo "The specified file, $KEYFILE, is missing or empty" >&2
    exit 1 # terminate and indicate error
fi

# Get today's date
TODAY=`date +"%Y-%m-%d"`

# Create the tag name
TAG_NAME="$TAG_PREFIX$TODAY.$VERSION"

# Function to check to see if the tag name exists, and increment name if it
# does. When an available name is found, save it
check_tag () {
cd $1 || exit $?                                                   # cd to the path of the repo
  TAKEN=TRUE
  echo "Checking $1"
  if [[ $ORIGIN_TAG ]]
    then
    git tag -l
    git checkout tags/$ORIGIN_TAG || { echo "Aborting: could not check out $ORIGIN_TAG from repo $1" 1>&2 ; exit 1; }                        
    git fetch --all
    git reset --hard origin/master
  elif [[ $ORIGIN_BRANCH ]]
    then
    git checkout $ORIGIN_BRANCH || { echo "Aborting: could not check out $ORIGIN_BRANCH from repo $1" 1>&2 ; exit 1; }                         
    git fetch --all
    git reset --hard origin/master
  else
    echo "You need to specify a branch or a tag to be tagged"
    exit
  fi
  while [ $TAKEN == "TRUE" ]
  do
    TAG_NAME="$TAG_PREFIX$TODAY.$VERSION"                          # ...and put it in the new name
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
  cd $1                                                            # cd to the path of the repo
  echo "Tagging $1"
  if [[ $ORIGIN_TAG ]]
    then
    git ls-remote origin | grep $ORIGIN_TAG | awk '{print $1}' | xargs git tag $TAG_NAME     # get the sha of ORIGIN_TAG and tag it with TAG_NAME
    git push origin $TAG_NAME                                                                # Push the new tag up
  elif [[ $ORIGIN_BRANCH ]]
    then
    git ls-remote origin | grep $ORIGIN_BRANCH | awk '{print $1}' | xargs git tag $TAG_NAME  # get the sha of ORIGIN_BRANCH and tag it with TAG_NAME
    git push origin $TAG_NAME                                                                # Push the new tag up
  else
    echo "You need to specify a branch or a tag to be tagged"
    exit
  fi
}

for REPO in "$@"                                            # Go through all the repos passed to the script
do                                                          # and check to make sure we'll be using an unused tag name
  echo "------------- updating repositories from remote ------------"
  check_tag $REPO
done

# Display the tag name ASAP
echo "------------  $TAG_NAME  ------------"

for REPO in "$@"                                            # Now go ahead and create them.
do
  create_tag $REPO
  RESULTS[$COUNT]=`echo $REPO | awk -F'/' '{print $NF}'`    # Put the repo name, without the full path, in the RESULTS array
  COUNT=`expr $COUNT + 1`                                   # Increment COUNT
  RESULTS[$COUNT]=`git rev-parse HEAD`                      # put the SHA1 in the RESULTS array, too
  COUNT=`expr $COUNT + 1`                                   # increment COUNT again
  echo "---------------- Attempted to tag $REPO with the tag $TAG_NAME ----------------"
done

php $LABELER $DOMAIN $KEY "status%20in%20($STATUS)%20AND%20project%20in%20($PROJECT)" $TAG_NAME

# Determine the lenght of RESULTS so we can loop throught and display the repos and their SHA1s
LENGTH=`expr ${#RESULTS[@]}`
COUNT=0

# Display all the relevant info. Loop through the repos and display their names and SHA1s
echo "Tag: $TAG_NAME"
while [[ $COUNT -lt $LENGTH ]]
do
  echo ${RESULTS[$COUNT]} " " ${RESULTS[$COUNT+1]}
  COUNT=`expr $COUNT + 2`
done

# Exit status based on status of last command
echo $?