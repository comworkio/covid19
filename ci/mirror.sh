#!/bin/bash

REPO_PATH="${PROJECT_HOME}/covid19/"

cd "${REPO_PATH}" && git pull origin "${GIT_BRANCH}"  || :
git push github "${GIT_BRANCH}" 
git push pgitlab "${GIT_BRANCH}"
git push bitbucket "${GIT_BRANCH}"
exit 0
