#!/bin/bash

REPO_PATH="${PROJECT_HOME}/tekton-task-images/"

cd "${REPO_PATH}" && git pull origin "${GIT_BRANCH}"  || :
git push github "${GIT_BRANCH}" 
git push pgitlab "${GIT_BRANCH}" 
git push pgithub "${GIT_BRANCH}" 
exit 0
