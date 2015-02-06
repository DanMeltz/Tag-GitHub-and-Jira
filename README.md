## Tag Multiple Repositories and Jira

### Purpose
This script was written to create new tags in multiple repos all at the same time. It also tags stories in Jira. (This is easily disabled if you don't use Jira) 

This is all because of the branching model we're using, (I didn't come up with it, but I think it's a pretty good system) which is very similar to [this model](http://nvie.com/posts/a-successful-git-branching-model). In short, all devs merge their work into the "develop" branch whenever they like. QA people tag develop whenever they like and test that "moment in time" marked by the tag. Jira stories are also tagged, so Product Owners (and anybody else) knows what's ready to be tested / currently being tested.

### Usage
This script will create new tags in multiple repos, but you need to specify the repos by their path. I found it worked using ~/path/to/repo but if you have problems you may want to try using fully qualified paths. It also allows for you to not only tag a spedific branch (which we use for tagging repos in order to QA them) but you can, instead, tag based on an existing tag. We use this to add a "Production" tag to a an existing QA tag that has been tested and passed.

Example:

``` ./tag-multiple-repos.sh -o tag_prefix -p project_name -b existing_branch /path/to/repo1 /path/for/repo2 /path/leading/to/repo3 

Flags:

    -o Set the tag prefix
    -t Set the origin TAG, you can use this OR the origin branch, not both
    -b Set the origin BRANCH, you can use this OR the origin tag, not both
    -p Set the project
    -s Set the Status (status field in Jira)
```

It also calls a PHP script in order to tag any issues in Jira ("on demand" Jira) that are in a specified project and in a specified status (or column, if you're using Agile methodologies) with the same tag. The PHP script was written by Evan Frohlich <evan.frohlich@controlgroup.com>

This script was cobbled together—with infinite help from stack exchange—by Dan Meltz <dan@controlgroup.com>
