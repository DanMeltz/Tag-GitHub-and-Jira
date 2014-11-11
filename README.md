## Tag Multiple Repositories and Jira

### Purpose
This script was written to create new tags in multiple repos all at the same time. This is in response to the branching model we're using, which is very similar to [this model](http://nvie.com/posts/a-successful-git-branching-model). In short, all devs merge their work into the "develop" branch whenever they like. QA people tag develop whenever they like and test that "moment in time" marked by the tag. 

### Usage
This script will create new tags in multiple repos, but you need to specify the repos by their path. I found it worked using ~/path/to/repo but if you have problems you may want to try using fully qualified paths. Example:
``` ./tag-multiple-repos.sh /path/to/repo1 /path/for/repo2 /path/leading/to/repo3 

It also calls a PHP script in order to tag any issues in Jira ("on demand" Jira) that are in a specified project and in a specified status (or column, if you're using Agile methodologies) with the same tag. The PHP script was written by Evan Frohlich <evan.frohlich@controlgroup.com>

This script was cobbled together--with infinite help from stack exchange--by Dan Meltz <dan.meltz@controlgroup.com>
